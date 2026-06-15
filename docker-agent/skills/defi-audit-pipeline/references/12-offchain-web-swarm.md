# Phase 5 (off-chain) — Web & code security swarm

The main Phase 5 swarm (`references/10`) audits the **contracts** in `source/`. A DeFi
protocol is more than its contracts: there is a dapp frontend, APIs, RPC/subgraph
endpoints, infra, and the repos behind them — and that off-chain surface is where wallet
drainers, leaked keys, IDOR/BOLA, and supply-chain bugs live. This **optional, parallel
swarm** hunts that surface, reusing the same lead → converge machinery so its results land
in the *same* ranked `issues/` set as the contract findings.

It wraps the five open-source web/pentest agents from the reference list — but in this
harness the **practical engine is the in-harness `cso`, `qa`, and `browse` skills** plus
the standard toolkit (ProjectDiscovery chain, trufflehog, etc.). Each agent names the
open-source project it represents *and* the in-harness skill it falls back to; an agent
whose external project is not set up runs the fallback and says so. It never fabricates.

## Authorization gate (non-negotiable — read first)

The contract swarm is safe because it reads public on-chain state and runs exploits only
against local forks. Web testing is different: scanning a live site is **active** and can
be illegal without permission. So this swarm is bounded:

- **Default = passive.** Analyze only **public artifacts**: public JS bundles + source
  maps, public repos (deps / CI/CD / secrets), HTTP response headers, TLS, DNS / subdomain
  OSINT. This is the web analogue of reading deployed bytecode — low-touch, no exploitation.
- **Active scanning is gated.** Fuzzing, injection (sqlmap/dalfox), authenticated probing,
  nuclei active templates, and any autonomous exploit loop run **only** when the target is:
  (a) **owned** by the user, (b) inside a **named bug-bounty program's scope** the user
  states, or (c) a **local lab / fork**. 
- If that authorization is not established, every agent **stays passive and says so** in
  its report. Out-of-scope hosts are never touched. Findings exist to be disclosed to the
  protocol, not exploited — same whitehat rule as the rest of this skill.

When in doubt, ask the user to confirm the in-scope target list before any active step.

## The agents (one lens each)

| agent | represents | in-harness fallback | primary lens |
|-------|-----------|---------------------|--------------|
| `agent-pentestswarm` | PentesSwarm AI | Exa OSINT + ProjectDiscovery chain + `browse` | recon / breadth → off-chain hot set (run first) |
| `agent-cai`          | CAI            | **`cso`** (comprehensive)                      | generalist attacker-story hunting |
| `agent-hexstrike`    | HexStrike AI   | toolkit via Bash + `cso` dep/secret scan       | tool execution / DAST |
| `agent-pentagi`      | PentAGI        | **`cso`** + **`investigate`**                  | deep autonomous chain on one target (sandbox) |
| `agent-pentestgpt`   | PentestGPT     | OWASP WSTG + `cso` checklists                  | methodology coverage + adversarial verify |

These complement, they do not replace, the contract swarm. Run the contract swarm
(`references/10`) for `source/`; run this one for the web/code surface. Both feed the same
`agent-converge`.

## Dispatch order

Preconditions: Phase 2 research done (`research/website.md`, `research/repos.md`,
`recon.md` list the in-scope domains/dapp/API/repos), agents installed
(`bash scripts/dispatch_agents.sh --install`), and the **authorization gate cleared** for
anything beyond passive analysis.

1. **`agent-pentestswarm` first, alone.** It maps the surface and writes
   `agents/offchain-surface.md` with the ranked **off-chain hot set** — the shared scope
   for the rest, exactly like `agent-xray` does for contracts.
2. **`agent-cai`, `agent-hexstrike`, `agent-pentagi`, `agent-pentestgpt` in parallel**, all
   scoped to that off-chain hot set. Each writes `agents/<id>-report.md` +
   `agents/<id>.leads.jsonl`. `agent-pentestgpt` also verifies the others' leads as they
   land.
3. **`agent-converge` last** — the *same* convergence agent as the contract swarm. It globs
   **all** `agents/*.leads.jsonl` (contract + off-chain), clusters by
   `bug_class|contract|function`, unions (never votes), and normalizes survivors into
   `issues/SEVERITY-NN-slug.md`. Off-chain leads cluster on their own keys (web bug-class,
   host/repo as `contract`) and become H/M/L/I findings alongside the contract ones. In the
   coverage matrix, add an **off-chain section** (rows = these agents, columns = the
   off-chain hot set).

On **claude.ai** (no parallel subagents): run the lenses sequentially in one context, write
each leads file as you go, then converge inline — same as the contract swarm.

## Lead contract

Identical to the contract swarm: `assets/agent-lead-schema.md`. Use the **Web / off-chain
bug classes** vocabulary and the **off-chain field mapping** in that file (`contract` =
host/service/repo, `function` = endpoint/route/file, `location` = full URL/param or
file:line you actually retrieved). Evidence rules are the same and non-negotiable: a URL
you did not fetch, a header you did not read, or a leaked key you did not see does not
exist.

## Setup of the external projects (optional)

All five are heavyweight standalone systems with their own LLM/Docker/API-key setup; this
skill does not ship or install them. If the user wants the real thing rather than the
in-harness fallback, install per each repo's README:

- CAI — github.com/aliasrobotics/cai (multi-agent; supports local LLMs via Ollama)
- HexStrike AI — github.com/0x4m4/hexstrike-ai (MCP server; connect it, bring your own LLM)
- PentAGI — github.com/vxcontrol/pentagi (autonomous, Docker sandbox)
- PentestGPT — github.com/GreyDGL/PentestGPT (LLM-guided assistant)
- PentesSwarm AI — github.com/Armur-Ai/Pentest-Swarm-AI (Go + Claude API, AGPL-3.0)

If none are set up, the swarm still runs on the in-harness fallbacks above — `cso` is the
backbone, the way `agent-invariant` is the backbone of the contract swarm.
