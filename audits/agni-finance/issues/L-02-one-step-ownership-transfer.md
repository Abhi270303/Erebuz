# L-02: One-Step Ownership Transfer Risks Permanent Loss of Factory Control

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none — governance/operational risk
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniFactory (`setOwner`)
- **Deployed address:** N/A
- **Source:** verified
- **Location:** source/core/AgniFactory.sol:L83-L86

## Description

`AgniFactory.setOwner()` immediately transfers ownership in a single transaction without requiring the new owner to accept:

```solidity
function setOwner(address _owner) external override onlyOwner {
    emit OwnerChanged(owner, _owner);
    owner = _owner;
}
```

If the wrong address is provided (due to typo, address poisoning, or compromised input), all factory control is permanently lost, including:
- Protocol fee settings on all pools
- Fee tier configuration
- LM pool deployer assignments
- Whitelist management
- Protocol fee collection rights on all pools

Standard practice (including Uniswap V3) uses a two-step pattern where ownership is first proposed, then the new owner must call `acceptOwner()`.

## Root cause

The `setOwner()` function sets `owner` directly in the same transaction instead of using a two-step commit-accept pattern.

## Impact

- If the owner accidentally sets `_owner` to an incorrect address (typo), a burned address (`address(0)` or `0xdead`), or a contract without the ability to call `setOwner`, all factory control is permanently lost
- No recovery mechanism exists
- All pools' protocol fee configuration becomes frozen

## Attack path / preconditions

1. Owner's key management process makes a mistake — sends a transaction with the wrong `_owner` address
2. The transaction succeeds, ownership is transferred to the wrong address
3. Factory and all pools lose admin control permanently

This is a single-point-of-failure in the key management process.

## Proof of concept

`POC: pending` — Code review confirms the one-step pattern.

**Needs:**
- No exploit POC needed — this is an operational risk confirmed by code review

## Recommendation

Implement a two-step ownership transfer pattern:

```diff
+ address public pendingOwner;
+
+ function setOwner(address _owner) external override onlyOwner {
+     pendingOwner = _owner;
+     emit OwnerProposed(owner, _owner);
+ }
+
+ function acceptOwner() external override {
+     require(msg.sender == pendingOwner, "Only pending owner can accept");
+     emit OwnerChanged(owner, pendingOwner);
+     owner = pendingOwner;
+     pendingOwner = address(0);
+ }
```

## References

- **forefy FORE-004** — "One-step ownership transfer risks permanent loss of factory control" (L)
