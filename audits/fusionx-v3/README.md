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

### Off-Chain (Web / Social Engineering)
| Severity | Count | Key Finding |
|----------|-------|-------------|
| High | 2 | H-03: DMARC/DKIM missing → email spoofing; H-04: Fake FSX token scams |
| Medium | 3 | M-15: Missing CSP enables GTM wallet drainer; M-16: PancakeSwap fork review needed; M-17: Community channel impersonation |
| Low | 3 | L-07: Missing security headers; L-08: No security contact; L-09: Source map disclosure |
| Info | 2 | I-03: Hardcoded addresses; I-04: Coverage gaps |
| **Total** | **10** | |

## Key Exploit Chain (On-Chain)
1. Donate 1 wei RFSX to MasterChef (no tracked amount increase)
2. Trigger harvest where amount ≥ balance → `fusionXAmountBelongToMC = 0`
3. `sweepToken(RFSX, 0, attacker)` → drains ALL RFSX
4. `sweepToken(USDC, 0, attacker)` → drains ALL USDC
5. `unwrapWETH9(0, attacker)` → drains ALL ETH

## Key Off-Chain Risk
**H-03**: Missing DMARC/DKIM — anyone can spoof @fusionx.finance email. Combined with M-15 (GTM injection vector), an attacker could deliver a wallet drainer via a convincing phishing email from the legitimate domain.

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

## Agents Run (Social Engineering)
social-engineering-audit
