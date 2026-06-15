# M-04 ZapV1 rebalancing math has multiple precision loss vectors causing suboptimal LP ratios

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** I-26 — Zap rebalancing math reaches 50/50 split (MISSING)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalZapV1` (`_calculateAmountToSwap`, `_calculateAmountToSwapForRebalancing`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalZapV1.sol:L403-L434`, `L782-L835`

## Description

The custom rebalancing math in ZapV1 has **multiple independent precision loss vectors** that prevent achieving an exact 50/50 token split for LP provision:

1. **Underflow at extreme ratios** (pashov-005): The formula `amountToSwap = 2 * token0AmountToSell - Babylonian.sqrt(...)` can underflow when `nominator > 4 * denominator`, which occurs at extreme pool ratios (>99% in one token). Solidity 0.8.4 reverts rather than wrapping, causing valid zaps to fail.

2. **Division by zero** (pashov-006): The denominator computed via `tropicalRouter.quote()` can return 0 when `_reserve1 - nominator ≈ 0` (swap nearly drains the pool). Division by zero in `Babylonian.sqrt()` reverts.

3. **Iteration mismatch** (forefy-008): The second iteration recomputes `token0AmountToSell` using adjusted reserves, but the sqrt() price impact adjustment still uses `nominator` and `denominator` from the **first iteration**, causing a systematic bias in the computed swap amount for thin pools.

4. **Cumulative truncation** (INV-005): At least 7 integer truncation points across the formula — integer `/2` divisions, `getAmountOut` rounding down, `quote` rounding down, and `Babylonian.sqrt` rounding down. Each loses up to 1 wei, producing total error up to ~7 wei per operation.

## Root cause

`TropicalZapV1.sol:_calculateAmountToSwapForRebalancing()`:
```solidity
// Second iteration with adjusted reserves:
token0AmountToSell = (_token0AmountIn - (_token1AmountIn * (_reserve0 + token0AmountToSell)) / (_reserve1 - nominator)) / 2;

// Final computation uses FIRST-ITERATION nominator/denominator with SECOND-ITERATION amount:
amountToSwap = 2 * token0AmountToSell - Babylonian.sqrt(
    (token0AmountToSell * token0AmountToSell * nominator) / denominator
);  // Can underflow when nominator > 4 * denominator
```

`_calculateAmountToSwap()`:
```solidity
uint256 denominator = tropicalRouter.quote(halfToken0Amount, _reserve0 + halfToken0Amount, _reserve1 - nominator);
// denominator can be 0 when _reserve1 - nominator ≈ 0
Babylonian.sqrt((halfToken0Amount * halfToken0Amount * nominator) / denominator);  // Division by zero
```

## Impact

- **Complete DoS at extreme ratios:** Valid zap transactions revert silently when pools have extreme reserve imbalance (>99% in one token), effectively breaking Zap functionality for imbalanced pairs
- **Suboptimal LP minting:** At normal ratios, the cumulative rounding errors (~7 wei) cause the LP position to deviate from exact 50/50, resulting in slightly less LP value (dust, but compounds over many operations)
- **Amplified by H-02:** The 1/1 minima on addLiquidity means these precision errors are silently accepted without any post-condition validation
- **Amplified by M-01:** Residual tokens from the imprecise split accumulate in the Zap contract and can be extracted by any caller
- Historical precedent: BunniXYZ $2.3M precision bug (Sept 2025) — similar sqrt-based custom AMM math rounding error

## Attack path / preconditions

**DoS scenario:**
1. A pool exists with extreme reserve imbalance (e.g., 1 ETH vs 1,000,000 USDC — highly imbalanced)
2. User calls `zapInTokenRebalancing()`
3. `_calculateAmountToSwapForRebalancing()` underflows at the sqrt subtraction
4. Transaction reverts — zap fails with no clear error message

**Residual accumulation scenario:**
1. Normal rebalancing zaps execute with cumulative truncation (~7 wei per operation)
2. Each operation leaves a tiny residual in the Zap contract
3. Over 1,000 operations, 7,000 wei accumulates
4. Combined with M-01, any user can extract these residuals

## Proof of concept

```
POC: pending — Foundry fuzz test at extreme ratios
```

**Test plan (underflow):**
1. Create pool with reserve ratio 1000:1 (extreme imbalance)
2. Call `_calculateAmountToSwapForRebalancing()` with inputs that trigger `nominator > 4 * denominator`
3. Verify the sqrt subtraction underflows and reverts

**Test plan (truncation):**
1. Fuzz `_calculateAmountToSwapForRebalancing()` with 10,000 random reserve/imbalance combinations
2. Compute theoretical optimal swap amount
3. Compare to `_calculateAmountToSwapForRebalancing()` output
4. Measure deviation distribution and maximum error

**Test plan (iteration mismatch):**
1. Compute expected post-swap ratio for a thin pool using the function's output
2. Compare to true 50/50
3. Verify the deviation is larger than expected from rounding alone

## Recommendation

1. **Fix the underflow** with a bounds check:
```diff
  amountToSwap = 2 * token0AmountToSell - Babylonian.sqrt(
      (token0AmountToSell * token0AmountToSell * nominator) / denominator
  );
+ // Ensure sqrt does not exceed 2 * token0AmountToSell
+ if (amountToSwap > token0AmountToSell) amountToSwap = token0AmountToSell;
```

2. **Fix the iteration mismatch** by recomputing nominator/denominator for the second iteration:
```diff
+ (uint256 nominator2, uint256 denominator2) = recomputeForSecondIteration(...);
- amountToSwap = 2 * token0AmountToSell - Babylonian.sqrt((token0AmountToSell * token0AmountToSell * nominator) / denominator);
+ amountToSwap = 2 * token0AmountToSell - Babylonian.sqrt((token0AmountToSell * token0AmountToSell * nominator2) / denominator2);
```

3. **Add a post-condition** that the resulting ratio is within an acceptable bound (e.g., 1% of 50/50):
```diff
+ // After swapping, verify the resulting split is acceptable
+ require(_reserve0 * 1000 >= _reserve1 * 999 && _reserve0 * 1000 <= _reserve1 * 1001, "post-swap ratio too far from 50/50");
```

## References

- pashov (pashov-005) — sqrt underflow at extreme ratios (H — re-assessed to M)
- pashov (pashov-006) — division by zero from quote rounding (M)
- forefy (forefy-008) — First/second iteration nominator/denominator mismatch (L)
- invariant (INV-005) — 7 integer truncation points (L)
- solodit (SOL-006) — Rebalancing math precision loss at extreme ratios (M)
- trailofbits (TB-06) — Truncation with no post-condition 50/50 check (M)
- Solodit ref: BunniXYZ $2.3M precision bug — https://cryptodamus.io/en/articles/news/how-a-2-3m-crypto-black-hole-happened-uniswap-v4-hooks-broken-by-bunnixyz-precision-bug
