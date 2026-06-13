# M-09: IAU Owner Backdoor via Timelock — Second Key Can Mint Unlimited IAU

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-6 (IAU supply cannot be inflated without corresponding asset increase)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** InternalAccountingUnit (IAU)
- **Source:** verified
- **Location:** `InternalAccountingUnit.sol:L150-L154`

## Description

`InternalAccountingUnit` overrides `_checkOwner()` to allow both `owner()` AND `timelock` to execute `onlyOwner` functions:

```solidity
function _checkOwner() internal view virtual override {
    if (owner() != _msgSender() && _msgSender() != timelock) {
        revert OwnableUnauthorizedAccount(_msgSender());
    }
}
```

The `timelock` address is set by `onlyOwner` with no delay:

```solidity
function setTimelock(address _newTimelock) external onlyOwner {
    emit TimelockUpdated(_newTimelock, timelock);
    timelock = _newTimelock;
}
```

This means the owner can create a backdoor by setting `timelock` to any address (including an EOA they control). That timelock address can then:
- Call `addMinter(maliciousContract)` — granting minting authority
- Call `removeMinter(legitimateContract)` — revoking legitimate minters
- Call `setTimelock(anotherAddress)` — passing the backdoor forward

If the owner key is later compromised, the timelock-EOA can still mint unlimited IAU independently.

## Root cause

`_checkOwner()` grants equal authority to two independent addresses without a governance mechanism or timelock to change the timelock. Setting `timelock = owner` immediately is a single-step change with no delay or approval.

## Impact

- **Permanent backdoor:** The owner can set timelock to a secondary key and keep primary key active. If either key is compromised, the attacker gains full minting authority.
- **Compromised owner → full supply control:** If owner is compromised, attacker sets timelock to their EOA, then mints unlimited IAU → dilutes all tETH holders to zero.

## Attack path

1. Owner calls `IAU.setTimelock(backupEOA)`.
2. Owner's primary key is compromised.
3. Attacker uses primary key to call `IAU.addMinter(attackerContract)`.
4. OR: If primary key is rotated, backupEOA (still valid as timelock) calls `IAU.addMinter(attackerContract)`.
5. `attackerContract` calls `IAU.mintTo(attackerContract, 1e30)`.
6. IAU total supply inflated with no backing.
7. TAsset share price diluted to zero (since tETH = proxy for IAU value).

## References

- **invariant-lead-9**: InternalAccountingUnit._checkOwner — owner backdoor via timelock

## Recommendation

1. **Remove timelock from `_checkOwner()`** — the timelock concept is incomplete and creates a backdoor:
   ```diff
   function _checkOwner() internal view virtual override {
   -    if (owner() != _msgSender() && _msgSender() != timelock) {
   +    if (owner() != _msgSender()) {
             revert OwnableUnauthorizedAccount(_msgSender());
         }
   }
   ```

2. **If timelock is needed for operational purposes**, use a separate role with restricted capabilities (e.g., only `addMinter`/`removeMinter` with a delay, not full owner authority).

3. **Require timelock changes to be two-step** (propose + accept) with a minimum delay.
