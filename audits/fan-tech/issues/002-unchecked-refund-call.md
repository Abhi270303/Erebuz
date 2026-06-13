# Issue 002: `_bidShares` ignores external call failure, causing value accounting divergence

**Severity**: High  
**Type**: Unchecked Return Value / Silent Failure  
**File**: FanTech.sol (line 783)  
**Status**: Unfixed in deployed `0x20aa28a1f66a6cbd97de8eb1907a5643eef7a108`

## Description

In `_bidShares`, when the initial-bidder top list overflows, the displaced bidder (`shiftAccount`) receives a refund via an external `.call{value:}`. The return value is captured but **never checked**:

```solidity
(bool status, ) = shiftAccount.call{value: refundAmount}("");
// status is captured but never used
pool.sharesBalance[shiftAccount] -= 1;
```

If `shiftAccount` is a contract that reverts on ETH receipt (e.g., missing `receive()` or `fallback()`), the call silently fails (`status = false`, `refundAmount` stays in the FanTech contract). The share balance is still decremented, and `pool.value` is still reduced by `refundAmount` (line 800-806):

```solidity
pool.value = pool.value + msg.value - refundAmount - protocolFee - subjectFee - referrerFee;
```

## Impact

Each failed refund creates a permanent divergence between the contract's actual ETH balance and `pool.value`:

- **Actual ETH in contract**: increases by `msg.value - actualFeesSent` (refund was NOT sent)
- **pool.value**: increases by `msg.value - refundAmount - fees` (refund was SUBTRACTED)
- **Difference**: `refundAmount` (the MNT that wasn't sent but was subtracted)

Over many refund failures, this "untracked surplus" accumulates. At the time of audit, the surplus is **~17,198 MNT (~$13.7K)**, representing MNT in the contract not accounted for by any pool's value.

This surplus is **permanently locked**—no function in the contract can distribute it:
- `sellShares` sends based on `getSellPrice` which is capped at `pool.value`
- No withdrawal mechanism for untracked ETH
- Protocol fees go to `protocolFeeDestination`, not the surplus

## Proof

On-chain state at latest block:
- FanTech contract balance: 42,998.8 MNT
- Sum of pool.value across top 40 pools: ~25,801.2 MNT  
- **Untracked surplus**: ~17,197.6 MNT

## Remediation

Check and handle the return value:

```solidity
(bool status, ) = shiftAccount.call{value: refundAmount}("");
require(status, "Refund to shifted bidder failed");
```

Or use a pull-based refund pattern where the shifted bidder must claim their refund:

```solidity
if (shiftAccount != address(0)) {
    pendingRefunds[shiftAccount] += refundAmount;
    pool.sharesBalance[shiftAccount] -= 1;
}
// Later: function claimRefund()

Alternatively, force-add the refund to the pool value if the call fails to maintain accounting consistency.
```
