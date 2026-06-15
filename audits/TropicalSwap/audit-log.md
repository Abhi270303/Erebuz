# Audit log — TropicalSwap

## Coverage
- [x] All contracts reviewed by at least 3 of 5 agents
- [ ] TropicalRouter coverage is thin — only 3 leads from 3 agents
- [ ] No test suite analysis performed

## POC Status
- [x] **testResidualMathFlaw** (PASS) — Proves M-04: rebalancing math creates ratio deviation
- [x] **testBalanceOfDrainsAllResiduals** (PASS) — Proves M-01: balanceOf returns raw = value leak
- [x] **testFullExploitChain** (PASS) — Proves M-04 -> H-02 -> M-01 chain: profitable residual extraction
- [x] **testFlashSwapCallbackTiming** (PASS) — Proves H-01: callback before _update()
- [ ] **testMaliciousCallee** — H-01 cross-chain reentrancy requires Mantle fork with live pairs
- [ ] **testZapSandwich** — H-02 full MEV sandwich requires Mantle fork with funded accounts

## Chaining ideas (Phase 8)

### Critical chain: Persistent residual value leak (PROVEN)
```
M-04 (rebalancing precision leaves ~7 wei residuals per zap)
  + H-02 (1/1 minima means residuals can't be cleaned)
  + M-01 (balanceOf returns raw = next user extracts all residuals)
→ PROVEN via Foundry math test: profit multiple of 7000x at 1000 ops
→ Severity: H (persistent value leak growing with TVL)
```

### Cross-contract reentrancy (PROVEN code path)
```
H-01 (flash swap callback re-enters other pairs with stale reserves)
  → Proven via code inspection: callback at L159, _update() at L169
  → Any protocol using TropicalSwap spot price as oracle can be manipulated
```

### Full sandwich amplification
```
H-02 (1/1 minima on addLiquidity)
  + M-02 (block.timestamp deadline removes timing safeguard)
  → Complete MEV sandwich on every zap transaction
```

### Fee-on-transfer cascading failures
```
M-05 (FoT tokens corrupt Pair reserve tracking)
  + M-01 (zapOut balanceOf doesn't validate swap output)
  + M-02 (no deadline means no timing defense)
```

## Findings Summary
- **High:** 2 (H-01 flash reentrancy, H-02 zap sandwich)
- **Medium:** 5 (M-01 balanceOf drain, M-02 deadline, M-03 init hash, M-04 precision, M-05 FoT)
- **Low:** 9 (L-01 through L-09)
- **Info:** 3 (I-01 through I-03)
- **Total:** 19 findings from 51 merged leads across 5 audit lenses

## Questions for the protocol team
- Is feeToSetter an EOA or multisig? If EOA, recommend multisig upgrade.
- Are any fee-on-transfer tokens expected to be paired?
- Is ZapV1 deployed at `0x7998653869Ab3c78888f954a3F62d8B7EA3bC867` on Mantle mainnet?
