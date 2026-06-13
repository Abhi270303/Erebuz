# Critical Findings - Merchant Moe Liquidity Book

## CRITICAL [C-01]: `getCompositionFee` Rounds Down to Zero - Fee-Free Implicit Swaps

**Severity:** CRITICAL (9.5/10)
**Impact:** Protocol drain via fee-free value extraction
**Status:** **DEFERRED** - Fee path is mathematically unreachable in v2.1 codebase

### Root Cause
The `getCompositionFee` function in `FeeHelper.sol` (line 72-83) uses integer division that rounds DOWN:
```solidity
return uint128(uint256(amountWithFees) * totalFee * (uint256(totalFee) + Constants.PRECISION) / Constants.SQUARED_PRECISION);
```

The division `... / SQUARED_PRECISION (1e36)` truncates the result. When the numerator < 1e36, the fee is 0.

### Threshold Analysis
| Fee Level | Min Imbalance for Fee > 0 |
|-----------|--------------------------|
| 0.001%    | 100,000 wei ($0.0000000000001) |
| 0.01%     | 10,000 wei |
| 0.1%      | 1,000 wei |
| 1.0%      | 100 wei |

### Key Update: Path Unreachable

**After full mathematical derivation and 10,000×10,000 brute-force search, the composition fee is mathematically impossible in this codebase version.**

The reason: `BinHelper.getSharesAndEffectiveAmountsIn` (line 73-84) always aligns the deposit ratio to the bin's ratio before the composition fee check in `BinHelper.getCompositionFees` (line 178-201). When X is the limiting token, `receivedX == amountX` exactly; when Y is the limiting token, `receivedY == amountY` exactly. The condition `receivedX > amountX || receivedY > amountY` can never be satisfied.

The C4 and Offside Labs findings targeted a different code version where share calculation was done differently (without the alignment in `getSharesAndEffectiveAmountsIn`).

### Code Path
1. `LBPair._updateBin()` calls `binReserves.getCompositionFees(...)`
2. `BinHelper.getCompositionFees()` checks `receivedX > amountX || receivedY > amountY`
3. Both conditions are **always false** due to the share/amount alignment in `getSharesAndEffectiveAmountsIn`
4. The composition fee is always `0`

### Proof
Mathematical derivation:
- When X limits: `shares = amountX * supply / reserveX`, `receivedX = shares * (reserveX + amountX) / (supply + shares) = amountX` exactly
- When Y limits: `shares = amountY * supply / reserveY`, `receivedY = shares * (reserveY + amountY) / (supply + shares) = amountY` exactly
- Integer rounding can only make values SMALLER, never larger
- Therefore `receivedX > amountX` and `receivedY > amountY` are both impossible

### Recommendations
1. No code change needed for the fee function itself (it's correct but unreachable)
2. If the share calculation changes in the future, re-verify the composition fee threshold
3. Consider removing the unreachable composition fee code to reduce contract size and gas costs

### References
- [Code4rena Trader Joe v2 Report](https://code4rena.com/reports/2022-10-traderjoe)
- [Offside Labs - "Compensation for Composition"](https://blog.offside.io/p/compensation-for-composition)
