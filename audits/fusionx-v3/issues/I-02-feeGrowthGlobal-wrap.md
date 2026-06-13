# [I] feeGrowthGlobalX128 Can Wrap Past uint256 Max — Strict Monotonicity Broken (By-Design)

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** INV-POOL-05 — feeGrowthGlobal0X128 and feeGrowthGlobal1X128 are monotonically non-decreasing
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3Pool` (`swap`, `flash`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3Pool.sol:L713`, `L855`

## Description

`feeGrowthGlobal0X128` and `feeGrowthGlobal1X128` are `uint256` values incremented via `+=` on each swap and flash loan. When they exceed `2^256 - 1`, they wrap to 0, breaking strict monotonicity. However, Uniswap V3's modular arithmetic handles wrapping correctly: positions snapshot `feeGrowthInsideLastX128` and compute `delta = current - last` (mod 2^256). The comment at line 787 confirms overflow is acceptable.

## Root cause

```solidity
// FusionXV3Pool.sol:L713
state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

// L787-789: "overflow is acceptable"
```

## Impact

- **No practical exploit:** Requires ~3.4e38 swap iterations to overflow at Q128 scaling — computationally impossible
- **Modular arithmetic is correct:** `Position.sol` delta computation handles wrap-around correctly
- **Documentation only:** If a downstream consumer relies on strict `uint256` monotonicity (e.g., checking `new > old`), it could break at wrap-around

## Proof of concept

No POC needed — theoretical overflow requiring >10^38 swap iterations.

## Recommendation

Document that `feeGrowthGlobal0X128` and `feeGrowthGlobal1X128` support modular arithmetic and consumers must compute deltas modulo 2^256 rather than checking strict inequality.

## References

- **Invariant lens:** Lead #2 (INFO) — feeGrowthGlobal can wrap uint256
- **Invariant:** INV-POOL-05
- **By-design in Uniswap V3:** Position library handles wrap-around at lines 62-66
