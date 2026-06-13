# Audit log — init-capital (top-level auditor notebook)

## Coverage
- [x] InitCore.sol (602 lines) — full review
- [x] Multicall.sol (43 lines) — full review
- [x] LendingPool.sol (268 lines) — full review
- [x] PosManager.sol (362 lines) — full review
- [x] RiskManager.sol (91 lines) — reviewed
- [x] MarginTradingHook.sol (631 lines) — full review
- [x] MoneyMarketHook.sol (318 lines) — reviewed
- [x] InitOracle.sol (125 lines) — reviewed
- [x] LiqIncentiveCalculator.sol (116 lines) — reviewed
- [x] Config.sol (168 lines) — reviewed
- [x] All interfaces and libraries — skimmed

## Swarm Execution
- [x] X-ray: complete (5 hot contracts, 11 vectors)
- [x] Pashov: complete (11 leads: 3C, 2H, 5M, 1L)
- [x] Trail of Bits: complete (5 leads: 1C, 1H, 3M)
- [x] Forefy: complete (5 leads: 1C, 1H, 3M)
- [x] Solodit: complete (11 leads matched to historical patterns)

## Key Findings
- **CRIT-001**: `callback()` + `multicall()` missing `nonReentrant` — confirmed by all 4 agents. Foundry PoC at `pocs/CallbackReentrancy.t.sol`.
- **HIGH-001**: `MarginTradingHook.fillOrder()` — no access control, no `nonReentrant`.
- **MED-001**: `InitOracle` single-source fallback bypasses deviation check.

## Hunches (not yet findings)
- wLP `calculatePrice_e36` might use DEX spot prices — not verifiable without wLP source code
- Debt share drift between PosManager and RiskManager over many borrow/repay cycles — needs fuzz test
- Bad debt cleanup incentive = 0 could lead to protocol insolvency

## Chaining ideas (Phase 8)
- CRIT-001 + wLP manipulation = forced unfair liquidations via callback reentrancy
- CRIT-001 + permissionless liquidate() = capital-free liquidation extraction
- fillOrder() no access control + oracle manipulation = MEV sandwich
- flash() nonReentrant + callback() no guard = flash-within-flash (double-dip)

## Questions for the protocol team
- Is the wLP `calculatePrice_e36` implementation using DEX spot prices or a TWAP?
- Why does `callback()` intentionally lack `nonReentrant`? Oversight or design?
- Are there plans to add invariant cross-checks between PosManager and RiskManager debt shares?
