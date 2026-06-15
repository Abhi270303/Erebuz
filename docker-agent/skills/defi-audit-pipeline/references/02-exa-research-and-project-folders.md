# Phase 2 — Project research with the Exa MCP

Goal: build a complete picture of the target — what it claims to do, its docs, its prior
audits, and where its real source lives — and distill each into a `.md` file under
`audits/PROJECT/research/`. You are gathering the protocol's *intended* behavior and
*stated security assumptions*; later phases test whether the deployed code honors them.

See `references/06-external-skills.md` for Exa MCP install/setup. Tools available:
`web_search_exa`, `get_code_context_exa`, `crawling_exa`, `company_research_exa`,
`linkedin_search_exa`, `deep_search_exa`, `deep_researcher_start`,
`deep_researcher_check`.

## Which Exa tool for which job

| Need | Tool |
|------|------|
| Find the project's site, blog, audit announcements | `web_search_exa` |
| Pull full text from a known URL (docs page, audit PDF, PR) | `crawling_exa` |
| Find source / understand a contract or library from GitHub, StackOverflow | `get_code_context_exa` |
| Team / company background (rug-risk, history) | `company_research_exa`, `linkedin_search_exa` |
| Broad open-ended investigation | `deep_search_exa`, or `deep_researcher_start` then `deep_researcher_check` |

## Context discipline (important)

Exa results can be large. In **Claude Code**, run each research query inside a Task
sub-agent whose only job is "search X, return a 5-bullet distilled summary + the URLs
and any contract addresses." The sub-agent's verbose results stay out of your main
context; you keep only the distillate. On **claude.ai** (no sub-agents), search inline
but immediately write the distilled `.md` and do not keep raw pages in context.

Never paste long pages into findings; cite the URL and summarize in your own words.

## What to collect and where it goes

Create these files under `research/`:

### `research/website.md`
- One-paragraph product description (what value it custodies, for whom).
- Live URLs (app, landing, status page).
- Anything that hints at trust assumptions: "non-custodial", "admin can pause",
  "upgradeable", "governance controls fees".

### `research/docs.md`
The most valuable file for invariants. From the docs (`crawling_exa` the docs pages):
- The mechanism in plain English (mint/redeem, lend/borrow, swap, stake, bridge...).
- **Stated invariants and assumptions** — quote what the docs promise must hold (e.g.
  "1 share is always redeemable for >= 1 underlying", "only the timelock can upgrade",
  "oracle price is TWAP over 30 min"). These become Phase 4 invariants to test.
- Roles/permissions (owner, guardian, governance, keeper) and what each can do.
- External dependencies the docs mention (oracles, bridges, base protocols).

### `research/audits.md`
For each prior audit you can find (search "PROJECT audit", check the DefiLlama
`audit_links`, the docs' security page, audit-firm portfolios):
- Firm, date, **commit hash / scope** audited, report URL.
- Headline findings and their resolution status.
- The exact commit audited — you need it in Phase 4 to diff audited-vs-deployed.
Use `crawling_exa` to pull the report text; summarize, do not dump.

### `research/repos.md`
- Every GitHub repo (`get_code_context_exa` and `web_search_exa`): contracts repo,
  monorepo, SDK.
- For each: default branch, the **commit hash** that matches the audit (tag/release),
  and the on-disk path of the core contracts (`src/`, `contracts/`).
- Language(s): Solidity (EVM) vs Rust (Solana/CosmWasm/Stylus) — sets your tooling.
- Note if the repo looks different from what the adapter addresses suggest is deployed.

## Reconcile against Phase 1

Cross-check: do the addresses from `recon.md` match deployments referenced in the
docs/repo? Mismatches (extra contracts, different chain, newer deploy than the audited
commit) are leads — record them in `recon.md` open questions and in
`source/deployed-vs-audited.md` (Phase 4).

## Output of this phase

Populated `research/` folder + an updated `README.md` with a crisp "what it is / what it
custodies / who can touch the money" summary. You now know what the protocol *promises*;
Phase 3 gets the code that has to deliver it.
