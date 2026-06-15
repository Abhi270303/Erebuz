#!/usr/bin/env bash
#
# prepare.sh — OPTIONAL. Refresh the bundled skills/MCPs/agents under docker/
# from your local ~/.claude/skills.
#
# The image is self-contained: docker/skills, docker/mcp, and docker/agents are
# committed and the Dockerfile COPYs them directly. You only need this script
# when you've updated a skill locally and want the bundled copy to match.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SKILLS_SRC="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

EXCL=(--exclude '__pycache__' --exclude '.git' --exclude 'node_modules'
      --exclude '*.pyc' --exclude '.DS_Store')

# Essential skills the pipeline orchestrates (missing ones are skipped — the
# agent degrades gracefully per SKILL.md).
SKILLS=(
  defi-audit-pipeline solidity-auditor x-ray smart-contract-audit
  solodit foundry-poc defi-fork-audit defi-data
)

echo ">> Refreshing bundled skills from $SKILLS_SRC"
mkdir -p "$HERE/skills" "$HERE/mcp" "$HERE/agents"

for s in "${SKILLS[@]}"; do
  if [ -d "$SKILLS_SRC/$s" ]; then
    rm -rf "$HERE/skills/$s"
    rsync -a "${EXCL[@]}" "$SKILLS_SRC/$s" "$HERE/skills/"
    echo "   + skill: $s"
  else
    echo "   - skill missing (skipped): $s"
  fi
done

[ -d "$HERE/skills/defi-audit-pipeline" ] || { echo "FATAL: defi-audit-pipeline not found" >&2; exit 1; }

# Local MCP servers (chainlist + defillama) from this repo.
rsync -a "${EXCL[@]}" "$REPO/.opencode/"mcp-*.py "$HERE/mcp/" 2>/dev/null \
  && echo "   + local MCP servers" || echo "   - no local MCP servers found"

# Hunter swarm: ships inside the pipeline skill, plus any repo off-chain swarm.
cp "$HERE/skills/defi-audit-pipeline/agents/"agent-*.md "$HERE/agents/" 2>/dev/null \
  && echo "   + swarm agents (from skill)" || true
cp "$REPO/.claude/agents/"agent-*.md "$HERE/agents/" 2>/dev/null \
  && echo "   + swarm agents (from repo)" || true

echo ">> Done. Bundled sizes:"
du -sh "$HERE/skills" "$HERE/mcp" "$HERE/agents" | sed 's,^,   ,'
