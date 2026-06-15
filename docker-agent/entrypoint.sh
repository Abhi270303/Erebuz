#!/usr/bin/env bash
#
# entrypoint.sh — dispatch the container on its first arg.
#
#   audit <target>   one-shot CLI audit; writes audits/<slug>/REPORT.md, then exits
#   serve            long-running HTTP API (POST /audit, GET /audit/{id})
#   raw  <args...>   passthrough to the opencode CLI (debugging)
#   <anything else>  exec'd verbatim (e.g. `bash`)
set -euo pipefail

MODE="${1:-serve}"

# Build a stable, filesystem-safe slug from an arbitrary target string.
slugify() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
  s="${s#-}"; s="${s%-}"
  printf '%s' "${s:0:48}"
}

run_audit() {
  local target="$1"
  local slug; slug="$(slugify "$target")"
  [ -n "$slug" ] || slug="target"
  local work="/work/audits/$slug"

  mkdir -p "$work/.opencode/agents"
  # Make the hunter swarm discoverable to opencode's task tool in this workspace.
  cp /opt/audit/agents/*.md "$work/.opencode/agents/" 2>/dev/null || true

  # Static template with placeholders (quoted heredoc => no expansion/escaping needed),
  # then substitute the dynamic bits.
  local template prompt
  template="$(cat <<'PROMPT'
You are a whitehat DeFi security auditor running fully autonomously and non-interactively.
Use the `defi-audit-pipeline` skill and run it END TO END against this target:

    __TARGET__

The target may be a protocol name, a "chain:address" pair, a bare contract address,
a DefiLlama slug, or a GitHub / pull-request URL. Resolve it, then:

  1. Scaffold the workspace under audits/__SLUG__/ using the skill scaffold script.
  2. Acquire exactly the source that is live on-chain (handle proxies/bytecode).
  3. Reconstruct invariants and the threat model.
  4. Run the parallel hunter swarm and converge the leads into ranked findings.
  5. Write per-finding files and Foundry fork-test PoCs where warranted.
  6. Produce a final audits/__SLUG__/REPORT.md.

Hard rules:
  - Whitehat scope only. PoCs run against local mainnet forks / testnets ONLY.
    Never broadcast an exploit transaction to a live contract holding third-party funds.
  - If an MCP or API key is missing, say so and continue with what is available.
  - Never invent contract addresses, source, findings, or Solodit hits.
  - When finished, print the absolute path to REPORT.md on the last line.
PROMPT
)"
  prompt="${template//__TARGET__/$target}"
  prompt="${prompt//__SLUG__/$slug}"

  cd /work
  echo ">> Auditing '${target}' -> ${work}"
  if [ -n "${OPENCODE_MODEL:-}" ]; then
    exec opencode run --model "$OPENCODE_MODEL" "$prompt"
  else
    exec opencode run "$prompt"
  fi
}

case "$MODE" in
  audit)
    shift
    [ "$#" -ge 1 ] || { echo "usage: audit <protocol|chain:address|github-url>" >&2; exit 2; }
    run_audit "$*"
    ;;
  serve)
    exec python3 /opt/audit/server.py
    ;;
  raw)
    shift
    cd /work
    exec opencode "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
