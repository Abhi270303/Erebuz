# H-01: Owner Can Bypass VaultRescuer Timelock and Drain All Vault Assets Instantly

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** INV-03 (User deposits should not be extractable by a single key holder without timelock)
- **Chain / network:** ethereum (chainId 1)
- **Contract:** Vault (via `Rescuable`), InternalAccountingUnit (via `_checkOwner`), TreehouseAccounting (`mark`)
- **Source:** verified
- **Location:**
  - `libs/Rescuable.sol:L57-L68`
  - `libs/Rescuable.sol:L75-L78`
  - `InternalAccountingUnit.sol:L150-L154`
  - `TreehouseAccounting.sol:L71-L83`

## Description

The Vault inherits `Rescuable`, which has two critical functions:
```solidity
function rescueERC20(IERC20 tokenContract, address to, uint256 amount) external onlyRescuer {
    tokenContract.safeTransfer(to, amount);
}
function updateRescuer(address newRescuer) external onlyOwner {
    _rescuer = newRescuer;
}
```

The owner can **instantly** set any address (including their own EOA) as the `rescuer` of the Vault, and then that rescuer can drain ALL ERC20 tokens (including wstETH, stETH, WETH) from the Vault with no timelock. The `VaultRescuer` contract (which has a 5-day timelock) is trivially bypassed.

Additionally, the IAU contract's `_checkOwner()` allows both the owner AND the timelock to perform owner-only actions:
```solidity
function _checkOwner() internal view virtual override {
    if (owner() != _msgSender() && _msgSender() != timelock) {
        revert OwnableUnauthorizedAccount(_msgSender());
    }
}
```

If the owner sets themselves as timelock or if the timelock is compromised, the IAU can be manipulated (minters added/removed, etc.).

Furthermore, the owner/executor can call `TreehouseAccounting.mark()` to mint/burn any amount of IAU (within the deviation check), which directly affects the TAsset share price.

## Root cause

The `Rescuable` contract is inherited from Circle's FiatToken and intended as an emergency mechanism, but it gives the owner the ability to instantly bypass any timelock by setting an arbitrary rescuer.

## Impact

- The owner (or compromised owner key) can drain 100% of Vault funds (wstETH, stETH, WETH, all ERC20s) instantly via `updateRescuer(ownEOA)` + `rescueERC20(wstETH, ownEOA, type(uint).max)`.
- No multi-sig, no timelock, no user protection.
- Total loss of all user deposits.

## Attack path

1. Owner calls `Vault.updateRescuer(attackerEOA)`
2. attackerEOA calls `Vault.rescueERC20(wstETH, attackerEOA, vaultBalance)`
3. All wstETH is transferred from Vault to attacker
4. Repeat for all other ERC20s in Vault
5. Total time: one transaction

## Recommendation

1. **Remove** `Rescuable` from Vault, or override `updateRescuer` to add a timelock.
2. **Add** a multi-sig requirement to any function that can move user funds.
3. **Use** a proper timelock or governance for all privileged operations.

```diff
+   uint public constant RESCUER_CHANGE_DELAY = 7 days;
+   uint public rescuerChangeTimestamp;
+   address public pendingRescuer;
+
+   function updateRescuer(address newRescuer) external onlyOwner {
+       pendingRescuer = newRescuer;
+       rescuerChangeTimestamp = block.timestamp + RESCUER_CHANGE_DELAY;
+   }
+
+   function acceptRescuer() external {
+       if (block.timestamp < rescuerChangeTimestamp) revert();
+       _rescuer = pendingRescuer;
+   }
```
