#!/usr/bin/env python3
"""
merge_agent_reports.py — fan-in pre-clustering for the audit agent swarm.

Usage:
    python scripts/merge_agent_reports.py PROJECT [--base audits]

Reads every audits/PROJECT/agents/*.leads.jsonl (the per-hunter lead feeds),
normalizes and recomputes each lead's dedupe_key (bug_class|contract|function),
clusters leads that share a key, and writes two files the agent-converge agent
consumes:

    agents/_merged.leads.jsonl  — all valid leads, normalized, one per line
    agents/_worktable.md        — clusters + agent-by-contract coverage matrix

This script only PRE-clusters. It never writes to issues/ and never decides
severity — agent-converge + the human do that. Malformed lines are reported and
skipped, never invented. See assets/agent-lead-schema.md and
assets/convergence-worktable-template.md.
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# Hunters whose feeds we expect; rows of the coverage matrix appear in this order.
KNOWN_AGENTS = ["pashov", "trailofbits", "forefy", "solodit", "invariant"]
SEV_RANK = {"H": 4, "M": 3, "L": 2, "I": 1, "G": 0}
CONF_RANK = {"high": 3, "medium": 2, "low": 1}


def slugify(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "-", name.strip()).strip("-") or "project"


def norm(v) -> str:
    return ("" if v is None else str(v)).strip()


def dedupe_key(lead: dict) -> str:
    return "|".join((
        norm(lead.get("bug_class")) or "unknown",
        norm(lead.get("contract")) or "unknown",
        norm(lead.get("function")),
    ))


def load_leads(agents_dir: Path):
    """Return (leads, problems). leads: list of dicts with dedupe_key recomputed."""
    leads, problems = [], []
    feeds = sorted(p for p in agents_dir.glob("*.leads.jsonl")
                   if not p.name.startswith("_"))
    for feed in feeds:
        for i, raw in enumerate(feed.read_text(encoding="utf-8").splitlines(), 1):
            line = raw.strip()
            if not line:
                continue
            try:
                lead = json.loads(line)
            except json.JSONDecodeError as e:
                problems.append(f"{feed.name}:{i}: invalid JSON ({e.msg})")
                continue
            if not isinstance(lead, dict):
                problems.append(f"{feed.name}:{i}: not a JSON object")
                continue
            # Trust the agent field if present, else infer from filename.
            if not norm(lead.get("agent")):
                lead["agent"] = feed.name.split(".leads.jsonl")[0]
            for req in ("title", "bug_class", "contract", "severity_guess"):
                if not norm(lead.get(req)):
                    problems.append(
                        f"{feed.name}:{i}: missing required field '{req}' "
                        f"(lead {lead.get('lead_id','?')})")
            lead["dedupe_key"] = dedupe_key(lead)
            leads.append(lead)
    return leads, problems, [f.name for f in feeds]


def max_sev(leads):
    best = min(leads, key=lambda l: -SEV_RANK.get(norm(l.get("severity_guess")), -1),
               default=None)
    return norm(best.get("severity_guess")) if best else ""


def max_conf(leads):
    best = max((norm(l.get("confidence")) for l in leads),
               key=lambda c: CONF_RANK.get(c, 0), default="")
    return best


def build_worktable(project, leads, feeds_seen, problems):
    agents_present = [a for a in KNOWN_AGENTS
                      if any(norm(l.get("agent")) == a for l in leads)]
    # also include any unexpected agent ids that showed up
    extra = sorted({norm(l.get("agent")) for l in leads}
                   - set(agents_present) - {""})
    agent_rows = agents_present + extra

    contracts = sorted({norm(l.get("contract")) or "unknown" for l in leads})

    clusters = defaultdict(list)
    for l in leads:
        clusters[l["dedupe_key"]].append(l)
    # sort clusters by max severity then corroboration count, both desc
    ordered = sorted(
        clusters.items(),
        key=lambda kv: (SEV_RANK.get(max_sev(kv[1]), -1), len(kv[1])),
        reverse=True,
    )

    out = []
    out.append(f"# Convergence worktable — {project} (auto-generated)\n")
    out.append("Pre-clustered by `merge_agent_reports.py`. `agent-converge` edits this "
               "into the\nfinal `convergence.md`: confirm/merge/drop each cluster, set "
               "real severities, and\npromote survivors to `issues/`. Corroboration "
               "count is recorded, never a gate.\n")

    out.append("## Run summary\n")
    out.append(f"- Lead feeds read: {', '.join(feeds_seen) if feeds_seen else 'NONE'}")
    out.append(f"- Valid leads ingested: {len(leads)}")
    out.append(f"- Distinct clusters (dedupe_key): {len(clusters)}")
    not_run = [a for a in KNOWN_AGENTS if a not in agents_present]
    if not_run:
        out.append(f"- Known hunters with NO leads this run: {', '.join(not_run)} "
                   f"(not installed, or clean — confirm which)")
    out.append("")

    out.append("## Coverage matrix (leads per agent × contract)\n")
    header = "| agent \\ contract | " + " | ".join(f"`{c}`" for c in contracts) + " |"
    sep = "|" + "---|" * (len(contracts) + 1)
    out.append(header)
    out.append(sep)
    for a in agent_rows:
        cells = []
        for c in contracts:
            n = sum(1 for l in leads
                    if norm(l.get("agent")) == a
                    and (norm(l.get("contract")) or "unknown") == c)
            cells.append(str(n) if n else "–")
        out.append(f"| {a} | " + " | ".join(cells) + " |")
    out.append("\n`–` = no lead (looked-and-clean vs never-looked is for converge to "
               "resolve from the\nagent reports). Add a row note for any hunter that did "
               "not run at all.\n")

    out.append("## Clusters (one row per dedupe_key, severity-ranked)\n")
    out.append("| dedupe_key | agents (corrob.) | max sev_guess | max conf | "
               "-> issue file | decision / reason |")
    out.append("|---|---|---|---|---|---|")
    for key, group in ordered:
        agents = sorted({norm(l.get("agent")) for l in group})
        corrob = f"{', '.join(agents)} ({len(agents)})"
        out.append(f"| `{key}` | {corrob} | {max_sev(group)} | {max_conf(group)} "
                   f"|  | TODO |")
    out.append("")

    out.append("### Lead detail per cluster\n")
    for key, group in ordered:
        out.append(f"#### `{key}`  — {len(group)} lead(s)")
        for l in sorted(group, key=lambda x: norm(x.get("agent"))):
            loc = norm(l.get("location")) or "no-location"
            out.append(
                f"- **{norm(l.get('agent'))}** "
                f"`{norm(l.get('lead_id'))}` "
                f"[{norm(l.get('severity_guess'))}/{norm(l.get('confidence'))}] "
                f"{norm(l.get('title'))}")
            out.append(f"  - loc: `{loc}`  inv: {norm(l.get('invariant')) or '–'}"
                       f"  solodit: {norm(l.get('solodit_ref')) or '–'}")
            if norm(l.get("summary")):
                out.append(f"  - {norm(l.get('summary'))}")
            if norm(l.get("needs")):
                out.append(f"  - needs (POC): {norm(l.get('needs'))}")
        out.append("")

    if problems:
        out.append("## Skipped / malformed lines (fix or ignore — NOT invented)\n")
        for p in problems:
            out.append(f"- {p}")
        out.append("")

    out.append("## Next (agent-converge)\n")
    out.append("1. For each cluster: confirm/merge/split/drop; re-read cited evidence.")
    out.append("2. Promote survivors to `issues/SEVERITY-NN-slug.md` "
               "(template + rubric).")
    out.append("3. Finalize the coverage matrix narrative; call out gaps.")
    out.append("4. Route chains -> `audit-log.md` (Phase 8); copy `needs` -> POC "
               "to-dos (Phase 9).")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Merge swarm agent lead feeds.")
    ap.add_argument("project", help="project name (same value used at scaffold time)")
    ap.add_argument("--base", default="audits", help="base directory (default: audits)")
    args = ap.parse_args()

    root = Path(args.base) / slugify(args.project)
    agents_dir = root / "agents"
    if not agents_dir.is_dir():
        print(f"error: {agents_dir} does not exist. Run the swarm (and scaffold) first.",
              file=sys.stderr)
        return 1

    leads, problems, feeds_seen = load_leads(agents_dir)

    merged = agents_dir / "_merged.leads.jsonl"
    merged.write_text(
        "".join(json.dumps(l, ensure_ascii=False) + "\n" for l in leads),
        encoding="utf-8")

    worktable = agents_dir / "_worktable.md"
    worktable.write_text(build_worktable(args.project, leads, feeds_seen, problems),
                         encoding="utf-8")

    print(f"merged {len(leads)} lead(s) from {len(feeds_seen)} feed(s)")
    if problems:
        print(f"  {len(problems)} malformed/incomplete line(s) flagged in worktable")
    print(f"  -> {merged}")
    print(f"  -> {worktable}")
    print("\nNext: agent-converge reads _worktable.md, then writes canonical issues/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
