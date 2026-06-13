# L-01: Swap-and-Pop Redemption Entry Reordering Causes User Confusion (V1 and V2)

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (quality issue)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TreehouseRedemptionV2, TreehouseRedemption (V1)
- **Source:** verified
- **Location:**
  - `TreehouseRedemptionV2.sol:L207-L210` — swap-and-pop in V2
  - `TreehouseRedemption.sol:L216-L219` — swap-and-pop in V1

## Description

Both redemption contracts use a "swap-and-pop" pattern to delete entries from the `redemptionInfo[]` array:

```solidity
// TreehouseRedemptionV2.sol:207-210
function _deleteRedeemEntry(uint256 index) internal {
    redemptionInfo[msg.sender][index] = redemptionInfo[msg.sender][redemptionInfo[msg.sender].length - 1];
    redemptionInfo[msg.sender].pop();
}
```

This copies the last element into the deleted slot, then pops the last element. After deletion:
- The remaining entries are reordered
- The length decreases by 1
- The user's index-to-entry mapping is silently invalidated

A user who calls `getRedeemLength()` and then `finalizeRedeem(index)` cannot be sure which redemption they are finalizing if a prior deletion occurred. The function accesses `_redeemIndex` by position, not by RedemptionInfo ID.

This is not directly exploitable for fund loss because `nonReentrant` and `waitingPeriod` checks prevent double-claim, but it creates a UX hazard where users can accidentally finalize the wrong entry.

## References

- **pashov-006**: Swap-and-pop reordering (V2)
- **pashov-007**: Swap-and-pop reordering (V1)

## Recommendation

1. Replace swap-and-pop with an ordered deletion that preserves indices (shift elements left), or:
2. Use a mapping of ID-to-Info instead of an array, so deletions don't reorder entries.
3. Document the behavior clearly: warn users that indices shift after any deletion.
4. Return the new valid indices for remaining entries after deletion.
