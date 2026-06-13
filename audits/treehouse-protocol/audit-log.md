# Audit log — treehouse-protocol (top-level auditor notebook)

## Coverage
- [ ] <contract / function reviewed?>

## Hunches (not yet findings)
- 

## Chaining ideas (Phase 8)

### Chain 1 (HIGH — top priority): NAV Inflation → Unbacked Mint → Vault Drain
**Findings:** H-02 + M-05  
**Path:** Force ETH to Vault → inflate NAV → executor calls TreehouseAccounting.mark() directly (bypasses 2.5% deviation guard) → unlimited IAU minted → tETH share price inflates → attacker redeems for real wstETH from Vault  
**POC needed:** Selfdestruct contract → mark(MINT, large, 0) → verify wstETH drained from Vault  
**Status:** 🔴 Not yet proven (Phase 9)

### Chain 2 (HIGH): Strategy Delegatecall → Vault Drain
**Findings:** H-03  
**Path:** Executor calls Strategy.callExecute(maliciousAction) → delegatecall runs malicious code → calls Vault.withdraw() as active strategy → wstETH drained  
**POC needed:** Deploy malicious action, call via executor, verify Vault drain  
**Status:** 🔴 Not yet proven (Phase 9)

### Chain 3 (MEDIUM): Fast Cooldown + Large Deviation → Rapid Inflation
**Findings:** H-02 (deviation 2.5%) + PnlAccounting.setCooldownSeconds(min=60s)  
**Path:** Reduce cooldown to 60s → 2.5% per minute → unlimited daily inflation  
**POC needed:** setCooldownSeconds(60), rapid doAccounting calls  
**Status:** 🟡 Requires owner cooperation, not unprivileged

### Chain 4 (MEDIUM): Helper Deviation Bypass + mark() → Strategy PnL
**Findings:** M-04 + M-05  
**Path:** setDeviation(65535) on PnlAccountingHelper (bypasses cap due to wrong-variable bug) → helper calls mark() with massive amounts  
**POC needed:** Verify setDeviation(65535) succeeds, then trace through to mark()  
**Status:** 🟡 Requires owner cooperation

### Chain 5 (LOW): Timelock Backdoor + Minter → Supply Inflation
**Findings:** M-09 + M-08  
**Path:** Owner sets timelock→attacker → attacker calls addMinter → mints unlimited IAU to TAsset  
**POC needed:** Two-step backdoor setup, verify unlimited mint  
**Status:** 🟡 Requires owner cooperation

## Questions for the protocol team
1. What is the current setup for the executor role? Is it an EOA, a multisig, or an automated keeper bot?
2. What is the owner key setup? Multisig? Threshold? Signers?
3. Is the deviation 2.5% (actual) or 0.025% (documented) the intended value? The PRECISION=1e4 vs comment "1e6 base" suggests a 100x error.
4. Are both TreehouseRedemption V1 and V2 deployed? Which is the canonical redemption contract?
5. Is the blacklister address set in TAsset? Who holds it?
6. Is there a plan to deploy a TimelockController? The dependency is imported but unused.
7. What action contracts are currently deployed? Are any upgradeable?
