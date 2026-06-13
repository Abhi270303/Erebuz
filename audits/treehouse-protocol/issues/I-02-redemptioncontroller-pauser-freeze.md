# I-02: RedemptionController.setPause Allows Pauser to Freeze All Redemptions

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** INV-7 (7-day waiting period for redemptions is inviolable — pausing is different)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** RedemptionController, TreehouseRedemptionV2, TreehouseFastlane
- **Source:** verified
- **Location:**
  - `periphery/RedemptionController.sol:L78-L86` — `setPause()` allows owner OR pauser
  - `TreehouseRedemptionV2.sol:L247-L249` — inherits `whenNotPaused` from controller
  - `TreehouseFastlane.sol:L132-L134` — inherits `whenNotPaused` from controller

## Description

`RedemptionController.setPause()` at line 78 allows both `owner()` and `pauser` to pause the contract:

```solidity
function setPause(bool _paused) external {
    if (msg.sender != owner() && msg.sender != pauser) revert Unauthorized();
    if (_paused) _pause(); else _unpause();
}
```

The `pauser` role is set by the owner with no timelock. Both `TreehouseRedemptionV2` and `TreehouseFastlane` inherit `whenNotPaused` from the `RedemptionController` (via their `redemptionController` reference), so pausing the controller also pauses all redemption flows.

However, `TreehouseRedemption` (V1) has its own independent pause mechanism and is NOT affected by the controller's pause state. This inconsistency means:
- V2 and Fastlane can be frozen by a compromised pauser
- V1 redemptions continue unaffected, which could lead to unexpected behavior if the system relies on all redemption paths being paused

## Impact

- A compromised pauser can freeze V2 and Fastlane redemptions, preventing users from withdrawing.
- V1 redemptions are NOT frozen, creating an asymmetric state where some users can still redeem but others cannot.
- This is a centralization risk — the pauser role should be carefully guarded.

## References

- **invariant-lead-8**: RedemptionController.setPause independent pauser

## Recommendation

1. Ensure V1 redemptions also respect the controller's pause state, or document the asymmetric behavior clearly.
2. Consider a multi-sig or timelock for the pauser role.
3. Evaluate whether a separate pauser role (distinct from owner) is necessary — if not, remove it to reduce the attack surface.
