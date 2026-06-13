# Merchant Moe Liquidity Book - Audit Conclusion

## Summary
Comprehensive security audit of Merchant Moe's Liquidity Book protocol (Trader Joe v2 fork on Mantle chain). The audit covered core LB contracts (LBPair, LBRouter, LBFactory, LBToken), rewarders (lb-rewarder), and protocol contracts (MasterChef, MoeStaking, VeMoe).

## Findings

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| C-01 | CRITICAL | `getCompositionFee` rounds DOWN to zero - fee-free implicit swaps | Confirmed (PoC) |
| C-02 | CRITICAL | "Compensation for Composition" - fee not in liquidity denominator | Confirmed |
| M-01 | MEDIUM | Swap fee (UP) vs Composition fee (DOWN) inconsistency | Confirmed (PoC) |
| M-02 | MEDIUM | Flash loan fee check uses single packed comparison | Confirmed |
| M-03 | MEDIUM | `_reserves` vs `_bins[]` can desynchronize | Confirmed |
| L-01 | LOW | Direct donation inflates swap input | Confirmed |
| L-02 | LOW | Phantom 1 wei in protocol fees | Confirmed |

## PoC Results
All 8 Foundry tests pass, proving:
- Composition fee rounds to ZERO for imbalances below threshold
- 100 exploit cycles execute with ZERO composition fees collected
- Swap fees (round UP) vs composition fees (round DOWN) inconsistency
- Exact mathematical threshold derivation

## Critical Exploit Chain
1. Flash loan a large amount of tokens
2. Exploit C-01: deposit skewed composition - fee rounds to 0
3. Exploit C-02: get inflated LP shares (fee not in denominator)
4. Remove liquidity - extract value from existing LPs
5. Repeat across all pools
6. Repay flash loan

## Key Contracts Analyzed
- `/tmp/joe-v2/src/LBPair.sol` (1107 lines) - Core swap logic
- `/tmp/joe-v2/src/LBRouter.sol` (1135 lines) - Router
- `/tmp/joe-v2/src/LBFactory.sol` (756 lines) - Factory
- `/tmp/joe-v2/src/LBToken.sol` (244 lines) - LP tokens
- `/tmp/joe-v2/src/libraries/FeeHelper.sol` - Fee calculation (vulnerable)
- `/tmp/joe-v2/src/libraries/BinHelper.sol` - Composition fee (vulnerable)
- `/tmp/joe-v2/src/libraries/PairParameterHelper.sol` - Fee parameters
- `/tmp/moe-core/src/MasterChef.sol` - Staking rewards
- `/tmp/moe-core/src/MoeStaking.sol` - MOE staking
- `/tmp/moe-core/src/VeMoe.sol` - Voting escrow
- `/tmp/lb-rewarder/src/LBHooksBaseRewarder.sol` - Hooks rewarder

## PoC Location
`/Users/0xabhii/defi-audits/audits/merchant-moe/test/Exploit_PoC.t.sol`

## References
- [Code4rena Trader Joe v2 Report](https://code4rena.com/reports/2022-10-traderjoe)
- [Offside Labs - "Compensation for Composition"](https://blog.offside.io/p/compensation-for-composition)
- [Merchant Moe Docs](https://docs.merchantmoe.com/resources/contracts)
- [Marchent Moe Audits](https://docs.merchantmoe.com/resources/audits)
