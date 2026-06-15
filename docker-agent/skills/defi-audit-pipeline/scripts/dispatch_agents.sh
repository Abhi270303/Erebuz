#!/usr/bin/env bash
#
# dispatch_agents.sh — install the audit swarm subagents, or print the dispatch
# plan for a project.
#
# Usage:
#   bash scripts/dispatch_agents.sh --install [--dest DIR]
#       Copy agents/agent-*.md into DIR (default .claude/agents/) so Claude Code
#       can use them as subagents in the project you are auditing.
#
#   bash scripts/dispatch_agents.sh --plan PROJECT [--base audits]
#       Print the fan-out/fan-in dispatch checklist and the exact output files to
#       expect, so you can confirm the swarm completed before converging.
#
# This script does no hunting and writes no findings. See
# references/10-agent-swarm-and-convergence.md and agents/README.md.
set -euo pipefail

# Resolve the skill root (this script lives in <root>/scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_SRC="$ROOT/agents"

HUNTERS=(pashov trailofbits forefy solodit invariant)
# Optional off-chain (web/code) swarm — hunts the dapp/API/repos, not the contracts.
# Recon lead (pentestswarm) runs first; the rest in parallel. See references/12.
WEB_HUNTERS=(cai hexstrike pentagi pentestgpt)

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; s/^#$//' | sed '$d'
  exit "${1:-0}"
}

cmd_install() {
  local dest=".claude/agents"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dest) dest="${2:?--dest needs a path}"; shift 2 ;;
      *) echo "unknown arg for --install: $1" >&2; exit 2 ;;
    esac
  done
  mkdir -p "$dest"
  local n=0
  for f in "$AGENTS_SRC"/agent-*.md; do
    [[ -e "$f" ]] || { echo "no agent-*.md found in $AGENTS_SRC" >&2; exit 1; }
    cp "$f" "$dest/"
    echo "  + $dest/$(basename "$f")"
    n=$((n + 1))
  done
  echo "installed $n subagent(s) into $dest"
  echo "the external skills/MCPs each wraps are installed separately —"
  echo "see references/06-external-skills.md."
}

cmd_plan() {
  local project="" base="audits"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base) base="${2:?--base needs a path}"; shift 2 ;;
      -*) echo "unknown arg for --plan: $1" >&2; exit 2 ;;
      *) project="$1"; shift ;;
    esac
  done
  [[ -n "$project" ]] || { echo "--plan needs PROJECT" >&2; exit 2; }
  # Match scaffold_project.py slugify.
  local slug
  slug="$(printf '%s' "$project" \
    | sed -E 's/[^a-zA-Z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  [[ -n "$slug" ]] || slug="project"
  local pdir="$base/$slug"
  local adir="$pdir/agents"

  echo "=== Audit swarm dispatch plan — $project ==="
  echo "workspace: $pdir"
  if [[ -d "$pdir" ]]; then
    echo "  (workspace exists)"
  else
    echo "  (workspace MISSING — run: python scripts/scaffold_project.py \"$project\")"
  fi
  echo
  echo "Preconditions: Phases 0-4 done; $pdir/invariants.md exists; agents installed"
  echo "(bash scripts/dispatch_agents.sh --install)."
  echo
  echo "STEP 1 — recon, run ALONE first:"
  echo "  agent-xray   -> $adir/x-ray.md (+ appends invariants.md)"
  echo "  Read x-ray.md; its ranked hot-contract list scopes every hunter below."
  echo
  echo "STEP 2 — hunters, dispatch IN PARALLEL (one Task each), same hot set:"
  for a in "${HUNTERS[@]}"; do
    printf '  agent-%-12s -> %s/%s-report.md  +  %s/%s.leads.jsonl\n' \
      "$a" "$adir" "$a" "$adir" "$a"
  done
  echo "  (claude.ai: no parallel subagents — run these sequentially in one context.)"
  echo
  echo "STEP 3 — converge, run LAST once all hunters wrote their files:"
  echo "  python scripts/merge_agent_reports.py \"$project\""
  echo "     -> $adir/_merged.leads.jsonl  +  $adir/_worktable.md"
  echo "  agent-converge -> $pdir/issues/SEVERITY-NN-slug.md (canonical findings)"
  echo "                 -> $adir/convergence.md (coverage matrix + decisions)"
  echo
  echo "Verify fan-out before converging — expected hunter feeds:"
  local missing=0
  for a in "${HUNTERS[@]}"; do
    local feed="$adir/$a.leads.jsonl"
    if [[ -f "$feed" ]]; then
      echo "  [x] $feed"
    else
      echo "  [ ] $feed   (missing — agent not run, or not installed)"
      missing=$((missing + 1))
    fi
  done
  if [[ "$missing" -gt 0 ]]; then
    echo "note: $missing hunter feed(s) absent. The swarm still converges on what ran"
    echo "(agent-invariant alone is a valid run); converge will flag the coverage gap."
  fi

  echo
  echo "=== Optional off-chain (web/code) swarm — references/12 ==="
  echo "Hunts the dapp/API/RPC/repos, not the contracts; feeds the SAME agent-converge."
  echo "PASSIVE by default; active scanning only against owned / in-scope-bug-bounty / lab"
  echo "targets (authorization gate). Skip this swarm if there is no off-chain surface."
  echo
  echo "STEP A — recon, run ALONE first:"
  echo "  agent-pentestswarm -> $adir/offchain-surface.md (the off-chain hot set)"
  echo "STEP B — hunters, dispatch IN PARALLEL, scoped to that hot set:"
  for a in "${WEB_HUNTERS[@]}"; do
    printf '  agent-%-12s -> %s/%s-report.md  +  %s/%s.leads.jsonl\n' \
      "$a" "$adir" "$a" "$adir" "$a"
  done
  echo "STEP C — converge: the same agent-converge folds these leads into issues/ too."
}

[[ $# -ge 1 ]] || usage 1
case "$1" in
  --install) shift; cmd_install "$@" ;;
  --plan)    shift; cmd_plan "$@" ;;
  -h|--help) usage 0 ;;
  *) echo "unknown command: $1" >&2; usage 2 ;;
esac
