# L-02: Front-Runnable Fee Increase on Pending Redemptions — MEV Extraction Risk

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (centralization/MEV risk)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TreehouseRedemptionV2, TreehouseFastlane
- **Source:** verified
- **Location:**
  - `TreehouseRedemptionV2.sol:L165-L169` — `setRedemptionFee()` no timelock
  - `TreehouseRedemptionV2.sol:L120-L121` — fee computed at finalize time
  - `TreehouseFastlane.sol:L100-L103` — `setFeeContract()` no timelock

## Description

Redemption fees are computed at finalization time, not locked at redeem time:

```solidity
// TreehouseRedemptionV2.sol:120-121
uint _fee = (_returnAmount * redemptionFee) / PRECISION;
_returnAmount = _returnAmount - _fee;
```

The `redemptionFee` is set by `onlyOwner` with no timelock or notice period. The owner (or a compromised key) can:
1. Front-run a high-value redemption: increase `redemptionFee` from 0.5% to 50% just before the user finalizes.
2. Change `TreehouseFastlane.feeContract` to a malicious contract that applies 100% fee.

In `TreehouseFastlane`, the fee is determined by `feeContract.applyFee(_assets)` at execution time (line 77). The `feeContract` address can be changed by `onlyOwner` immediately.

## Impact

- Users cannot predict their net redemption amount at the time they initiate a redemption.
- A malicious or compromised owner can extract arbitrary fees from user redemptions via front-running.
- The economic loss is bounded by the user's redemption amount but represents an unfair value extraction.

## References

- **pashov-008**: Front-run fee increase on pending redemptions

## Recommendation

1. **Lock the fee at redeem time:** Store the fee percentage in the `RedemptionInfo` struct at `redeem()` time and use the stored value at finalization.
2. **Add a timelock** to `setRedemptionFee()` and `setFeeContract()` (e.g., 48-hour delay) so users have time to react to fee changes.
3. **Emit events** on fee changes and require off-chain monitoring.
