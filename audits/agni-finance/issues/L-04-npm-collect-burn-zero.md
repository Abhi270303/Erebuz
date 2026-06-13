# L-04: NPM Collect Triggers burn(0) on Pool — Griefing Risk if Pool Becomes Inaccessible

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** NonfungiblePositionManager (`collect`)
- **Deployed address:** N/A
- **Source:** verified
- **Location:** source/periphery/NonfungiblePositionManager.sol:L330-L331

## Description

In `NonfungiblePositionManager.collect()`, if the position has liquidity, the function calls `pool.burn(tickLower, tickUpper, 0)` to trigger fee growth updates before collecting earned fees:

```solidity
if (amount0Collect > 0 || amount1Collect > 0) {
    if (position.liquidity > 0) pool.burn(tickLower, tickUpper, 0);
    // ... collect tokensOwed
}
```

This `burn(0)` call will revert if the pool is paused, disabled, or otherwise inaccessible (e.g., due to a failed LM pool call during swap). This prevents users from collecting their earned fees even though fee collection is logically independent of pool swap state.

The same pattern exists in standard Uniswap V3.

## Root cause

Fee collection depends on a pool interaction (`burn(0)`) that can fail even though the fee collection operation is independent of the swap functionality.

## Impact

- If a pool's swap functionality is DoS'd (e.g., via malicious LM pool as described in H-02), LPs cannot collect fees from their positions
- LPs can still burn full liquidity via `decreaseLiquidity()` then `collect()` in a separate transaction, bypassing the `burn(0)` call — but this is not obvious to users
- Economic impact: temporary delay in fee collection, not permanent loss

## Attack path / preconditions

1. Pool's swap functionality is DoS'd (LM pool reverts, or other failure mode)
2. LP tries to collect fees via `NonfungiblePositionManager.collect()`
3. The `pool.burn(0)` call reverts
4. LP cannot collect fees until pool swaps are restored
5. LP can still call `decreaseLiquidity()` separately, then `collect()` succeeds on the second call

## Proof of concept

`POC: pending`

**Needs:**
- Fork POC: DoS a pool's swap function, call `collect()` on an LP position with liquidity, confirm revert

## Recommendation

Consider using `try/catch` around the `burn(0)` call:

```diff
- if (position.liquidity > 0) pool.burn(tickLower, tickUpper, 0);
+ if (position.liquidity > 0) {
+     (bool success, ) = address(pool).call(abi.encodeWithSelector(pool.burn.selector, tickLower, tickUpper, 0));
+     if (!success) {
+         // Fee growth update failed — collect may use stale values
+         // This is acceptable as fees are still accrued correctly on next success
+     }
+ }
```

## References

- **trailofbits** — "NPM collect triggers burn(0) on pool — griefing if pool becomes inaccessible" (low)
