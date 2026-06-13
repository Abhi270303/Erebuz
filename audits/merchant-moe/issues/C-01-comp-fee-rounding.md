# Critical Findings - Merchant Moe Liquidity Book

## CRITICAL [C-01]: `getCompositionFee` Rounds Down to Zero - Fee-Free Implicit Swaps

**Severity:** CRITICAL (9.5/10)
**Impact:** Protocol drain via fee-free value extraction
**Status:** Confirmed via Foundry PoC (all 8 tests pass)

### Root Cause
The `getCompositionFee` function in `FeeHelper.sol` (line 72-83) uses integer division that rounds DOWN:
```solidity
return uint128(uint256(amountWithFees) * totalFee * (uint256(totalFee) + Constants.PRECISION) / Constants.SQUARED_PRECISION);
```

The division `... / SQUARED_PRECISION (1e36)` truncates the result. When the numerator < 1e36, the fee is 0.

### Threshold Analysis (PoC Verified)
| Fee Level | Min Imbalance for Fee > 0 |
|-----------|--------------------------|
| 0.001%    | 100,000 wei ($0.0000000000001) |
| 0.01%     | ~10,000 wei |
| 0.05%     | 2,000 wei |
| 0.1%      | 1,000 wei |

Any deposit with an imbalance below the threshold pays **ZERO** composition fee while still benefiting from the implicit swap.

### Attack Flow
1. Call `LBRouter.addLiquidity()` on the active bin with a skewed composition
2. The skew creates an imbalance requiring an implicit swap
3. The composition fee is calculated as 0 due to rounding down
4. Call `LBRouter.removeLiquidity()` to extract the fee-free swapped value
5. Repeat across multiple pools to drain protocol value

### PoC Output (from test_Exploit_RepeatedCycles)
```
After 100 exploit cycles:
  Final reserves X: 999999999999999999999999000
  Total composition fees collected: X = 0, Y = 0
CONFIRMED: All 100 cycles executed WITHOUT paying any composition fees!
```

### Fix
Change `getCompositionFee` to round UP:
```solidity
return uint128((uint256(amountWithFees) * totalFee * (uint256(totalFee) + Constants.PRECISION) + Constants.SQUARED_PRECISION - 1) / Constants.SQUARED_PRECISION);
```

---

## CRITICAL [C-02]: "Compensation for Composition" - Fee Excluded from Liquidity Denominator

**Severity:** CRITICAL (9.0/10)
**Impact:** Inflated LP shares allow extracting value from existing LPs
**Reference:** Offside Labs / Immunefi (fixed in commit `7e5b0b494`)

### Root Cause
In `LBPair._updateBin()` (line 1072-1084), the share calculation deducts the composition fee from the numerator but does NOT add it to the liquidity denominator:

```solidity
// BUGGY: fee not in denominator
uint256 binLiquidity = binReserves.getLiquidity(price);
shares = userLiquidity.mulDivRoundDown(supply, binLiquidity);

// CORRECT:
uint256 binLiquidity = binReserves.add(fees.sub(protocolCFees)).getLiquidity(price);
shares = userLiquidity.mulDivRoundDown(supply, binLiquidity);
```

### Impact
- Depositors get INFLATED shares when adding to the active bin with skewed composition
- The composition fee that should compensate existing LPs is effectively returned to the depositor
- Combined with C-01, this enables a complete drain of LP value

---

## MEDIUM [M-01]: Swap Fee (rounds UP) vs Composition Fee (rounds DOWN) Inconsistency

**Severity:** MEDIUM
**Impact:** Systematic undercharging of fees for implicit swaps

### Root Cause
Two different rounding strategies create an exploitable discrepancy:
1. Swap fee (`getFeeAmount`): rounds UP - always charges at least 1 wei
2. Composition fee (`getCompositionFee`): rounds DOWN - can be zero for small amounts

### Impact
Users can bypass swap fees by using the add liquidity + remove liquidity path instead of a direct swap, with the composition fee rounding to zero.

---

## MEDIUM [M-02]: Missing Fee Collection Invariant Check in Flash Loan

**Severity:** MEDIUM
**Impact:** Potential underpayment of flash loan fees via balance manipulation

### Root Cause
`LBPair.flashLoan()` checks `balancesAfter >= reservesBefore + totalFees` as a single packed comparison rather than per-token. Composition manipulation during the callback could result in insufficient fee collection in one token.

---

## MEDIUM [M-03]: `_reserves` vs `_bins[]` Desynchronization

**Severity:** MEDIUM
**Impact:** Silent accounting errors accumulating over time

### Root Cause
There is NO consistency check between `_reserves` (total tracked reserves) and the sum of all `_bins[id]` values + `_protocolFees`. A bug in any additive operation (swap, mint, burn, collectProtocolFees) could desynchronize these values.

---

## LOW [L-01]: Direct Token Donation to LBPair Inflates Next Swap Input

**Severity:** LOW
**Impact:** Anyone can grief swap callers by donating tokens to inflate their effective swap amount

### Root Cause
The swap function uses `balanceOf(token) - reserve` to calculate input amounts. A direct ERC20 transfer to the LBPair artificially inflates this difference for the next caller.

---

## LOW [L-02]: `collectProtocolFees` Creates Phantom 1 Wei

**Severity:** LOW
**Impact:** 1 wei of each token permanently locked as protocol fees

### Root Cause
The function stores `ones = 1.encode(1)` as `_protocolFees` even if only one token had fees, creating 1 wei of phantom fees in the other token.

---

## Integration Map

```
User/EoA
  ├─ LBRouter (v2.1 LB Router) ──→ LBPair (swap/mint/burn)
  │     └─ _swapExactTokensForTokens
  │           ├─ V1: MoePair (Uniswap V2 style)
  │           ├─ V2: Legacy LB Pair (deprecated)
  │           └─ V2.1: LBPair (current)
  │
  ├─ MoeRouter (V1 Router) ──→ MoePair (Uniswap V2 style)
  │
  ├─ MasterChef ──→ VeMoe (vote weights) ──→ LB Pools (reward emissions)
  │     └─ deposit/withdraw LP tokens for MOE rewards
  │
  └─ MoeStaking ──→ VeMoe / sMoe
        └─ stake/unstake MOE
```

The critical path for the exploit:
```
Attacker
  → LBRouter.addLiquidity() (skewed amounts)
    → LBPair.mint()
      → BinHelper.getCompositionFees() [VULN C-01: rounds to 0]
      → LBPair._updateBin() [VULN C-02: fee not in denominator]
    → LBRouter.removeLiquidity()
      → LBPair.burn()
  → Extract more value than deposited
```
