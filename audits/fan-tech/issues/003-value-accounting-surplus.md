# Issue 003: Value accounting divergence — untracked MNT surplus

**Severity**: High  
**Type**: Accounting / Value Leak  
**File**: FanTech.sol (multiple functions)  
**Status**: Active in deployed `0x53167401aeebFf5677C31E1DDA945628422D7Ed2`

## Description

The contract maintains `pool.value` as an accounting variable tracking each pool's liquid MNT. Multiple code paths can cause `pool.value` to diverge from the actual MNT backing those shares:

### 1. Unchecked refund failures (Issue 002)
In `_bidShares` line 783, failed refunds reduce `pool.value` by `refundAmount` without actually sending the MNT.

### 2. Fee extraction asymmetry
In `_buyShares` (line 871-876):
```solidity
pool.value = pool.value + msg.value - protocolFee - subjectFee - referrerFee;
```
The `poolFee` is NOT subtracted from `pool.value`. But in `sellShares` (line 334):
```solidity
pool.value = pool.value + poolFee - price;
```
The `poolFee` IS added to `pool.value`.

This asymmetry means `pool.value` systematically drifts upward relative to the "ideal" curve-based value. Over many trades, the discrepancy accumulates.

### 3. Direct transfers
Anyone can `send` MNT directly to the contract address without it being tracked in any pool's value.

## Impact

The contract currently holds ~42,999 MNT, but the sum of all tracked `pool.value` is only ~25,801 MNT. The **untracked surplus of ~17,198 MNT ($13.7K)** is:

- **Inaccessible** through any trading function
- **Growing over time** as trades occur
- **Unrecoverable** without a protocol upgrade

For users, this means:
- Selling shares returns less MNT than the pro-rata share of the contract balance
- The surplus represents value that should belong to share holders but is locked

## On-chain Evidence

| Metric | Value |
|--------|-------|
| Contract MNT balance | 42,998.8 |
| Sum of pool.value (top 40 pools) | 25,801.2 |
| Untracked surplus | 17,197.6 (~$13.7K) |
| Gift contract balance | 51,059.3 |
| Total protocol TVL | 94,058.1 (~$75K) |

## Remediation

1. Fix the unchecked refund call (Issue 002)
2. Add a function to redistribute surplus to share holders pro-rata, or integrate it into `pool.value` proportionally
3. Consider a sweep mechanism for direct transfers
