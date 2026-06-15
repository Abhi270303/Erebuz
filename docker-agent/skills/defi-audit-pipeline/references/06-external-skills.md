# Phase 5 setup — External skills and MCP servers

This pipeline drives external tools that are installed/configured once by the user. None
ship inside this skill. Below are exact install commands, the tools/agents each exposes,
required API keys, and how to invoke them. If something is not installed, tell the user
the one command to fix it and continue with what is available — do not fabricate output.

Most of these are **Claude Code** capabilities (CLI, MCP, sub-agents). On **claude.ai**
the MCPs can be connected as connectors but sub-agent isolation is unavailable; adapt by
researching inline and summarizing tightly.

## How these map to the Phase 5 swarm

Phase 5 wraps each skill/MCP below in a dedicated subagent and runs them in parallel, then
converges their leads. This file is the **setup** (install commands, keys, tool names);
`references/10-agent-swarm-and-convergence.md` is the **orchestration** (dispatch order,
convergence rules). Which agent drives which capability:

| subagent | drives | if not installed |
|----------|--------|------------------|
| `agent-xray`        | pashov `x-ray`            | manual threat model from `source/` + docs |
| `agent-pashov`      | pashov `solidity-auditor` | manual multi-vector review |
| `agent-trailofbits` | ToB skills + `slither`    | manual detector-class review |
| `agent-forefy`      | Forefy skill              | manual multi-language / attacker-story review |
| `agent-solodit`     | Solodit MCP               | browser Solodit + `crawling_exa` |
| `agent-invariant`   | none (manual)             | always runs — the backbone |

Install the subagents themselves (separate from the skills below) with
`bash scripts/dispatch_agents.sh --install`. An agent whose skill is missing falls back to
the manual method in the last column and says so; it never fabricates.

---

## Exa web search MCP (discovery + research, Phase 2/6)

Hosted server: `https://mcp.exa.ai/mcp`

Install (Claude Code), enabling the tools this pipeline uses:
```bash
claude mcp add --transport http exa \
  "https://mcp.exa.ai/mcp?tools=web_search_exa,get_code_context_exa,crawling_exa,company_research_exa,linkedin_search_exa,deep_researcher_start,deep_researcher_check"
```
Auth: append `&exaApiKey=YOUR_KEY` to the URL, or set `EXA_API_KEY` in the environment.
HTTP config equivalent: `{"mcpServers":{"exa":{"type":"http","url":"https://mcp.exa.ai/mcp"}}}`.

Tools:
- `web_search_exa` — general web search.
- `get_code_context_exa` — code + docs from GitHub/StackOverflow (default-enabled).
- `crawling_exa` — extract full content from a specific known URL (docs, audit PDF, PR).
- `company_research_exa`, `linkedin_search_exa` — team/company background.
- `deep_search_exa` / `deep_researcher_start` + `deep_researcher_check` — long-running
  deep research (start returns a task id; poll with check).

Best practice: in Claude Code, isolate each Exa call in a Task sub-agent that returns
only a distilled summary + URLs/addresses, so verbose pages never enter main context.

---

## Solodit MCP (historical-vulnerability research, Phase 6)

Solodit (`https://solodit.cyfrin.io/`, by Cyfrin) aggregates tens of thousands of audit
findings from Cyfrin, Sherlock, Code4rena, Trail of Bits, OpenZeppelin, and more.

Skill/MCP: `bowtiedswan/solodit-api-skill`. Install:
```bash
npx playbooks add skill bowtiedswan/solodit-api-skill --skill solodit-api-skill
```
Auth: set `CYFRIN_API_KEY` (format `sk_...`). Get it from your Solodit profile at
`solodit.cyfrin.io` -> profile -> API Keys.

MCP tools:
- `search_vulnerabilities` — keyword + filter search over findings (the workhorse).
- `get_finding` — full text of one finding by id.
- `list_audit_firms`, `list_tags`, `list_protocol_categories`, `list_languages` —
  enumerate valid filter values before searching.
- `get_statistics`, `clear_cache`.

No MCP key? Solodit is usable in the browser (search + filters by Keyword, Source,
Impact, Author, Protocol Name, Protocol Category, Forked-From, Report Tag) and the
checklist at `solodit.cyfrin.io/checklist`. Use `crawling_exa` to pull pages if needed.
Detailed usage: `references/07-solodit-research.md`.

---

## pashov skills (bug hunting + pre-audit scan, Phase 5)

Repo: `github.com/pashov/skills` (MIT). Install the two used here:
```bash
npx skills add https://github.com/pashov/skills --skill solidity-auditor
npx skills add https://github.com/pashov/skills --skill x-ray
```

### x-ray (run FIRST, pre-audit)
Invoke: ask the agent to "run an x-ray on the codebase." Produces `x-ray.md`: codebase
overview, threat model, invariants, entry points, integrations, docs quality, test
analysis, and git/developer history. Use it to orient Phase 4/5 and to cross-check the
invariants you derived.

### solidity-auditor (run on hot contracts)
Invoke: "run solidity auditor on CONTRACT(s)." Spawns ~8 specialized parallel agents
(attack vectors, math/precision, access control, economic exploits, execution traces,
invariants, periphery, first-principles), dedupes, applies a 4-gate judging pass, and
emits a ranked report with exploit chains + fixes, named
`PROJECT-pashov-ai-audit-report-TIMESTAMP.md`.
- It skips test/mock/interface files (`interfaces/`, `lib/`, `mocks/`, `test/`, `*.t.sol`)
  — point it at real logic.
- Runs in under ~5 minutes; is **non-deterministic** — run it multiple times and union
  the results.
- Target the **2-5 hottest contracts** (most value, most privileged, most-changed since
  audit), not the whole tree.
Treat its findings as leads: confirm each by reading the code and writing a POC (Phase 9).

---

## Trail of Bits skills (Phase 5)

Trail of Bits publishes auditing/methodology skills and tooling (e.g. Slither detectors,
`weAudit`, secure-contracts guidance). Install whichever skill the user has access to via
its `npx skills add ...` command, and use it for: automated detectors (Slither),
incident/property checklists, and known anti-pattern catalogs. If Slither is installed
locally: `slither source/0xIMPL-Contract/ --checklist`. Use its output as leads.

## Forefy skill (Phase 5)

Forefy provides additional Solidity vulnerability-detection methodology/detectors.
Install via its `npx skills add ...` command and run it alongside pashov + ToB; union
all leads, then confirm manually.

---

## Tooling checklist (local)

- **Foundry**: `curl -L https://foundry.paradigm.xyz | bash && foundryup` -> `forge`,
  `cast`, `anvil` (Phase 3 source fetch + Phase 9 fork POCs).
- Optional decompilers: `heimdall-rs` (`heimdall`), Dedaub (web), panoramix (Phase 3).
- Optional: `gh` CLI (Phase 1 PR scanning), `slither`, `jq`.

## If a capability is unavailable

State plainly which tool is missing and the single command to install it, then proceed
with manual review + whatever IS available. The pipeline degrades gracefully: manual
reading against `invariants.md` is always the backbone; the skills/MCPs accelerate it.
