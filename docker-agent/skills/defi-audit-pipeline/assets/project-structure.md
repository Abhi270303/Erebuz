# Project folder layout (annotated)

`scripts/scaffold_project.py PROJECT` creates this under `audits/PROJECT/`. Everything
you learn lives here as `.md` files so the audit is resumable and the report assembles
itself from `issues/`.

```
audits/PROJECT/
├── README.md              # what it is / what it custodies / who can move the money / status
├── recon.md               # Phase 1: source PR, contract addresses + chains + deploy blocks,
│                          #          DefiLlama slug/category/audit_links, open questions
├── research/              # Phase 2 (Exa)
│   ├── website.md         #   product description, live URLs, trust hints
│   ├── docs.md            #   mechanism + STATED invariants/assumptions + roles + deps
│   ├── audits.md          #   prior audits: firm, date, COMMIT/scope, report URL, fixes
│   └── repos.md           #   GitHub repos, audited commit hash, source paths, language
├── source/                # Phase 3 (what is actually deployed)
│   ├── ADDR-Name/         #   verified or decompiled source per contract/facet
│   └── deployed-vs-audited.md  # proxy->impl map, verified?, compiler, chain/block;
│                               # Phase 4 diff classification (behavioral deltas, unaudited code)
├── invariants.md          # Phase 4: invariants with status enforced/assumed/MISSING
├── integration-map.md     # Phase 8: internal call/trust graph + external deps & assumptions
├── agents/                # Phase 5 swarm: one subagent per lens, hunted in parallel, converged
│   ├── x-ray.md            #   threat model + ranked hot-contract set (agent-xray, runs first)
│   ├── <id>-report.md      #   per-lens narrative: pashov|trailofbits|forefy|solodit|invariant
│   ├── <id>.leads.jsonl    #   per-lens leads (schema: assets/agent-lead-schema.md)
│   ├── _merged.leads.jsonl #   all leads clustered by bug_class|contract|function (merge script)
│   ├── _worktable.md       #   clusters + agent-by-contract coverage matrix
│   └── convergence.md      #   dedupe/corroborate decisions + coverage gaps (agent-converge, last)
├── issues/                # Phase 7: ONE finding per file, named SEVERITY-NN-slug.md
│   ├── H-01-....md         #   (H high, M medium, L low, I informational, G gas)
│   ├── M-01-....md
│   └── I-01-....md
├── pocs/                  # Phase 9: Foundry fork tests proving the findings
│   └── *.t.sol
└── audit-log.md           # running top-level notes: coverage, hunches, CHAINING ideas, questions
```

## How the files feed each other
- `recon.md` addresses -> `source/` (Phase 3) and seed `research/` (Phase 2).
- `research/docs.md` assumptions + `source/` code + protocol-type knowledge -> `invariants.md`.
- `invariants.md` (esp. MISSING) + `source/deployed-vs-audited.md` behavioral deltas ->
  prioritized hunting list (Phase 5/6).
- observations -> `issues/` immediately (Phase 7); Solodit refs attached (Phase 6).
- `integration-map.md` + re-reading `issues/` -> chained, higher-impact findings (Phase 8).
- chained findings -> `pocs/` (Phase 9) -> finding status flips to `confirmed`.
- `issues/` + `pocs/` -> final report (Phase 10).

## Conventions
- Address-named folders use the checksummed address prefix + a human name:
  `source/0xAbc...123-Vault/`.
- Keep raw pages/PDFs OUT of these files — summarize and cite URLs (context discipline).
- A finding's severity is provisional; rename its file if chaining/POC changes it.
