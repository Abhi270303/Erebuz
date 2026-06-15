# Agni Finance — Audit Workspace

**Protocol:** Concentrated Liquidity AMM on Mantle Network (Uniswap V3 fork)
**TVL:** ~$20.7M (June 2026)
**Status:** Complete (on-chain + social engineering)

## Findings Summary

### On-Chain (Smart Contracts)
| Severity | Count |
|----------|-------|
| High | 3 (H-01, H-02, H-03) |
| Medium | 3 (M-01, M-02, M-03) |
| Low | 4 (L-01, L-02, L-03, L-04) |
| Info | 2 (I-01, I-02) |
| **Total** | **12** |

### Off-Chain / Social Engineering
| Severity | Count | Key Finding |
|----------|-------|-------------|
| Medium | 2 | M-04: Missing CSP + GTM wallet drainer; M-05: DMARC quarantine (not reject) |
| Low | 2 | L-05: Missing X-Frame-Options (clickjacking); L-06: No security contact |
| Info | 2 | I-03: High social surface area; I-04: Fake "Agni App" brand confusion |
| **Total** | **6** | |

### Combined Total: 18 findings (3 H, 5 M, 6 L, 4 I)

## Key Links
- Website: https://agni.finance/
- Docs: https://agni.gitbook.io/first-workspace/
- Dapp: https://agni.finance/swap
- GitHub: https://github.com/agni-protocol/contracts
- DefiLlama: https://defillama.com/protocol/agni-finance
- Twitter/X: https://x.com/Agnidex
- Telegram: https://t.me/AgniDEXCommunity
- Discord: https://discord.gg/H3YrfAkrGc
- Medium: https://medium.com/@Agnidex

## Key Risk (Off-Chain)
**M-04**: Missing CSP + Google Tag Manager = wallet drainer injection surface if GTM is compromised. Same class as FusionX V3 M-15.
