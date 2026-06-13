# Merchant Moe — Audit Log

## Phase 1-4 (Completed)
- Target: Merchant Moe (Trader Joe v2 fork on Mantle)
- Source: joe-v2, moe-core, lb-rewarder repos
- DefiLlama: 4 LB pairs + MOE/MNT, MasterChef, VeMoe, MoeStaking

## Phase 5 — Bug Hunt Swarm

### Agent: Composition Fee (Pashov/ToB lenses)
- Identified C-01 (rounding down) and C-02 (fee not in denominator)
- Built 8 Foundry mock tests
- **Critical update**: Mathematical proof + 10k×10k brute-force showed the fee path is **unreachable**
- `getSharesAndEffectiveAmountsIn` aligns deposits to bin ratio; received amount always equals deposited amount

### Agent: VeMoe Vote Manipulation
- Checked: flash loan vote manipulation — **blocked** by time-based veMoe accrual
- Found: M-01 (`oldBalance` cap bug — under-rewards only)
- Found: M-02 (duplicate PID vote — bribe extraction)
- Found: L-02 (reentrancy in `_vote` via `bribe.onModify`)

### Agent: LBHooks Reward Extraction
- Checked: reward doubling, range manipulation, precision — all correct
- Found: per-bin rewards use proper accrual pattern

### Agent: LBPair Swap Logic
- Checked: first-deposit, rounding, flash loan, oracle
- Found: H-01 (no MINIMUM_LIQUIDITY burn)
- Found: M-03 (donation extraction / missing skim)
- Found: L-01 (hooks after* callbacks outside reentrancy guard)

### Agent: MasterChef / MoePair / MoeRouter
- MasterChef: standard accDebtPerShare — correct
- MoePair: standard Uniswap V2 clone — battle-tested
- MoeRouter: standard routing — correct

## Phase 6 — Solodit Historical Research
- Previous Trader Joe v2 audits: C4 Oct 2022, Offside Labs
- C4 findings about bin step verification, oracle sample math, rounding  
- Offside Labs: "Compensation for Composition" — the direct inspiration for C-02
- Both findings applied to older codebase with different share calculation

## Phase 7 — Findings Documented
- `C-01-comp-fee-rounding.md` — Updated with path-unreachable proof
- `H-01-first-deposit-sqrt.md` — New
- `M-01-veMoe-oldBalance-cap.md` — New
- `M-02-flash-vote-bribes.md` — New
- `M-03-donation-extraction.md` — New
- `L-01-hooks-reentrancy.md` — New
- `L-02-veMoe-reentrancy.md` — New

## Phase 8 — Integration Mapping
- LB pairs ↔ MasterChef (via LBHooksMCRewarder as sink tokens)
- MoeStaking ↔ VeMoe ↔ MasterChef (staking → voting → reward distribution)
- Traditional MoePair/MoeRouter operates independently from LB system
- No cross-protocol composability issues found

## Phase 9 — POCs
- `test/Exploit_PoC.t.sol` — 8 mock tests for composition fee rounding (passing)
- `pocs/ForkExploit.sol` — Fork script for composition fee (compiles, but fee = 0)
- `pocs/FlashLoanExploit.sol` — Flash loan amplifed fork (compiles, but fee = 0)

## Phase 10 — Conclusion

### Critical Finding Path: None Found
The original exploit hypothesis (C-01 + C-02 composition fee → share inflation → value extraction) was mathematically disproven. No alternative critical path was found.

### Most Impactful Findings
1. **H-01**: First-deposit sqrt lacks MINIMUM_LIQUIDITY burn — economic attack on new bins
2. **M-01**: veMoe under-allocation — real loss for incremental stakers  
3. **M-02**: Duplicate PID bribe extraction — design flaw enabling reward gaming
4. **M-03**: Donation extraction — missing skim function

### Verdict
No protocol-drain critical vulnerability. The codebase is well-structured with proper access controls and standard DeFi primitives. Medium/Low findings represent real bugs with limited financial impact.
