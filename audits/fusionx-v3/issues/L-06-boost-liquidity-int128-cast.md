# [L] Boost Liquidity uint128 → int128 Cast May Underflow at Extreme Values

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** INV-MC-07 — Boost multiplier bounds (indirect)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`updateLiquidityOperation`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L505-L506`

## Description

`boostLiquidity` is computed as `((uint256(liquidity) * boostMultiplier) / BOOST_PRECISION).toUint128()` then cast to `int128` via `int128(boostLiquidity) - int128(positionInfo.boostLiquidity)`. If boostLiquidity exceeds `type(int128).max` (≈1.7e38), the cast reverts. Given MAX_BOOST_PRECISION = 200×1e10 and max uint128 = 3.4e38, the maximum safe liquidity is ~1.7e27 — orders of magnitude above realistic values.

## Root cause

```solidity
uint128 boostLiquidity = ((uint256(liquidity) * boostMultiplier) / BOOST_PRECISION).toUint128();
int128 liquidityDelta = int128(boostLiquidity) - int128(positionInfo.boostLiquidity);
```

## Impact

- **Theoretical only:** Requires `liquidity * boostMultiplier / BOOST_PRECISION > 2^127 - 1` (≈1.7e38)
- **Realistic max liquidity:** Even the largest Uniswap V3 positions are well below 1e20
- **Failure mode:** If this edge case is hit, `updateLiquidityOperation` reverts, DoS-ing `harvest`/`withdraw` for that position

## Proof of concept

No POC needed — theoretical edge case requiring unrealistic liquidity values (>10^27).

## Recommendation

Add a safe cast check:

```diff
int128 liquidityDelta = int128(boostLiquidity) - int128(positionInfo.boostLiquidity);
+ require(boostLiquidity <= uint128(type(int128).max), "boost exceeds int128 max");
```

## References

- **Trail of Bits lens:** Lead #10 (LOW) — boostLiquidity cast to int128 may underflow
- **Forefy lens:** Lead F-09 (LOW) — boost liquidity uint128 truncation
- **Invariant:** INV-MC-07
