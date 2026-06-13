# M-07: Cross-Contract totalRedeeming Mismatch Causes Fastlane Liquidity Overestimation

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-3 (Redemption cannot extract more than deposited)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TreehouseFastlane, TreehouseRedemptionV2, TreehouseRedemption (V1)
- **Source:** verified
- **Location:**
  - `TreehouseFastlane.sol:L112-L114` — reads `totalRedeeming` from only one contract
  - `TreehouseRedemptionV2.sol:L55` — separate `totalRedeeming` counter

## Description

`TreehouseFastlane.getRedeemableAmount()` reads `totalRedeeming()` from a single `REDEMPTION_CONTRACT` address:

```solidity
// TreehouseFastlane.sol:112-114
uint _approximateEarmark = IERC4626(TASSET).convertToAssets(
    ITreehouseRedemption(REDEMPTION_CONTRACT).totalRedeeming()
);
```

If both `TreehouseRedemption` (V1) and `TreehouseRedemptionV2` are deployed and operational, only one contract's `totalRedeeming` is tracked. The other's pending redemptions are invisible to Fastlane.

This creates two problems:

1. **Overestimation of available liquidity:** If Fastlane tracks V2 but a large redemption is pending in V1, Vault wstETH is already earmarked for that V1 redemption. Fastlane's `getRedeemableAmount()` overestimates available wstETH. A Fastlane user's `redeemAndFinalize()` may succeed but the Vault could end up with insufficient wstETH for the V1 redemption.

2. **Underestimation / stale liquidity:** Conversely, if Fastlane tracks the wrong contract, legitimate liquidity goes unused.

## Root cause

`REDEMPTION_CONTRACT` in Fastlane is an immutable address set at deploy time. The protocol supports two redemption implementations (V1 and V2) with separate `totalRedeeming` state. There is no aggregation mechanism.

## Impact

- A Fastlane redemption succeeds when the Vault has sufficient wstETH at that moment, but the underlying wstETH may be double-counted against a V1 pending redemption.
- If the V1 redemption is finalized after Fastlane, the Vault could have insufficient wstETH, causing `safeTransferFrom` in `RedemptionController.redeem()` to fail (revert) — the V1 user is blocked, but the V2/Fastlane user already got their funds.
- Invariant: `Vault wstETH + strategy wstETH >= IAU.totalSupply() + sum(pending redemptions)` is broken.

## Attack path

1. TreehouseRedemptionV1 has a pending redemption for 1,000 wstETH.
2. Fastlane (tracking V2) thinks only 100 wstETH is pending.
3. Fastlane `getRedeemableAmount()` returns `available - 100` instead of `available - 1100`.
4. User calls `Fastlane.redeemAndFinalize()` — succeeds, pulling wstETH from Vault.
5. V1 user finalizes — Vault has insufficient wstETH → revert.
6. V1 redemption is stuck until more wstETH is deposited.

## References

- **trailofbits-07**: Cross-contract totalRedeeming mismatch

## Recommendation

1. **Aggregate totalRedeeming across all redemption contracts:** Fastlane should query all registered redemption contracts for their `totalRedeeming` and sum them.
2. **Alternative:** Maintain a single `totalRedeeming` tracker that all redemption contracts write to, rather than having per-contract counters.
3. **Or:** Designate one redemption contract as canonical for Fastlane tracking and disable the other.
