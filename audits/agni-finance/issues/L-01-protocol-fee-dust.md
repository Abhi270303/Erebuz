# L-01: Protocol Fee Collect Leaves 1 Wei Dust Permanently Stuck Per Token Per Pool

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none — inherited standard UniV3 behavior
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPool (`collectProtocol`)
- **Deployed address:** N/A (implementation contract)
- **Source:** verified
- **Location:** source/core/AgniPool.sol:L874-L881

## Description

`AgniPool.collectProtocol()` uses an off-by-one decrement pattern to avoid fully clearing the storage slot for gas savings. When the requested amount equals the total accumulated protocol fees, the function decrements by 1:

```solidity
if (amount0 == protocolFees.token0) amount0--; // ensure that the slot is not cleared, for gas savings
protocolFees.token0 -= amount0;
if (amount1 == protocolFees.token1) amount1--;
protocolFees.token1 -= amount1;
```

This means 1 wei per token is permanently locked in each pool. When the remaining protocol fee is exactly 1 wei, the amount gets decremented to 0 and no transfer occurs — the dust is stuck forever.

This behavior is inherited from standard Uniswap V3 and is documented as an intentional gas optimization (clearing a storage slot costs a gas refund, but the refund is capped and may not be economically beneficial).

## Root cause

```solidity
// AgniPool.sol:L874-L875
if (amount0 == protocolFees.token0) amount0--;
```

When `protocolFees.token0` accumulates to 1 wei, and a caller requests `amount0Requested = 1`:
1. `amount0 = min(1, protocolFees.token0) = 1`
2. `if (1 == 1) amount0--` → `amount0 = 0`
3. No tokens are transferred — the 1 wei remains stuck

## Impact

- Negligible economic impact (1 wei per token per pool)
- Permanent accounting discrepancy for each pool
- Cannot be recovered without upgrading the pool contract

## Attack path / preconditions

1. Protocol fees accumulate to exactly 1 wei in any token for any pool
2. Owner calls `collectProtocol()` requesting the full amount
3. 1 wei remains permanently uncollectible

This is not exploitable by an attacker — it is a permanent dust accumulation.

## Proof of concept

`POC: pending` — Trivially confirmable by reading the code.

**Needs:**
- Verify that when `protocolFees.token0` is 1, `amount0` gets decremented to 0 and no transfer occurs

## Recommendation

No fix needed — this matches standard Uniswap V3 behavior. If desired, add a sweep function for dust:

```diff
+ function sweepDust(address token) external onlyFactoryOrFactoryOwner {
+     uint256 dust = protocolFees.token0 == 0 ? 0 : 1;  // only 1 wei max
+     if (dust > 0) {
+         protocolFees.token0 -= uint128(dust);
+         TransferHelper.safeTransfer(token, msg.sender, dust);
+     }
+ }
```

## References

- **trailofbits** — "Protocol fee collection rounds down by 1 wei — permanently locked dust" (low)
- **forefy FORE-008** — "Protocol fee collect leaves 1 wei permanently stuck per token per pool" (I)
- **solodit solodit-006** — "collectProtocol off-by-one gas optimization causes revert when claiming full protocol fees" (M)
- Solodit reference: https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/73 (Off-by-one in collectProtocol)
