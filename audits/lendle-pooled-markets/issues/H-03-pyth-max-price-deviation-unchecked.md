# H-03: PythPriceFeed MAX_PRICE_DEVIATION Never Checked + getPriceUnsafe Allows Stale/Manipulated Prices

| Field | Value |
|-------|-------|
| **Severity** | HIGH |
| **Status** | unconfirmed |
| **Invariants broken** | INV-07 (MISSING), INV-06 (MISSING — amplifying) |
| **Contract** | `PythPriceFeed.sol` |
| **Functions** | `_fetchPrice()`, `_getCurrentResponse()`, `updatePrice()` |
| **Line ranges** | L30 (constant), L95–L134 (_fetchPrice), L190–L210 (_getCurrentResponse), L100–L108 (updatePrice) |
| **Source file** | `/misc/PythPriceFeed.sol` |

---

## Description

**Three independent failures combine to make the Pyth oracle accept arbitrarily stale, incorrect, or manipulated prices** with no circuit breaker.

### Failure 1: MAX_PRICE_DEVIATION defined but never enforced

At `PythPriceFeed.sol` L30:
```solidity
uint256 public constant MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND = 5e17; // 50%
```

This constant is **declared but never referenced** in any `require()`, `if()` condition, or comparison anywhere in the codebase. When the oracle transitions from `oracleUntrusted` back to `oracleWorking` (`_fetchPrice` L132), the new Pyth price is accepted directly:

```solidity
return (Status.oracleWorking, response.answer);
```

No check against `lastGoodPrice`. A price that differs by **1000%** from the last trusted price would be silently accepted.

### Failure 2: getPriceUnsafe() wrapped in try/catch — never reverts

`_getCurrentResponse()` at L196–L209:
```solidity
try oracle.getPriceUnsafe(priceId) returns (PythStructs.Price memory price) {
    // ...populates response
} catch {
    return response;  // returns zeroed response with success=false
}
```

`getPriceUnsafe()` is the Pyth function that explicitly **does not validate staleness**. Pyth's documentation warns: *"This function may return a price from arbitrarily far in the past."* The try/catch pattern suggests the developer believed `getPriceUnsafe` could revert, but in practice it always succeeds — even with stale/old data.

The result: Pyth prices that are hours or days old are returned as "current" with no timestamp validation beyond the `TIMEOUT` check (which has a generous threshold).

### Failure 3: updatePrice() is permissionless (anyone can call)

`updatePrice()` at L100–L108:
```solidity
function updatePrice() external override returns (uint256) {
    (Status newStatus, uint256 price) = _fetchPrice();
    lastGoodPrice = price;
    // ...
}
```

Anyone can call this function at any time. Combined with the above:
- Any user can write to `lastGoodPrice` by calling `updatePrice()`
- If Pyth is in a degraded state, `_fetchPrice()` returns `lastGoodPrice` unchanged (no change)
- But if Pyth returns any data (even stale), `lastGoodPrice` is overwritten with it
- There is **no access control** on who can trigger an oracle update

### Impact accumulation

With 11 `PythPriceFeed` instances deployed (one per supported asset), the broad oracle surface means failure of any single Pyth feed affects the corresponding asset's borrow/liquidation calculations.

## Impact

An attacker can:

1. **Exploit oracle downtime**: During a period when Pyth stops updating a price feed, call `updatePrice()` to freeze an advantageous price into `lastGoodPrice`
2. **Flash loan sandwich on Pyth**: Influence Pyth's on-chain price within a single block, then borrow/liquidate before the price corrects
3. **Post-outage price spike**: When Pyth comes back online after an outage, the first `updatePrice()` sets `lastGoodPrice` to whatever Pyth returns (potentially extreme) — no deviation check prevents this

All three of these feed into the core lending operations: borrow (via `updateAssetPrice()`), liquidation (via `updateAssetPrice()` in `_calculateAvailableCollateralToLiquidate()`), and health factor checks (via `getAssetPrice()`).

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | leads 4, 5, 12 | MEDIUM |
| **trailofbits** | leads 2, 8 | CRITICAL |
| **forefy** | leads 4, 9, 10 | HIGH |
| **solodit** | lead 3 | HIGH |
| **invariant** | leads 3, 4 | HIGH |

All 5 hunters confirmed the deviation check is missing. Reconciled to HIGH: the deviation check alone is a HIGH-severity gap, amplified to CRITICAL only when combined with flashLoan reentrancy (H-01).

## Historical Precedent

- **IDEX (Immunefi Boost #34239)**: `getPriceUnsafe` without `publishTime` check. Fix recommended: use `getPriceNoOlderThan()` or manually validate `publishTime`.
- **Mach Finance (Sherlock 2024 #33, #39)**: Same issue — `_getLatestPrice()` uses `getPriceUnsafe` without freshness validation. Both sponsor-confirmed with fix.
- **Radiant Capital (2024, $4.5M)**: Exploited price inconsistency in Aave V2 fork. The oracle manipulation path was central to the attack.

## PoC Sketch

```solidity
// Forge unit test concept
// 1. Deploy PythPriceFeed with a mock Pyth oracle
// 2. Set mock Pyth to return price = 1000 (oracleWorking state)
// 3. Call updatePrice() → lastGoodPrice = 1000
// 4. Set mock Pyth to return price = 100000 (100x, no valid reason)
// 5. Call updatePrice() → NO REVERT, lastGoodPrice = 100000
//    Expected: revert because 100000 > 1000 * (1 + 50%) = 1500
//    Actual: accepted silently
// 6. Now borrow() against collateral valued at 100x real price
```

## Recommendation

1. **Enforce the deviation check**: In `PythPriceFeed._fetchPrice()`, before returning `response.answer`, compare it against `lastGoodPrice`. Revert if deviation exceeds `MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND`:
   ```solidity
   if (lastGoodPrice > 0) {
       uint256 deviation = response.answer > lastGoodPrice
           ? response.answer - lastGoodPrice
           : lastGoodPrice - response.answer;
       require(deviation * 1e18 <= lastGoodPrice * MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND,
           "Price deviation exceeds max");
   }
   ```

2. **Use `getPriceNoOlderThan()`** instead of `getPriceUnsafe()` with a maxAge parameter, or validate `publishTime` against `block.timestamp` with a reasonable tolerance.

3. **Add access control** to `updatePrice()` or at minimum emit an event when it's called.

4. **Circuit breaker**: If the oracle has been in `oracleUntrusted` state for more than a configurable timeout, pause the affected asset's borrow/liquidation operations.

## POC Needs (Phase 9)

- Forge unit test with mock Pyth oracle
- Verify that >50% price deviation is accepted without revert
- Demonstrate a borrow/liquidation using the manipulated price
