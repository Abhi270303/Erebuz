# Audit log — FusionX V3 (Complete)

## Coverage
- [x] FusionXV3Pool — core pool (swap, mint, burn, flash, collect)
- [x] FusionXV3Factory — pool factory, fee tiers, LM pool deployer
- [x] FusionXV3PoolDeployer — CREATE2 pool deployment
- [x] NonfungiblePositionManager — LP position NFT management
- [x] V3SwapRouter / SmartRouter — swap routing, multi-hop, V2+V3+Stable
- [x] LBPMasterChefV3 — staking / reward distribution
- [x] FusionXV3LmPool — liquidity mining, reward accumulation
- [x] IFO contracts — Initial Farm Offering

## Swarm Run Summary
- **x-ray**: Hot contracts ranked, 30+ invariants documented, threat model built
- **Pashov**: 10 leads (2 H, 3 M, 4 L, 1 I)
- **Trail of Bits**: 10 leads (2 H, 4 M, 3 L, 1 I)
- **Forefy**: 10 leads (2 H, 4 M, 3 L, 1 I)
- **Solodit**: 10 leads (3 H, 2 M, 3 L, 2 I)
- **Invariant**: 6 leads (2 M, 2 L, 2 I)

## Findings
### On-Chain (Contract)
- **2 High** — H-01, H-02
- **14 Medium** — M-01 through M-14
- **6 Low** — L-01 through L-06
- **2 Info** — I-01, I-02

### Off-Chain (Web / Social Engineering) — 2026-06-15
- **4 High** — H-01, H-02 (on-chain), H-03 (DMARC/DKIM → email spoofing), H-04 (Fake FSX token scams)
- **3 Medium** — M-15 (Missing CSP enables GTM-driven wallet drainer), M-16 (PancakeSwap fork — shared frontend vulns), M-17 (Community channel impersonation)
- **3 Low** — L-07 (Missing security headers), L-08 (No security contact), L-09 (Potential source map disclosure)
- **2 Info** — I-03 (Hardcoded addresses in bundle), I-04 (Coverage gaps)

## Confirmed Exploits (POC passes)
1. **H-01**: sweepToken() / unwrapWETH9() — missing access control, any wallet drains all non-RFUSIONX tokens
2. **H-02**: _safeTransfer() else branch inflates fusionXAmountBelongToMC — accounting corruption enables full RFUSIONX drain
3. **Full chain**: H-02 + H-01 = any wallet drains ALL tokens from MasterChef

## Live on-chain confirmation
- MasterChef: 0xF6efaDb0fD3504EE1d55A3c35a8C5755aE78044e
- RFSX: 0xb7feC4ff66b32764758A7DF9D6410F6279929a7E
- MC holds 3,277,909,863,530,384,561,440,850 RFSX
- Unaccounted surplus: ~15,744 RFSX

## Key exploit chain
Step 1: Donate 1 wei RFSX to MC (no tracked amount increase)
Step 2: Trigger harvest where _amount >= balance → BUG: fusionXAmountBelongToMC = 0
Step 3: sweepToken(RFSX, 0, attacker) → drains ALL RFSX
Step 4: sweepToken(USDC, 0, attacker) → drains ALL USDC
Step 5: unwrapWETH9(0, attacker) → drains ALL ETH

## Off-Chain Swarm Summary (2026-06-15)
- **pentestswarm**: 5 leads — source maps, GTM risk, missing security.txt, CDN, hardcoded addresses
- **cai**: 5 leads — missing CSP, GitBook SSRF, affiliate IDOR, missing XFO, RPC DoS
- **hexstrike**: 4 leads — missing headers (CSP/XFO/XCTO), PancakeSwap fork detection
- **pentagi**: 3 leads — GTM→wallet drainer chain, subgraph enumeration, fork inheritance
- **pentestgpt**: 2 leads — coverage gaps, lead verification

### Social Engineering Audit — 2026-06-15
- **social-engineering-audit**: 4 findings — H-03 (DMARC/DKIM missing → email spoofing), H-04 (Fake FSX token impersonation), M-17 (Community channel impersonation), SE-004 (No security contact — redundant with L-08)
- **2 High, 1 Medium** — email phishing + fake token scams are the highest social engineering risks

### Key off-chain finding
**M-15**: Missing Content-Security-Policy + Google Tag Manager = wallet drainer injection surface. Corroborated by 4 agents. This is the highest-risk off-chain finding and should be prioritized for remediation (add CSP header).

### Key social engineering finding
**H-03**: Missing DMARC/DKIM — anyone can spoof @fusionx.finance email. Combined with M-15 (GTM injection vector), an attacker could deliver a wallet drainer via a convincing phishing email from the legitimate domain.
