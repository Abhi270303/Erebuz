# [M] NPM collect() Subtracts Requested Amount Not Actual Collected Amount — Dust Accumulates Indefinitely

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-NPM-03 — tokensOwed accumulation must match fee growth × liquidity
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `NonfungiblePositionManager` (`collect`)
- **Source:** verified (repo source)
- **Location:** `v3-periphery/contracts/NonfungiblePositionManager.sol:L310-L375`

## Description

In `collect()`, `tokensOwed0/1` are decremented by `amount0Collect/amount1Collect` (the requested amounts), not by the actual `amount0/amount1` returned by `pool.collect()`. The pool may return 1-2 wei less due to rounding down in core. Over many collects, this creates an accumulating deficit: tracked `tokensOwed` drifts below actual pool entitlement, making the position impossible to fully clear and burn.

## Root cause

```solidity
// NonfungiblePositionManager.sol:L362-372
(uint128 amount0, uint128 amount1) = pool.collect(
    recipient,
    params.tickLower,
    params.tickUpper,
    amount0Collect,
    amount1Collect
);

// ... (amount0, amount1 returned from pool are available)
// But the code uses amount0Collect/amount1Collect for the subtraction:
// "sometimes there will be a few less wei than expected due to rounding down in core"
(position.tokensOwed0, position.tokensOwed1) = (
    tokensOwed0 - amount0Collect,   // BUG: should use amount0
    tokensOwed1 - amount1Collect    // BUG: should use amount1
);
```

The comment at L370-371 acknowledges the rounding issue but the code does not use the actual returned values.

## Impact

- Each `collect()` creates a 1-2 wei deficit in `tokensOwed` tracking
- Over many collects (covering the pool's lifetime), this accumulates into uncollectable dust
- Positions cannot be fully cleared and burned because `burn()` requires `tokensOwed == 0`
- The dust is small per-event but permanent — the pool holds tokens that no one can ever claim

## Attack path / preconditions

1. User has a position with `tokensOwed0 = X`
2. User calls `collect` requesting `amount0Max = X`
3. `amount0Collect = min(tokensOwed0, amount0Max) = X`
4. `pool.collect()` actually transfers `X - 1` (pool rounding)
5. Line 372: `tokensOwed0 = X - X = 0` (subtracts the full X, not the actual X-1)
6. The 1 wei stays in the pool as uncollectable dust
7. Over many positions and many collects, total dust accumulates

## Proof of concept

`POC: pending` — fork test:
1. Mint a position, let fees accumulate
2. Collect fees repeatedly (many times)
3. Compare NPM `tokensOwed` tracking vs actual pool collectable amount
4. Verify deficit grows with each collect

## Recommendation

Use the actual returned amounts from `pool.collect()`:

```diff
- (position.tokensOwed0, position.tokensOwed1) = (tokensOwed0 - amount0Collect, tokensOwed1 - amount1Collect);
+ (position.tokensOwed0, position.tokensOwed1) = (tokensOwed0 - amount0, tokensOwed1 - amount1);
```

## References

- **Pashov lens:** Lead #4 (MEDIUM) — collect rounding ignores actual pool return
- **Forefy lens:** Lead F-05 (MEDIUM) — collect subtracts requested vs actual amount
- **Invariant broken:** INV-NPM-03 — tokensOwed accumulation should match fee accrual exactly
- Uniswap V3 upstream has this same pattern (acknowledged) — the comment at L370 confirms it
