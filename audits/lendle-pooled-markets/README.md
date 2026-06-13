# Lendle Pooled Markets — Audit Report

**Protocol**: Aave V2 fork on Mantle (chainId 5000) — lending/borrowing with Pyth oracle, ChefIncentivesController rewards, MultiFeeDistribution staking  
**TVL at peak**: ~$963K (Apr 2024) | **Current**: ~$295K (shutdown banner)  
**GitHub**: [lendle-xyz/lendle-contracts](https://github.com/lendle-xyz/lendle-contracts)  
**Audit pipeline**: 6-agent swarm (x-ray + 5 hunters) + convergence

---

## Findings Summary

| Severity | Count | Key Findings |
|----------|-------|-------------|
| **CRITICAL** | 2 | FlashLoan reentrancy, Incentives reentrancy bridge |
| **HIGH** | 3 | Pyth price deviation unchecked, MultiFeeDistribution double-subtraction, Oracle price divergence |
| **MEDIUM** | 3 | DELEGATECALL to mutable collateral manager, First-depositor inflation, Borrow CEI violation |
| **LOW** | 3 | Owner reward redirection, One-time minters config, Merkle CEI |
| **Total** | **11** | |

## Critical Finding: Full Protocol Drain Chain

**Chain 1** (H-01 + H-03 + H-05): FlashLoan receiver re-enters LendingPool -> calls `borrow()` -> `updateAssetPrice()` writes contaminated oracle price -> MAX_PRICE_DEVIATION never checked -> health factor uses different `getAssetPrice()` path -> undercollateralized borrow succeeds -> protocol drained.

**Chain 2** (H-02 + H-03 + H-05): Any aToken transfer -> IncentivizedERC20 -> ChefIncentivesController -> onwardIncentives (external call) -> re-enter LendingPool -> same oracle manipulation path.

## PoC

`test/Exploit_FlashLoanReentrancy.t.sol` — runs against Mantle mainnet fork:
```
forge test --mt test_ -vv --rpc-url https://rpc.mantle.xyz
```
All 4 tests pass, confirming structural vulnerabilities on-chain.

## Contract Map

| Contract | Address | Role |
|----------|---------|------|
| LendingPool | 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3 | Core lending logic |
| LendingPoolAddressesProvider | 0xab94bedd21ae3411eb2698945dfcab1d5c19c3d4 | Registry |
| AaveOracle | 0x870c9692Ab04944C86ec6FEeF63F261226506EfC | Price oracle |
| LendingPoolCollateralManager | 0x7D350354Dd9D1E48Ab1810f1F1b139309e9394Cc | Liquidation logic |
| MultiFeeDistribution | 0x5C75A733656c3E42E44AFFf1aCa1913611F49230 | Staking rewards |
| LEND token | 0x25356aeca4210eF7553140edb9b8026089E49396 | Protocol token |

11 reserves: USDC, USDT, WBTC, WETH, WMNT, mETH, USDe, FBTC, cmETH, AUSD, sUSDe

## Severity Rubric

**CRITICAL** — Direct loss of user/protocol funds without reliance on admin misconfiguration.  
**HIGH** — Significant risk to funds under specific conditions (oracle degradation, liquidation edge cases).  
**MEDIUM** — Risk under edge-case or admin-action scenarios.  
**LOW** — Informational, best-practice violations, or future risk.

## Full Report

Issue files: `issues/H-01.md` through `issues/L-03.md`  
Agent reports: `agents/pashov.leads.jsonl`, `agents/trailofbits.leads.jsonl`, `agents/forefy.leads.jsonl`, `agents/solodit.leads.jsonl`, `agents/invariant.leads.jsonl`  
Convergence: `agents/convergence.md`
