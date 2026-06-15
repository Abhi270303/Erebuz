#!/usr/bin/env python3
"""
scaffold_project.py — create the standard DeFi-audit project folder layout.

Usage:
    python scripts/scaffold_project.py PROJECT [--base audits]

Creates audits/PROJECT/ with the folder tree and seed .md files used by the
defi-audit-pipeline skill. Idempotent: never overwrites an existing file.
See assets/project-structure.md for the annotated layout.
"""
import argparse
import re
import sys
from pathlib import Path

SEED = {
    "README.md": """# {name} — audit workspace

- **What it is:** TODO (one paragraph)
- **What it custodies:** TODO (whose funds, how much)
- **Who can move the money:** TODO (roles: owner/guardian/governance/keeper)
- **Status:** recon

## Key links
- DefiLlama PR: 
- Website: 
- Docs: 
- Repo (audited commit): 
""",
    "recon.md": """# Recon — {name} (Phase 1)

## Source
- DefiLlama PR: #  — URL: 
- Author / date: 
- DefiLlama slug / category: 
- audit_links (from api.llama.fi): 

## Contracts (from the adapter projects/<name>/index.js)
| address | chain | role (guess) | proxy? | deploy block |
|---------|-------|--------------|--------|--------------|
| 0x... | ethereum |  | ? |  |

## Open questions
- 
""",
    "invariants.md": """# Invariants — {name} (Phase 4)

Status values: enforced (cite file:line) | assumed | MISSING (call out explicitly).

INV-01  <statement of what must always/never be true>
  enforced-by: 
  breaks-if:   
  status:      

<!-- Pull the canonical invariants for this protocol type (lending / AMM / ERC4626 /
     staking / bridge / stablecoin / perps) from Solodit categories — see Phase 6. -->
""",
    "integration-map.md": """# Integration map — {name} (Phase 8)

## Internal (file-to-file)
- <Contract>.<fn> -> <Other>.<fn>   (call | delegatecall | staticcall)
- shared storage / trust edges: 

## External dependencies (assumption -> how it breaks)
- Tokens: 
- Oracles: 
- Other protocols / bridges: 
- Privileged infra (governance/timelock/multisig/keeper): 
""",
    "audit-log.md": """# Audit log — {name} (top-level auditor notebook)

## Coverage
- [ ] <contract / function reviewed?>

## Hunches (not yet findings)
- 

## Chaining ideas (Phase 8)
- e.g. L-02 + I-05 might break INV-03 -> test in POC

## Questions for the protocol team
- 
""",
    "source/deployed-vs-audited.md": """# Deployed vs audited — {name} (Phase 3/4)

| address | proxy? | implementation | verified? | compiler | chain/block | audited commit | delta |
|---------|--------|----------------|-----------|----------|-------------|----------------|-------|
| 0x... | yes/no | 0x... | yes/no |  |  |  | identical / cosmetic / BEHAVIORAL / UNAUDITED |

## Behavioral deltas (deployed differs from audited) — HIGH priority
- 

## Deployed but never audited — HIGH priority
- 

## Prior findings: confirm each was actually fixed
- 
""",
    "research/website.md": "# Website — {name} (Phase 2)\n\n- Description: \n- URLs: \n- Trust hints (custodial? upgradeable? pausable? admin powers?): \n",
    "research/docs.md": "# Docs — {name} (Phase 2)\n\n## Mechanism (plain English)\n\n## Stated invariants / assumptions (-> invariants.md)\n\n## Roles & permissions\n\n## External dependencies\n",
    "research/audits.md": "# Prior audits — {name} (Phase 2)\n\n| firm | date | commit/scope | report URL | headline findings | fixed? |\n|------|------|--------------|-----------|-------------------|--------|\n|  |  |  |  |  |  |\n",
    "research/repos.md": "# Repos — {name} (Phase 2)\n\n| repo | default branch | audited commit/tag | core source path | language |\n|------|----------------|--------------------|------------------|----------|\n|  |  |  |  | Solidity/Rust |\n\n## Mismatch vs deployed addresses?\n- \n",
    "issues/.gitkeep": "",
    "pocs/.gitkeep": "",
    "agents/README.md": """# Agents — {name} (Phase 5 swarm output)

The bug-hunting swarm writes here. One subagent per audit lens, run in parallel over the
hot contracts from `x-ray.md`, then converged. See the skill's
`references/10-agent-swarm-and-convergence.md` and `agents/README.md`.

- `x-ray.md`               — threat model + ranked hot-contract set (agent-xray, first)
- `<id>-report.md`         — per-lens narrative (pashov, trailofbits, forefy, solodit, invariant)
- `<id>.leads.jsonl`       — per-lens machine-readable leads (schema: assets/agent-lead-schema.md)
- `_merged.leads.jsonl`    — all leads, clustered (scripts/merge_agent_reports.py)
- `_worktable.md`          — clusters + agent-by-contract coverage matrix
- `convergence.md`         — dedupe/corroborate decisions + coverage matrix (agent-converge, last)

Hunters emit **leads, not findings**. Only the convergence step promotes leads into
`../issues/`. Nothing here is a confirmed finding until a POC passes (Phase 9).
""",
}


def main():
    ap = argparse.ArgumentParser(description="Scaffold a DeFi-audit project folder.")
    ap.add_argument("project", help="project name (kept human-readable; folder uses a safe slug)")
    ap.add_argument("--base", default="audits", help="base directory (default: audits)")
    args = ap.parse_args()

    name = args.project.strip()
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "-", name).strip("-") or "project"
    root = Path(args.base) / slug

    if root.exists():
        print(f"note: {root} already exists — filling in only missing files (no overwrite).")
    for sub in ("research", "source", "source/.", "issues", "pocs", "agents"):
        (root / sub).mkdir(parents=True, exist_ok=True)

    created, skipped = [], []
    for rel, template in SEED.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            skipped.append(rel)
            continue
        path.write_text(template.format(name=name))
        created.append(rel)

    print(f"\nProject workspace: {root}")
    if created:
        print("  created:")
        for r in created:
            print(f"    + {r}")
    if skipped:
        print(f"  skipped {len(skipped)} existing file(s).")
    print("\nNext: Phase 1 recon -> fill recon.md. See SKILL.md and references/01-defillama-pr-recon.md.")


if __name__ == "__main__":
    sys.exit(main())
