# I-01: Deviation Cap Applies Symmetrically — Limits Loss Marking During Fast Depegs

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** None (design observation)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** PnlAccounting
- **Source:** verified
- **Location:** `periphery/PnlAccounting.sol:L64`

## Description

The deviation cap (`maxPnl()`) applies symmetrically to both profit AND loss:

```solidity
if (_netPnl > maxPnl()) revert DeviationExceeded();
```

With `deviation = 250`, `PRECISION = 1e4`, and `cooldown = 3600s`:
- `maxPnl() = 2.5% * lastNav` per 1-hour window
- Max loss recognition per day: ~45.5% (non-compounding, due to lastNav decreasing)

In a fast market crash (e.g., stETH depeg from 1.0 to 0.9 in hours), the protocol cannot mark losses faster than 2.5% per hour. This means:
- The stale, pre-crash NAV persists for up to ~4 hours (10% depeg / 2.5% per hour)
- Users can redeem at the inflated pre-crash share price during this window
- The protocol absorbs the loss from stale pricing

This is a design trade-off, not a bug: the deviation cap prevents PnL manipulation but also delays loss recognition. Protocols with volatile or manipulable NAV inputs are more affected.

## References

- **trailofbits-09**: Deviation cap applies symmetrically to loss marking

## Recommendation

Consider asymmetric deviation caps: tighter for positive deviations (profit), looser for negative deviations (loss). This allows faster loss recognition while maintaining profit manipulation resistance.
