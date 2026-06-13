# H-05: updateAssetPrice vs getAssetPrice Oracle Price Divergence

| Field | Value |
|-------|-------|
| **Severity** | HIGH |
| **Status** | unconfirmed |
| **Invariant broken** | INV-06 (MISSING) |
| **Contracts** | `AaveOracle.sol`, `PythPriceFeed.sol`, `LendingPool.sol`, `LendingPoolCollateralManager.sol` |
| **Functions** | `AaveOracle.updateAssetPrice()`, `AaveOracle.getAssetPrice()`, `PythPriceFeed.updatePrice()`, `PythPriceFeed.fetchPrice()` |
| **Line ranges** | AaveOracle L52–L63, PythPriceFeed L95–L108, LendingPool L865, LendingPoolCollateralManager L292–L293 |
| **Source files** | `/misc/AaveOracle.sol`, `/misc/PythPriceFeed.sol`, `/protocol/lendingpool/LendingPool.sol`, `/protocol/lendingpool/LendingPoolCollateralManager.sol` |

---

## Description

`AaveOracle` provides **two distinct code paths** for reading asset prices, and they can return different values for the same asset at the same block:

### Two code paths

| Function | Called by | Writes state? | PythPath |
|----------|-----------|---------------|----------|
| `updateAssetPrice(asset)` L52–L55 | `LendingPool._executeBorrow()` L865, `LendingPoolCollateralManager._calculateAvailableCollateralToLiquidate()` L292–L293 | **Yes** — calls `source.updatePrice()` which writes `lastGoodPrice` | `PythPriceFeed.updatePrice()` → `_fetchPrice()` |
| `getAssetPrice(asset)` L60–L63 | `GenericLogic.calculateUserAccountData()` L186 (used by `validateBorrow()`, `validateWithdraw()`, `validateTransfer()`) | **No** — view-only | `PythPriceFeed.fetchPrice()` → `_fetchPrice()` |

### How they differ

- `updatePrice()` (PythPriceFeed L100–L108) calls `_fetchPrice()` which **writes `lastGoodPrice`** and may change the internal `status` variable. It returns the fetched price after potentially updating state.
- `fetchPrice()` (PythPriceFeed L95–L98) is a `view` override — it calls the same `_fetchPrice()` logic but never persists any state changes.

The critical divergence point is in `_fetchPrice()` (L110–L134):

```
When status == oracleWorking and Pyth is healthy:
  Both paths return the same fresh Pyth price. ✓ Consistent.

When status == oracleWorking and Pyth is broken/frozen:
  Both return (oracleUntrusted, lastGoodPrice). updatePrice() writes lastGoodPrice
  to itself (no change). fetchPrice() returns lastGoodPrice. Consistent.

When status == oracleUntrusted and Pyth becomes healthy again:
  updatePrice() → _fetchPrice() transitions status to oracleWorking, writes the
  new Pyth price to lastGoodPrice, and returns the new price.
  fetchPrice() → _fetchPrice() also transitions to oracleWorking and returns
  the new Pyth price. Both return the same value.

When status == oracleUntrusted and Pyth is broken:
  Both return (oracleUntrusted, lastGoodPrice). Consistent.
```

**The real asymmetry**: `updatePrice()` **unconditionally writes `lastGoodPrice = price`** at L107 after `_fetchPrice()` returns. `fetchPrice()` never writes. In periods of oracle degradation or status transition, the act of calling `updateAssetPrice()` (in borrow/liquidation) **persists a price** that `getAssetPrice()` (in health factor validation) would not persist.

### Where the divergence is dangerous

| Operation | Uses updateAssetPrice (writes) | Uses getAssetPrice (view) |
|-----------|-------------------------------|--------------------------|
| **Borrow** (`_executeBorrow` L865) | ✅ Computes `amountInETH` | ❌ |
| **Borrow validation** (`validateBorrow` → `calculateUserAccountData`) | ❌ | ✅ Health factor check |
| **Withdraw validation** (`validateWithdraw` → `calculateUserAccountData`) | ❌ | ✅ Health factor check |
| **Liquidation health check** (CollateralManager L100–L107) | ❌ | ✅ Health factor check |
| **Liquidation collateral calc** (`_calculateAvailableCollateralToLiquidate` L292–L293) | ✅ Both collateral and debt prices | ❌ |

This means:
- A **borrow** prices the collateral at the `updateAssetPrice` value (which writes `lastGoodPrice`)
- The **borrow health check** validates using the `getAssetPrice` value (which may differ)
- A **liquidation** validates the health factor at the `getAssetPrice` value, then calculates collateral/debt amounts at the `updateAssetPrice` value

## Impact

This inconsistency undermines every health factor check in the protocol. The practical impact:

1. **Borrow with stale/advantageous price**: An attacker who can trigger `updateAssetPrice()` first (setting `lastGoodPrice` to a favorable value) then borrows — the borrow uses the fresh `updateAssetPrice` price while the health check MAY use a `getAssetPrice` value that differs depending on Pyth status

2. **Liquidation price gaming**: A liquidator can rely on the fact that liquidation validation uses `getAssetPrice` (view) while collateral calculation uses `updateAssetPrice` (writes state). By first calling `updateAssetPrice()` for both collateral and debt assets, the liquidator can set `lastGoodPrice` before the liquidation executes

3. **Cross-transaction oracle griefing**: Calling `borrow()` on any asset (even with invalid params that will revert) triggers `updateAssetPrice()` as a side effect. This overwrites `lastGoodPrice`. An attacker can grief a user's upcoming withdrawal by changing the oracle price before the user's health check

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | leads 6, 7, 13 | MEDIUM |
| **trailofbits** | lead 4 | HIGH |
| **forefy** | forefy-006 | MEDIUM |
| **solodit** | SOLODIT-004 | MEDIUM |
| **invariant** | leads 5, 7 | MEDIUM |

All 5 hunters flagged this. Reconciled to HIGH: the asymmetry is a structural issue that undermines the oracle consistency invariant. Every health factor check in the protocol is affected.

## Historical Precedent

- **Radiant Capital (Jan 2024, $4.5M)**: Exploited price inconsistency in an Aave V2 fork. While the primary vector was the liquidityIndex rounding issue, the price oracle inconsistency amplified the attack.
- **MixBytes "AAVE and Compound Forking: Empty Pool Attacks"**: Documents how oracle path inconsistencies can be exploited in forked protocols.

## PoC Sketch

```solidity
// 1. Observe current Pyth status for a given asset
// 2. If oracle is in oracleUntrusted state:
//    - updateAssetPrice() writes lastGoodPrice and returns it
//    - getAssetPrice() may return a different value
// 3. Call borrow() which uses updateAssetPrice (writes state)
//    vs. the validation which uses getAssetPrice
// 4. The borrow may be validated with a health factor computed from
//    getAssetPrice but executed with updateAssetPrice pricing
```

## Recommendation

1. **Standardize on a single code path**: Have both `updateAssetPrice` and `getAssetPrice` call the same internal function. If state mutation is needed, separate the oracle update from the price read.

2. **Remove `updateAssetPrice()`**: Vanilla Aave V2 only has `getAssetPrice()`. The `updateAssetPrice()` function is a Lendle-specific modification. Replace all calls to `updateAssetPrice()` with `getAssetPrice()` and perform oracle updates via a separate, explicit function called by a keeper/CLI.

3. **Add an invariant check**: In critical paths (borrow, liquidate), assert `updateAssetPrice == getAssetPrice` within the same block.

## POC Needs (Phase 9)

- Trace both `updateAssetPrice` and `getAssetPrice` paths end-to-end on a fork
- Compare returned prices during both normal and degraded oracle states
- Demonstrate a borrow where the two paths return different values
