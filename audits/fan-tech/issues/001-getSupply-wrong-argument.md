# Issue 001: `_getSupply` increase-branch argument inversion inflates effective supply

**Severity**: Critical  
**Type**: Math/Logic Error  
**File**: FanTech.sol (line 514)  
**Status**: Unfixed in deployed `0x20aa28a1f66a6cbd97de8eb1907a5643eef7a108`

## Description

The `_getSupply` function's increase branch (when `pool.value > getPrice(0, supply)`) uses an incorrect argument order in the `getPrice` call:

```solidity
// Line 514 - BUG
_normLiquid2 = getPrice(_supply - supply, supply);
```

The correct call should be `getPrice(0, _supply)` to compare the total curve value for `_supply` shares against the liquid value. Instead, the code computes `getPrice(_supply - supply, supply)` which is the **marginal** price of adding `supply` shares starting from `_supply - supply`.

## Impact

`getPrice(n, supply)` grows as `O(n² · supply)` while `getPrice(0, _supply)` grows as `O(_supply³)`. This discrepancy causes the loop to iterate far longer than intended, returning an inflated `_supply`.

**Consequences:**
- `getBuyPrice(amount)` returns an inflated price (uses inflated `_supply`)
- `getSellPrice(amount)` also computes from inflated `_supply`, but is **capped at `pool.value`**
- For supply=1 pools: the inflated sell price exceeds `pool.value`, causing **sellPrice = pool.value** → **one share drains the entire pool**
- For supply≥2 pools: sell price is inflated up to ~pool.value/supply but never reaches the cap

## Proof

### Mathematical

For a pool with supply=`S` and value=`L`, the buggy `_getSupply` finds `_supply` where `getPrice(_supply-S, S) >= L`.

At loop exit: `getPrice(_supply-S, S) ≈ S·(_supply-S)²·PRICE_A/PRICE_B >= L`
→ `_supply ≈ S + sqrt(L·PRICE_B/(S·PRICE_A))`

Sell price: `min(getPrice(_supply-1, 1), L) = min((_supply-1)²·PRICE_A/PRICE_B, L)`
→ `min((S + sqrt(L·PRICE_B/(S·PRICE_A)))²·PRICE_A/PRICE_B, L)`

For sell price to reach the cap `L`:
`(S + sqrt(L·PRICE_B/(S·PRICE_A)))²·PRICE_A/PRICE_B >= L`
→ `sqrt(1/S) >= 1` (for large L)
→ `S <= 1`

**Only supply=1 triggers the sell-to-liquid cap.**

### On-chain Data

Scanned 40 top pools (out of 7,309 total subjects). None had supply=1:
- Min supply: 2 (most)
- Max supply: 76
- sellPrice < liquid for all 40 pools
- ~17K MNT untracked surplus in contract (contract balance > sum of pool values)

## False Positive Risk

**High.** While the bug is real and causes price calculation errors, no existing pool has supply=1, preventing exploitation. An attacker cannot create a supply=1 pool without the operator's EIP-712 signature (required by `initializeShares`).

## Remediation

Replace line 514:
```solidity
// Current (buggy):
_normLiquid2 = getPrice(_supply - supply, supply);
// Correct:
_normLiquid2 = getPrice(0, _supply);
```

Alternatively, if the intended behavior is to compute effective supply from liquid value, use:
```solidity
_normLiquid2 = getPrice(0, _supply);
```

This makes the increase branch consistent with the decrease branch (line 508 uses `getPrice(0, _supply)`).
