# erebuz — DeFi Smart Contract Audit Pipeline

**erebuz** is an autonomous, multi-agent smart contract security audit pipeline. It orchestrates a swarm of specialized AI agents that work in parallel to find vulnerabilities in deployed DeFi protocols, then converges their findings into validated, severity-ranked security reports with executable proof-of-concept tests.

## Core Philosophy

- **Audit the deployed bytecode, not the marketing** — the repo may not match what's live; always fetch from the chain.
- **Invariants first** — every bug is a way to violate an invariant; define them before hunting.
- **Evidence only** — every claim ties to a specific file:line, storage slot, transaction, or real historical finding.
- **Capture everything, immediately** — suspicious but unproven patterns go in as informational; don't gate on certainty.
- **Chain relentlessly** — the high-severity finding is usually two or three low-severity issues combined.
- **Tools produce leads, humans confirm** — all agent output is tentative; only the convergence step promotes to findings after re-reading the cited code.
- **Union, not vote** — a single agent's lead is kept; corroboration raises confidence but never gates inclusion.
- **Graceful degradation** — the invariant agent runs with zero external dependencies, so the swarm always produces coverage even when all external skills are missing.

## Pipeline Overview (10 Phases)

### Phase 0: Workspace Setup
Scaffold the audit directory structure: `audits/PROJECT/recon.md`, `research/`, `source/`, `invariants.md`, `issues/`, `pocs/`, `agents/`.

### Phase 1: Target Discovery
Scan DeFiLlama PRs (dimension-adapters repo) for new protocol additions. Extract contract addresses, chains, and integration architecture from the adapter code.

### Phase 2: Project Research
Gather whitepaper, documentation, GitHub repos, prior audit reports, social channels, and TVL/fee data. Detect upgradeable proxies, admin keys, and timelocks.

### Phase 3: Source Acquisition
Fetch verified deployed source via block explorer APIs. Resolve proxy implementations (EIP-1967, UUPS, beacon, diamond). Decompile unverified bytecode with Dedaub or heimdall. Normalize into `source/ADDR-Name/`.

### Phase 4: Invariants & Diff
Diff audited commit vs deployed code. Classify deltas:
- **Behavioral** (= HIGH priority — logic changed after audit)
- **Configurational** (= medium — parameters changed)
- **Cosmetic** (= low — comments, events, natspec)

Reconstruct all invariants with status: `enforced`, `assumed`, or `MISSING`.

### Phase 5: Bug Hunting Swarm (Parallel)
Strict dispatch order: **x-ray first → 5 hunters in parallel → converge last**.

```
┌──────────────┐
│  agent-xray  │  Pre-flight threat model
└──────┬───────┘
       │  Outputs: agents/x-ray.md (hot contracts, invariants, threat model)
       ▼
  ┌────┴────┐
  │ 5 Hunters │  Run IN PARALLEL — same hot contracts
  └────┬────┘
       │  Each writes: agents/<id>.leads.jsonl
       ▼
┌──────────────┐
│ agent-converge │  Dedup, corroborate, normalize
└──────────────┘
  Outputs: issues/SEVERITY-NN-slug.md + agents/convergence.md
```

#### The Agents

| Agent | Lens | Dependencies | Output |
|-------|------|-------------|--------|
| **x-ray** | Pre-flight threat model, entry-point map, ranked hot-contract list | pashov x-ray skill | `x-ray.md` |
| **pashov** | Broad Solidity: attack vectors, math, access control, economic, execution traces, invariants, periphery, first-principles (~8 sub-agents) | pashov solidity-auditor skill | `.leads.jsonl` |
| **trailofbits** | Slither detectors, entry-point enumeration, spec-to-code compliance, anti-pattern catalog | Slither + ToB skills | `.leads.jsonl` |
| **forefy** | Multi-language (Solidity, Vyper, Rust/Anchor, Move/Sui, TON FunC/Tact); also scaffolds Foundry POC drafts | Forefy skill | `.leads.jsonl` |
| **solodit** | Historical vulnerability matching — maps suspicious patterns against 10k+ past findings (Cyfrin, Sherlock, C4, ToB, OZ) | Solodit MCP | `.leads.jsonl` |
| **invariant** | First-principles — tries to break each invariant in `invariants.md` against deployed source. Reentrancy, arithmetic, accounting, access/state machine, external assumptions. Always runs (zero deps). | None | `.leads.jsonl` |
| **converge** | Fan-in: merges all `.leads.jsonl`, clusters by `bug_class\|contract\|function`, re-reads cited evidence, drops fabricated locations, assigns severity, writes findings. *Only agent that can write to issues/*. | None | `issues/*.md` + `convergence.md` |

### Phase 6: Solodit Research
Search Solodit (solodit.cyfrin.io) by protocol type for historical bugs. Map root causes onto current code. Attach Solodit references to findings.

### Phase 7: Document Findings
One file per finding in `issues/SEVERITY-NN-slug.md` following the canonical template:

```
Severity: H/M/L/I
Status: unconfirmed | confirmed
Invariant broken: INV-XX
Contract: ContractName (function)
Deployed address: 0x... (proxy) -> 0x... (impl)
Location: path/Contract.sol:L123-L145

## Description
## Root cause
## Impact
## Attack path / preconditions
## Proof of concept
## Recommendation (as diff)
## References
```

### Phase 8: Integration Mapping & Chaining
Map all integration dependencies (oracles, bridges, external vaults, swappers). Chain low-severity issues together into high-severity exploit paths. Update findings with combined attack paths.

### Phase 9: Foundry Fork-Test POCs
For each finding, write a Foundry fork test that proves the vulnerability against real on-chain state. Flip status to `confirmed` if the POC passes.

### Phase 10: Iterate & Report
Finalize severities using the rubric, assemble the report from `issues/` and `pocs/`.

## Lead Schema (JSONL)

Every hunter emits leads in this format:

```json
{
  "agent": "pashov",
  "lead_id": "pashov-003",
  "title": "Re-entrant withdraw double-counts shares in Vault",
  "bug_class": "reentrancy",
  "contract": "Vault",
  "function": "withdraw(uint256)",
  "location": "src/Vault.sol:L210-L240",
  "severity_guess": "H",
  "confidence": "medium",
  "invariant": "INV-04",
  "summary": "withdraw() sends ETH before zeroing the share balance...",
  "evidence": "L228 calls msg.sender.call... L235 sets shares=0 AFTER call",
  "precondition": "attacker holds shares and controls a contract",
  "solodit_ref": "",
  "needs": "fork POC: deposit, re-enter in receive(), assert drained > deposited"
}
```

## Severity Rubric

| | Impact High | Impact Medium | Impact Low |
|---|---|---|---|
| **Likelihood High** | High | Medium | Low |
| **Likelihood Medium** | High | Medium | Low |
| **Likelihood Low** | Medium | Low | Low/Info |

## Invariant Families

Each protocol has documented invariants covering:
- **Solvency / conservation** — total assets = sum of user claims
- **Share / asset accounting** — share price monotonicity, mint/burn math
- **Access control** — only authorized roles can call privileged functions
- **Oracle / pricing** — manipulation resistance, freshness, deviation checks
- **Liquidation / health** — positions can always be liquidated when below threshold
- **Reentrancy / CEI** — no state changes after external calls
- **Upgrade safety** — storage layout compatibility, initialization protection
- **Pausing / emergency** — invariant holds during paused states

Invariant format:
```
INV-XX Statement of what must always/never be true
  enforced-by: file:line (or "none found")
  breaks-if:   condition that violates it
  status:      enforced | assumed | MISSING
```

## Key Workflow Files

| File | Purpose |
|------|---------|
| `audits/PROJECT/recon.md` | Target metadata, addresses, chains, adapters |
| `audits/PROJECT/research/` | Website, docs, audits, repos (from Exa MCP) |
| `audits/PROJECT/source/ADDR-Name/` | Deployed source fetched from chain |
| `audits/PROJECT/invariants.md` | All protocol invariants with enforcement status |
| `audits/PROJECT/deployed-vs-audited.md` | Diff of audited vs deployed code |
| `audits/PROJECT/agents/x-ray.md` | Threat model + hot-contract list |
| `audits/PROJECT/agents/<agent>.leads.jsonl` | Machine-readable leads from each hunter |
| `audits/PROJECT/agents/convergence.md` | Coverage matrix + dedup decisions |
| `audits/PROJECT/issues/SEVERITY-NN-slug.md` | Canonical findings |
| `audits/PROJECT/pocs/*.t.sol` | Fork-test proof-of-concept contracts |

## Dependencies

- **Foundry** (forge, cast) — compilation, fork testing, on-chain queries, source fetching
- **Solodit MCP** (solodit.cyfrin.io) — historical vulnerability database
- **Exa MCP** — web research for protocol discovery and documentation
- **DeFiLlama API** — TVL, fees, token prices, protocol metadata
- **Chainlist API** — RPC endpoint discovery
- **pashov/auditor skill** — ~8 sub-agents for broad Solidity bug hunting
- **Forefy skill** — multi-language audit framework
- **Slither** — static analysis
- **OpenCode** — agent orchestration framework

All agents and skills are idempotent and designed for parallel execution within a stateless, containerized environment.
