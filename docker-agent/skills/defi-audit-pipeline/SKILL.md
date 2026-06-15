---
name: defi-audit-pipeline
description: End-to-end smart contract security audit pipeline for DeFi protocols. Use whenever the user wants to audit a smart contract or DeFi protocol, do a security review, hunt for vulnerabilities in Solidity or on-chain code, investigate DefiLlama listings or DefiLlama-Adapters pull requests, fetch deployed contract source from block explorers, handle proxies, decompile unverified bytecode, compare audited vs deployed code, check protocol invariants, research historical bugs on Solodit, map integration dependencies, chain findings into exploits, document findings by severity, or write Foundry fork-test proof-of-concepts for responsible disclosure. The bug hunt runs as a parallel multi-agent swarm — one subagent per audit lens (pashov, Trail of Bits, Forefy, Solodit, plus a dependency-free invariant agent) hunts independently, then a convergence agent dedupes and merges their leads. Orchestrates the Exa and Solodit MCPs and the pashov, Trail of Bits, and Forefy auditing skills into one whitehat workflow.
license: For defensive security and responsible disclosure only.
metadata:
  version: 1.2.0
---

# DeFi Audit Pipeline

A repeatable, end-to-end workflow for auditing DeFi smart contracts as a whitehat:
discover a target, acquire exactly the code that is live on-chain, reconstruct its
intended invariants, hunt for bugs with the help of specialist audit skills and a
historical-vulnerability database, chain small issues into real exploits, and prove
them with Foundry fork tests.

## Scope and intent (read first)

This skill is for **defensive security research and responsible disclosure**. Every
proof-of-concept exists to demonstrate a vulnerability to the protocol team so it can
be fixed. Operate accordingly:

- Run exploits **only** against local mainnet forks, testnets, or contracts you are
  explicitly authorized to test. Never send an exploit transaction to a live contract
  holding third-party funds.
- The deliverable is a written report plus reproducible POCs, not stolen funds.
- If a request shifts from "find and prove the bug so it can be fixed" to "extract
  value from a contract I do not own," stop and decline.

## What this skill orchestrates

External capabilities this pipeline drives. None ship inside this skill; each is set
up once by the user. See `references/06-external-skills.md` for exact install commands,
tool names, API keys, and how to invoke each.

- **Exa web search MCP** — discovery and research (project sites, docs, prior audits,
  GitHub source, code context).
- **DefiLlama REST API** (`https://api.llama.fi`, free, no auth) — protocol metadata,
  slugs, TVL, chains, audit links. Query it directly with `curl`; do **not** use the
  DefiLlama MCP. Endpoint reference: `references/11-defillama-api.md`.
- **Solodit MCP** (`solodit.cyfrin.io`) — search tens of thousands of aggregated audit
  findings to find historical bugs comparable to the code under review.
- **pashov skills** — `solidity-auditor` (parallel multi-agent bug hunt) and `x-ray`
  (pre-audit codebase scan / threat model).
- **Trail of Bits skills** and **Forefy skill** — additional methodology and detectors.
- **Foundry** (`forge`, `cast`, `anvil`) — source fetching, storage reads, and fork POCs.

The bug-hunting phase wraps each of these lenses in a dedicated **subagent** and runs
them as a parallel swarm that converges into one ranked finding set — see Phase 5 below
and `references/10-agent-swarm-and-convergence.md`. The subagents themselves ship in this
skill's `agents/` folder; the external skills/MCPs they drive are installed by the user.

If a capability is missing, say so and continue with what is available rather than
fabricating results. Never invent contract addresses, source code, findings, or
Solodit hits — if you did not retrieve it, you do not have it.

## The pipeline

Each phase has a dedicated reference file. Read the reference for a phase **before**
doing that phase; do not work from this summary alone. Phases are ordered but
iterative — return to earlier phases as you learn more (especially Phase 8 -> 4).

### Phase 0 — Set up the workspace
Pick or create the target's folder under `audits/PROJECT/` using the standard layout
(see "Project folder layout" below). Run `scripts/scaffold_project.py PROJECT` to
create it. Everything you learn is written to `.md` files in this folder as you go,
not held only in your head.

### Phase 1 — Target discovery (DefiLlama PR recon)
Find a target by scanning recent pull requests to `DefiLlama/DefiLlama-Adapters` (and
the dimension-adapters / yield-server repos). New protocols arrive as adapter PRs whose
`projects/NAME/index.js` lists contract addresses, token lists, and chains. Pull the
addresses + chain from the adapter; that seeds the whole audit. Resolve slugs and
protocol metadata via the free DefiLlama REST API (`https://api.llama.fi`), not the MCP.
-> `references/01-defillama-pr-recon.md`, `references/11-defillama-api.md`

### Phase 2 — Project research with Exa
For the target, use the Exa MCP to gather the website, documentation, prior audit
reports, and GitHub repositories (Solidity/Rust source). Distill each into a `.md` file
under `research/`. Capture claimed behavior and security assumptions — you will test
them later.
-> `references/02-exa-research-and-project-folders.md`

### Phase 3 — Source acquisition (the code that is actually deployed)
For each contract address, fetch the **verified deployed source** from the block
explorer (or Sourcify) with `cast`. Detect and resolve proxy patterns (EIP-1967 /
UUPS / transparent / beacon / minimal-proxy) to find the real implementation. When
source is unverified, decompile the bytecode. The audit target is what is on-chain,
not just what is in the repo.
-> `references/03-source-acquisition.md`

### Phase 4 — Invariants and audited-vs-deployed diff
Diff the audited code (from prior reports / the repo at the audited commit) against the
deployed source from Phase 3 — unaudited changes are prime hunting ground. Reconstruct
the protocol's invariants (what must always/never be true). Write them down, **including
invariants that are missing or unenforced**.
-> `references/04-invariants-and-diff.md`

### Phase 5 — Bug hunting as a parallel agent swarm
Hunt with one **subagent per audit lens**, run in parallel over the same hot contracts,
then converge their leads. Install the subagents with
`bash scripts/dispatch_agents.sh --install`. Preconditions: Phases 0–4 done and
`invariants.md` written.

- **5a — x-ray (run first, alone).** `agent-xray` builds the threat model and a ranked
  list of the 2–5 hottest contracts. That list is the shared scope for every hunter.
- **5b — swarm (run in parallel).** Dispatch `agent-pashov`, `agent-trailofbits`,
  `agent-forefy`, `agent-solodit`, and `agent-invariant` at once, all on the same hot set
  + `invariants.md`. Each hunts its lens in an isolated context and writes
  `agents/<id>-report.md` + `agents/<id>.leads.jsonl`. They emit **leads, not findings**,
  and never fabricate; `agent-invariant` needs no external skill so the swarm always runs.
- **5c — converge (run last).** `agent-converge` merges all leads
  (`python scripts/merge_agent_reports.py PROJECT`), dedupes/corroborates by
  `bug_class|contract|function` (**union, not vote**), normalizes survivors into canonical
  `issues/` findings, and writes a coverage matrix to `agents/convergence.md`.

Treat all swarm output as leads to verify, not final findings. On claude.ai (no parallel
subagents) run the lenses sequentially in one context, then converge inline.
-> `references/10-agent-swarm-and-convergence.md` (orchestration),
   `references/06-external-skills.md` (per-lens setup)

- **5d — off-chain swarm (optional).** A protocol is more than its contracts. When the
  target has a real web surface (dapp, API, RPC/subgraph, infra, the repos behind them),
  run the optional **off-chain swarm** alongside the contract one: `agent-pentestswarm`
  (recon -> off-chain hot set) first, then `agent-cai`, `agent-hexstrike`, `agent-pentagi`,
  `agent-pentestgpt` in parallel, converged by the **same** `agent-converge` so web bugs
  land in the same ranked `issues/`. These wrap the top open-source web/pentest agents
  (CAI, HexStrike, PentAGI, PentestGPT, PentesSwarm) with the in-harness `cso`/`qa`/`browse`
  skills as the practical fallback. **Authorization gate:** passive (public artifacts) by
  default; active scanning only against owned / named-bug-bounty-scope / lab targets.
  -> `references/12-offchain-web-swarm.md`

### Phase 6 — Contextual research on Solodit
For each suspicious pattern, search Solodit for comparable historical findings, then map
the historical bug onto the current code: does the same root cause exist here? Use
Solodit categories/tags to pull the known bug classes for this protocol type.
-> `references/07-solodit-research.md`

### Phase 7 — Document findings
Record every "weird" observation immediately as a one-finding-per-file `.md` in the
project's `issues/` folder, named by severity (`H-`, `M-`, `L-`, `I-`). Use the finding
template and severity rubric. Low/informational notes are kept — many chain into highs.
-> `references/05-finding-documentation.md`

### Phase 8 — Integration mapping and finding chaining
After each Solidity file, map its dependencies: file-to-file calls and external
integrations (oracles, tokens, other protocols). Then put on the auditor's top-level
hat and **chain** findings: combine small issues to break an invariant, bypass
access control, or defeat a modifier. This is where impact is made.
-> `references/08-integration-and-chaining.md`

### Phase 9 — Prove it: Foundry fork-test POCs
For each credible exploit chain, write a Foundry test that forks real mainnet state and
demonstrates the violation (drained balance, broken invariant, bypassed guard). A
finding without a passing POC is a hypothesis.
-> `references/09-foundry-poc.md`

### Phase 10 — Iterate and report
Iterate across every contract/branch, fold new knowledge back into earlier phases,
finalize severities, and assemble the report from the `issues/` files plus POCs.

## Operating principles (auditor mindset)

1. **Audit the deployed bytecode, not the marketing.** Repo != deployed. Audited commit
   != deployed commit. Always reconcile.
2. **Invariants first.** A bug is a way to violate an invariant. If you have not written
   the invariants down, you do not yet know what a bug is here.
3. **Evidence only.** Every claim ties to a specific file+line, storage slot, tx, or
   Solodit finding you actually retrieved. No fabricated addresses, code, or citations.
4. **Capture everything, immediately.** Weird-but-unproven goes in `issues/` as
   informational now; you will not remember it later.
5. **Chain relentlessly.** The high-impact finding is usually two or three "lows" wearing
   a trenchcoat. Always ask: what does this let me combine?
6. **Tools are leads, humans confirm.** pashov/ToB/Forefy/Solodit surface candidates;
   you confirm each by reading the code and writing a POC.
7. **Re-isolate context with subagents.** In Claude Code, run heavy Exa/Solodit research
   inside Task sub-agents that return only distilled findings, and run the Phase 5 bug
   hunt as a parallel swarm of one subagent per audit lens (each isolated, each emitting
   leads), converged by a final agent. This protects the main context and lets each lens
   hunt independently. (Not available on claude.ai — there, research and hunt inline,
   sequentially, and summarize tightly.)

## Project folder layout

`scripts/scaffold_project.py PROJECT` creates this under `audits/PROJECT/`:

```
audits/PROJECT/
├── README.md              # one-paragraph what-it-is + status + key links
├── recon.md               # DefiLlama PR, addresses, chains, deploy blocks
├── research/
│   ├── website.md
│   ├── docs.md            # claimed behavior + stated security assumptions
│   ├── audits.md          # prior audit reports found (firm, scope, commit)
│   └── repos.md           # GitHub repos + audited commit hashes
├── source/
│   ├── ADDR-Name/         # verified/decompiled source per contract
│   └── deployed-vs-audited.md
├── invariants.md          # invariants, INCLUDING missing/unenforced ones
├── integration-map.md     # file-to-file + external dependency graph
├── agents/                # Phase 5 swarm: per-lens reports + *.leads.jsonl + convergence.md
├── issues/                # one finding per file: H-01-slug.md, M-..., L-..., I-...
├── pocs/                  # Foundry fork tests proving the findings
└── audit-log.md           # running top-level auditor notes + chaining ideas
```

## Helper assets and scripts

- `scripts/scaffold_project.py` — create the folder layout above for a project.
- `scripts/fetch_source.sh` — fetch verified source via `cast`, read EIP-1967 proxy
  slots, and resolve the implementation address for a given on-chain contract.
- `scripts/dispatch_agents.sh` — install the Phase 5 swarm subagents (`--install`) or
  print the fan-out/fan-in dispatch plan for a project (`--plan PROJECT`).
- `scripts/merge_agent_reports.py` — merge every `agents/*.leads.jsonl`, cluster by
  `bug_class|contract|function`, and emit the convergence worktable + coverage matrix.
- `agents/` — one subagent per audit lens plus the convergence agent; see
  `agents/README.md`. Installed into `.claude/agents/` by `dispatch_agents.sh --install`.
- `assets/finding-template.md` — copy into `issues/` for each finding.
- `assets/severity-rubric.md` — impact x likelihood guidance for H/M/L/I.
- `assets/agent-lead-schema.md` — the JSONL lead contract every hunter emits.
- `assets/convergence-worktable-template.md` — scaffold for `agents/convergence.md`.
- `assets/project-structure.md` — annotated explanation of the folder layout.

## Reference index

| Phase | File |
|-------|------|
| 1 | `references/01-defillama-pr-recon.md` |
| 2 | `references/02-exa-research-and-project-folders.md` |
| 3 | `references/03-source-acquisition.md` |
| 4 | `references/04-invariants-and-diff.md` |
| 7 | `references/05-finding-documentation.md` |
| 5 (setup) | `references/06-external-skills.md` |
| 6 | `references/07-solodit-research.md` |
| 8 | `references/08-integration-and-chaining.md` |
| 9 | `references/09-foundry-poc.md` |
| 5 (swarm) | `references/10-agent-swarm-and-convergence.md` |
| 1 (API reference) | `references/11-defillama-api.md` |
| 5 (off-chain swarm) | `references/12-offchain-web-swarm.md` |
