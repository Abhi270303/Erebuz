# FusionX V3 — Audit Workspace

**Protocol:** Concentrated Liquidity AMM on Mantle Network (Uniswap V3 fork)
**TVL:** ~$102K (June 2026)
**Status:** Complete (on-chain + off-chain)

## Findings Summary

### On-Chain (Smart Contracts)
| Severity | Count |
|----------|-------|
| High | 2 (H-01, H-02) |
| Medium | 14 (M-01 — M-14) |
| Low | 6 (L-01 — L-06) |
| Info | 2 (I-01, I-02) |
| **Total** | **24** |

### Off-Chain (Web / Dapp)
| Severity | Count | Key Finding |
|----------|-------|-------------|
| Medium | 2 | M-15: Missing CSP enables GTM wallet drainer; M-16: PancakeSwap fork review needed |
| Low | 3 | L-07: Missing security headers; L-08: No security contact; L-09: Source map disclosure |
| Info | 2 | I-03: Hardcoded addresses; I-04: Coverage gaps |
| **Total** | **7** | |

## Key Exploit Chain (On-Chain)
1. Donate 1 wei RFSX to MasterChef (no tracked amount increase)
2. Trigger harvest where amount ≥ balance → `fusionXAmountBelongToMC = 0`
3. `sweepToken(RFSX, 0, attacker)` → drains ALL RFSX
4. `sweepToken(USDC, 0, attacker)` → drains ALL USDC
5. `unwrapWETH9(0, attacker)` → drains ALL ETH

## Key Off-Chain Risk
Missing Content-Security-Policy header + Google Tag Manager = wallet drainer injection surface if GTM is compromised. Corroborated by 4 independent agents.

## Key Links
- Website: https://fusionx.finance/
- Docs: https://docs.fusionx.finance/
- Dapp: https://fusionx.finance/swap
- GitHub: https://github.com/fusionx-finance
- DeFiLlama: https://defillama.com/protocol/fusionx-finance

## Agents Run (Contract Swarm)
x-ray, pashov, trailofbits, forefy, solodit, invariant, converge

## Agents Run (Off-Chain Swarm)
pentestswarm, cai, hexstrike, pentagi, pentestgpt, converge
