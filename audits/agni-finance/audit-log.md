# Audit log — agni-finance (top-level auditor notebook)

## Coverage
- [x] AgniPool — core pool (swap, mint, burn, flash, collect)
- [x] AgniFactory — pool factory, fee tiers, LM pool deployer
- [x] AgniPoolDeployer — CREATE2 pool deployment
- [x] NonfungiblePositionManager — LP position NFT management
- [x] SwapRouter / SmartRouter — swap routing, multi-hop
- [x] LBPMasterChef / LM Pool — staking / liquidity mining
- [x] IFO contracts — Initial Farm Offering

## Findings

### On-Chain (Contract)
- **3 High** — H-01, H-02, H-03
- **3 Medium** — M-01, M-02, M-03
- **4 Low** — L-01, L-02, L-03, L-04
- **2 Info** — I-01, I-02

### Off-Chain / Social Engineering — 2026-06-15
- **2 Medium** — M-04 (Missing CSP + GTM wallet drainer), M-05 (DMARC quarantine + SPF softfail)
- **2 Low** — L-05 (Missing X-Frame-Options), L-06 (No security contact)
- **2 Info** — I-03 (High social surface area), I-04 (Fake Agni App brand confusion)

## Confirmed Exploits (POC passes)
1. **H-01**: noDelegateCall modifier missing
2. **H-02**: LM pool external calls during swap
3. **H-03**: PoolDeployer setFactoryAddress front-run

## Chaining ideas (Phase 8)

### Chain 1: LM Pool Reentrancy + noDelegateCall → Complete Pool Takeover
- **Findings:** H-02 + H-01
- **Theory:** Deploy proxy (noDelegateCall), bypass admin controls, set malicious LM pool, re-enter during swap with full state control
- **Broken invariants:** INV-01, INV-08, INV-12
- **Priority:** HIGH

### Chain 2: PoolDeployer Front-Run + High Protocol Fees → Malicious Pool Creation
- **Findings:** H-03 + M-03 + M-02
- **Theory:** Front-run setFactoryAddress, deploy pools with extreme fees, disable fee tiers for legitimate factory
- **Broken invariants:** INV-07, INV-09
- **Priority:** MEDIUM

### Chain 3: One-Step Ownership Loss + Fee Tier Freeze → Protocol Lockout
- **Findings:** L-02 + M-02 + M-01
- **Theory:** Ownership lost via one-step transfer, fees/configurations frozen forever
- **Broken invariants:** INV-12, INV-09
- **Priority:** LOW

### Chain 4: LM Pool DoS + NPM Collect Griefing → LP Fund Lock
- **Findings:** H-02 (DoS aspect) + L-04
- **Theory:** LM pool reverts swaps, NPM collect fails due to burn(0) revert
- **Broken invariants:** none (temporary griefing)
- **Priority:** LOW

## Timeline
| Date | Activity | Details |
|------|----------|---------|
| 2026-06-15 | social-engineering | DNS, OSINT, web security, community channel analysis | 6 new findings (M-04, M-05, L-05, L-06, I-03, I-04) |
