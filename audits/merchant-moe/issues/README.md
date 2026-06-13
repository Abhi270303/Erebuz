# Merchant Moe Liquidity Book - Audit Conclusion

## Summary
Comprehensive security audit of Merchant Moe's Liquidity Book protocol (Trader Joe v2 fork on Mantle chain). The audit covered core LB contracts (LBPair, LBRouter, LBFactory, LBToken), rewarders (lb-rewarder), and protocol contracts (MasterChef, MoeStaking, VeMoe).

## Findings

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| C-01 | CRITICAL | `getCompositionFee` rounds DOWN — **path unreachable in v2.1** | Deferred (math proof) |
| H-01 | HIGH | First-deposit sqrt in `getSharesAndEffectiveAmountsIn` lacks MINIMUM_LIQUIDITY burn | Confirmed |
| M-01 | MEDIUM | `VeMoe._getVeMoe` cap uses `oldBalance` instead of `newBalance` | Confirmed |
| M-02 | MEDIUM | Duplicate PID in `vote()` enables flash vote+unvote bribe extraction | Confirmed |
| M-03 | MEDIUM | Direct token transfers to LB pairs extractable by next minter | Confirmed |
| L-01 | LOW | Hooks `after*` callbacks outside reentrancy guard | Confirmed |
| L-02 | LOW | `VeMoe._vote` reentrancy via `bribe.onModify` → `setBribes` | Confirmed |

## Key Findings Detail

### H-01: First-Deposit Inflation Attack (no MINIMUM_LIQUIDITY)
`BinHelper.sol:84` — `shares = sqrt(userLiquidity)` when bin total supply is 0. No MINIMUM_LIQUIDITY burn (Uniswap V2 burns `10**3`). First depositor can inflate share price. Donation to pair backfires — the donation is refunded to the next minter, not the first depositor. Pair also lacks a `skim()` function.

### M-01: veMoe Cap Bug
`VeMoe.sol:646` — `maxVeMoe = oldBalance * M` instead of `newBalance * M` when staking more MOE. Users who stake incrementally get permanently less veMoe. Loss-only, not inflatable.

### M-02: Flash Vote+Unvote
`VeMoe.sol:333` — No duplicate PID check. `vote([X,X], [+N,-N])` triggers two bribe `onModify` calls with zero net voting, enabling bribe extraction without contributing votes.

### M-03: Donation Extraction
`LBPair.sol:671` — `amountsReceived = balanceOf - reserve`. Direct transfers to the pair inflate `amountsReceived`; excess `amountsLeft` is refunded to the minter.

## No Critical Drain Found
- **Composition fee** (C-01): mathematically unreachable — fee is always zero
- **VeMoe flash loan voting**: prevented by time-based veMoe accrual
- **MasterChef rewards**: standard accDebtPerShare pattern, correct
- **MoePair/MoeRouter**: standard Uniswap V2 clone, battle-tested
- **LB swap rounding**: `mulDivRoundDown` always rounds in pool's favor

## Contracts Analyzed
- `/tmp/joe-v2/src/LBPair.sol` (1107 lines) — Core swap/mint/burn
- `/tmp/joe-v2/src/LBRouter.sol` (1135 lines) — Swap routing
- `/tmp/joe-v2/src/LBFactory.sol` (756 lines) — Pair factory
- `/tmp/joe-v2/src/LBToken.sol` (244 lines) — LP tokens (ERC-1155)
- `/tmp/joe-v2/src/libraries/BinHelper.sol` — Share/fee calculation
- `/tmp/joe-v2/src/libraries/FeeHelper.sol` — Fee math
- `/tmp/moe-core/src/MasterChef.sol` — Staking rewards
- `/tmp/moe-core/src/MoeStaking.sol` — MOE staking
- `/tmp/moe-core/src/VeMoe.sol` — Vote-escrowed MOE
- `/tmp/moe-core/src/Moe.sol` — MOE token
- `/tmp/moe-core/src/dex/MoePair.sol` — Traditional AMM (Uniswap V2 clone)
- `/tmp/lb-rewarder/src/LBHooksBaseRewarder.sol` — Reward hook
- `/tmp/lb-rewarder/src/LBHooksMCRewarder.sol` — MasterChef rewarder
- `/tmp/lb-rewarder/src/LBHooksManager.sol` — Hook manager

## PoC Location
`/Users/0xabhii/defi-audits/audits/merchant-moe/test/Exploit_PoC.t.sol`

## References
- [Code4rena Trader Joe v2 Report](https://code4rena.com/reports/2022-10-traderjoe)
- [Offside Labs - "Compensation for Composition"](https://blog.offside.io/p/compensation-for-composition)
- [Merchant Moe Docs](https://docs.merchantmoe.com/resources/contracts)
- [Merchant Moe Audits](https://docs.merchantmoe.com/resources/audits)
