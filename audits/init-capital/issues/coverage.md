# Convergence Report — INIT Capital Security Audit

## Swarm Execution

| Agent | Status | Leads Generated | Completion |
|-------|--------|----------------|------------|
| X-Ray (threat model) | Complete | 11 attack vectors, 5 hot contracts | ✅ |
| Pashov (8-lens manual) | Complete | 11 leads (3 critical, 2 high, 5 med, 1 low) | ✅ |
| Trail of Bits (Slither + manual) | Complete | 5 leads (1 critical, 1 high, 3 med) | ✅ |
| Forefy (attacker-story) | Complete | 5 leads (1 critical, 1 high, 3 med) | ✅ |
| Solodit (historical patterns) | Complete | 11 leads mapped to Solodit checklist | ✅ |

## Merged Findings (after deduplication)

### CRITICAL

| ID | Finding | Contracts | Pashov | ToB | Forefy | Solodit |
|----|---------|-----------|--------|-----|--------|---------|
| CRIT-001 | `callback()` + `multicall()` missing `nonReentrant` — unbounded reentrancy with deferred health checks | InitCore.sol, Multicall.sol | ✅ | ✅ | ✅ | ✅ |

### HIGH

| ID | Finding | Contracts | Pashov | ToB | Forefy | Solodit |
|----|---------|-----------|--------|-----|--------|---------|
| HIGH-001 | `MarginTradingHook.fillOrder()` no access control, no `nonReentrant` | MarginTradingHook.sol | ✅ | ✅ | ✅ | ✅ |
| HIGH-002 | wLP `calculatePrice_e36` external oracle — potential spot-price manipulation | InitCore (liquidateWLp) | ❌ | ❌ | ✅ | ❌ |

### MEDIUM

| ID | Finding | Contracts | Pashov | ToB | Forefy | Solodit |
|----|---------|-----------|--------|-----|--------|---------|
| MED-001 | `InitOracle` single-source fallback bypasses deviation check | InitOracle.sol | ✅ | ❌ | ✅ | ❌ |
| MED-002 | `MoneyMarketHook` msg.value double-consumption in loop | MoneyMarketHook.sol | ✅ | ✅ | ❌ | ✅ |
| MED-003 | `LendingPool.mint()` ∆-balance accounting breaks for fee-on-transfer / donations | LendingPool.sol | ✅ | ❌ | ❌ | ✅ |
| MED-004 | Debt share consistency gap: no cross-check between PosManager and RiskManager | PosManager.sol, RiskManager.sol | ✅ | ❌ | ❌ | ✅ |
| MED-005 | `LiqIncentiveCalculator` returns 0 incentive for bad debt (health=0) | LiqIncentiveCalculator.sol | ✅ | ❌ | ❌ | ✅ |

### LOW / INFORMATIONAL

| ID | Finding | Contracts | All |
|----|---------|-----------|-----|
| LOW-001 | `setPosMode()` order of operations — RiskManager update before PosManager | InitCore.sol | Pashov |
| LOW-002 | Debt share precision — borrow rounding direction analysis | LendingPool.sol | Pashov |
| LOW-003 | ERC4626 virtual shares — non-standard decimals for integration concerns | LendingPool.sol | Solodit |

## Invariant Coverage

| Invariant | Status | Notes |
|-----------|--------|-------|
| Position health ≥ 1e18 after state change | ENFORCED | ensurePositionHealth modifier |
| ALL modified positions checked after multicall | ENFORCED | uncheckedPosIds loop |
| `callback()` cannot be called during nonReentrant context | **BROKEN** | CRIT-001 |
| `multicall()` cannot be re-entered | **BROKEN** | CRIT-001 |
| Flash may not be called inside multicall | ENFORCED | `!isMulticallTx` check |
| Mode debt ceiling enforced | ENFORCED | RiskManager.sol |
| Mode debt shares == sum(pos debt shares) | **UNCHECKED** | No cross-reference |
| Pool cash + totalDebt == actual balance | ASSUMED | ∆-balance tracking |
| Liquidation post-health <= maxHealthAfterLiq | ENFORCED | unless uint64.max or health==0 |
| Virtual shares protect against inflation | ENFORCED | VIRTUAL_SHARES=1e8 |

## Agent-by-Contract Coverage Matrix

| Contract | X-Ray | Pashov | ToB | Forefy | Solodit |
|----------|-------|--------|-----|--------|---------|
| InitCore.sol | ✅ | ✅ | ✅ | ✅ | ✅ |
| Multicall.sol | ✅ | ✅ | ✅ | ✅ | ✅ |
| LendingPool.sol | ✅ | ✅ | ✅ | ✅ | ✅ |
| PosManager.sol | ✅ | ✅ | ❌ | ❌ | ✅ |
| MarginTradingHook.sol | ✅ | ✅ | ✅ | ✅ | ✅ |
| MoneyMarketHook.sol | ✅ | ✅ | ✅ | ❌ | ✅ |
| InitOracle.sol | ✅ | ✅ | ❌ | ✅ | ❌ |
| RiskManager.sol | ✅ | ✅ | ❌ | ❌ | ✅ |
| LiqIncentiveCalculator.sol | ✅ | ✅ | ❌ | ❌ | ✅ |
| Config.sol | ✅ | ✅ | ❌ | ❌ | ❌ |

## PoC Delivered

| File | Path | Status |
|------|------|--------|
| CallbackReentrancy.t.sol | `audits/init-capital/pocs/CallbackReentrancy.t.sol` | ✅ — structural proofs; requires Mantle RPC + token funding for full value extraction |

## Summary

- **Critical findings:** 1 (CRIT-001: callback + multicall reentrancy)
- **High findings:** 2 (HIGH-001, HIGH-002)
- **Medium findings:** 5 (MED-001 through MED-005)
- **Low findings:** 3 (LOW-001 through LOW-003)
- **Broken invariants:** 2 (INV-03: callback nonReentrant, INV-08: multicall nonReentrant)
- **Unchecked invariants:** 1 (INV-12: debt share cross-reference)
