# Audit log — agni-finance (top-level auditor notebook)

## Coverage
- [ ] <contract / function reviewed?>

## Hunches (not yet findings)
- 

## Chaining ideas (Phase 8)

### Chain 1: LM Pool Reentrancy + noDelegateCall → Complete Pool Takeover
- **Findings:** H-02 + H-01
- **Theory:** Deploy proxy (noDelegateCall), bypass admin controls, set malicious LM pool, re-enter during swap with full state control
- **Broken invariants:** INV-01, INV-08, INV-12
- **Priority:** HIGH — most dangerous potential exploit

### Chain 2: PoolDeployer Front-Run + High Protocol Fees → Malicious Pool Creation
- **Findings:** H-03 + M-03 + M-02
- **Theory:** Front-run setFactoryAddress, deploy pools with extreme fees, disable fee tiers for legitimate factory
- **Broken invariants:** INV-07, INV-09
- **Priority:** MEDIUM — deployment-time window but permanent damage

### Chain 3: One-Step Ownership Loss + Fee Tier Freeze → Protocol Lockout
- **Findings:** L-02 + M-02 + M-01
- **Theory:** Ownership lost via one-step transfer, fees/configurations frozen forever
- **Broken invariants:** INV-12, INV-09
- **Priority:** LOW — operational risk, not exploitable

### Chain 4: LM Pool DoS + NPM Collect Griefing → LP Fund Lock
- **Findings:** H-02 (DoS aspect) + L-04
- **Theory:** LM pool reverts swaps, NPM collect fails due to burn(0) revert
- **Broken invariants:** none (temporary griefing)
- **Priority:** LOW — LPs have workaround (decreaseLiquidity then collect)

## Questions for the protocol team
- 
