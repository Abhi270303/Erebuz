# Audit agent swarm

One subagent per audit skill / lens. They run **in parallel** over the same hot-contract
set, each in its own isolated context, and each emits leads to `audits/PROJECT/agents/`.
A final `agent-converge` fans them back in: dedupe, corroborate, normalize → `issues/`.

This is the fan-out / fan-in layer of Phase 5. Full procedure:
`references/10-agent-swarm-and-convergence.md`. Output contract every hunter obeys:
`assets/agent-lead-schema.md`.

```
                         ┌──────────────┐
                         │  agent-xray  │  pre-flight: threat model, entry points,
                         │  (run 1st)   │  invariants → x-ray.md (orients the swarm)
                         └──────┬───────┘
                                │  hot-contract set + threat model
        ┌───────────────┬───────┴───────┬───────────────┬──────────────┐
        ▼               ▼               ▼               ▼              ▼
 ┌────────────┐ ┌──────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────┐
 │agent-pashov│ │agent-trailof…│ │agent-forefy│ │agent-solod…│ │agent-invariant│
 │ solidity-  │ │ Slither +    │ │ multi-lang │ │ historical │ │ first-princ. │
 │ auditor    │ │ entry-point  │ │ audit      │ │ bug-class  │ │ (always on)  │
 └─────┬──────┘ └──────┬───────┘ └─────┬──────┘ └─────┬──────┘ └──────┬───────┘
       │  each writes agents/AGENT-report.md + agents/AGENT.leads.jsonl │
       └───────────────┴───────┬───────┴───────────────┴──────────────┘
                                ▼
                        ┌────────────────┐   scripts/merge_agent_reports.py
                        │ agent-converge │   → coverage matrix + dedup worktable
                        │  (run last)    │   → canonical issues/  + agents/convergence.md
                        └────────────────┘   → chains feed Phase 8, POCs Phase 9
```

## The agents

| file | id | wraps | always available? |
|------|----|-------|-------------------|
| `agent-xray.md`        | `xray`        | pashov `x-ray` (pre-audit threat model)         | needs pashov skill |
| `agent-pashov.md`      | `pashov`      | pashov `solidity-auditor` (internally ~8 agents)| needs pashov skill |
| `agent-trailofbits.md` | `trailofbits` | ToB skills + Slither + entry-point/property     | best with Slither |
| `agent-forefy.md`      | `forefy`      | Forefy `smart-contract-security-audit`          | needs Forefy skill |
| `agent-solodit.md`     | `solodit`     | Solodit MCP (historical bug-class matching)     | needs Solodit MCP |
| `agent-invariant.md`   | `invariant`   | manual first-principles vs `invariants.md`      | **yes, no deps**  |
| `agent-converge.md`    | `converge`    | merge / dedupe / corroborate / normalize        | yes               |

`agent-invariant` exists so the swarm still produces real coverage when the external
skills/MCPs are not installed — the pipeline degrades gracefully (SKILL.md principle:
manual review against `invariants.md` is always the backbone).

## Off-chain swarm (optional — web & code, not contracts)

A DeFi protocol is more than its contracts. This second, optional swarm hunts the
protocol's **web surface and off-chain code** (dapp frontend, APIs, RPC/subgraph, infra,
the repos behind them) and feeds the **same** `agent-converge`, so web bugs land in the
same ranked `issues/` set. Each agent represents one of the top-5 open-source web/pentest
agents from the reference list, with an **in-harness skill as its practical fallback** —
`cso` is the backbone here, the way `agent-invariant` is for contracts.

| file | id | represents | in-harness fallback | always available? |
|------|----|-----------|---------------------|-------------------|
| `agent-pentestswarm.md` | `pentestswarm` | PentesSwarm AI | Exa OSINT + ProjectDiscovery chain + `browse` | yes (recon, run 1st) |
| `agent-cai.md`          | `cai`          | CAI            | `cso` (comprehensive)        | **yes (`cso`)** |
| `agent-hexstrike.md`    | `hexstrike`    | HexStrike AI   | toolkit via Bash + `cso`     | best with toolkit |
| `agent-pentagi.md`      | `pentagi`      | PentAGI        | `cso` + `investigate`        | **yes (`cso`)** |
| `agent-pentestgpt.md`   | `pentestgpt`   | PentestGPT     | OWASP WSTG + `cso` checklists | **yes (`cso`)** |

**Authorization gate:** this swarm is passive by default (public artifacts only); active
scanning runs **only** against owned / named-bug-bounty-scope / lab targets. Full
orchestration, gate, and setup: `references/12-offchain-web-swarm.md`. Run order mirrors
the contract swarm — `agent-pentestswarm` first (writes `agents/offchain-surface.md`, the
off-chain hot set), the other four in parallel, then the shared `agent-converge`.

## Install (Claude Code subagents)

These are Claude Code subagent definitions. Make them available in the project you are
auditing by copying them into `.claude/agents/`:

```bash
bash scripts/dispatch_agents.sh --install        # copies agents/*.md → .claude/agents/
# or manually:
mkdir -p .claude/agents && cp agents/agent-*.md .claude/agents/
```

The external skills/MCPs each agent wraps are installed separately — see
`references/06-external-skills.md`. An agent whose skill is missing falls back to manual
methodology and says so in its report; it does not fabricate.

## Dispatch (fan-out)

From the main audit context, after Phase 0–4 are done and `invariants.md` exists:

1. Run `agent-xray` **first**, alone. Read its `x-ray.md`; it sets the hot-contract list.
2. Dispatch the five hunters **in parallel** (one Task / subagent call each), all pointed
   at the same 2–5 hot contracts + the same `invariants.md` + `x-ray.md`. Each runs in its
   own context and returns only a short summary; its full output lands in
   `agents/AGENT-report.md` + `agents/AGENT.leads.jsonl`.
3. Run `agent-converge` **last**, once all hunters have written their files.

`scripts/dispatch_agents.sh --plan PROJECT` prints the exact dispatch checklist and the
list of expected output files so you can confirm fan-out completed before converging.

On **claude.ai** (no parallel subagents): run the lenses sequentially in one context,
writing each agent's leads file as you go, then do the converge step inline. Same output,
slower, less context isolation.

## Conventions all agents share

- **Leads, not findings.** Hunters never write to `issues/`. Only `agent-converge` (with
  the human) promotes a corroborated, normalized lead into an `issues/` finding.
- **Same scope.** Every hunter audits the identical hot-contract set so corroboration is
  meaningful (agent A and B flagging `Vault.withdraw` only counts if both looked at it).
- **Own lane, but report strays.** Each agent has a primary lens but logs anything it
  trips over — cross-lane catches are valuable. It tags them honestly.
- **Evidence or it didn't happen.** Every lead cites code the agent actually read. No
  invented addresses, lines, snippets, or Solodit ids. Empty output beats fabricated
  output.
- **Union, not vote.** Convergence keeps single-agent leads. A bug only one lens caught is
  often the real one — corroboration raises confidence, it never gates inclusion.
