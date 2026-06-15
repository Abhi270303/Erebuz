#!/usr/bin/env bash
# fetch_source.sh — fetch verified deployed source + resolve EIP-1967 proxies via cast.
#
# Usage:
#   ETHERSCAN_API_KEY=... ETH_RPC_URL=... \
#     scripts/fetch_source.sh <chain> <address> [out_dir]
#
# Example:
#   scripts/fetch_source.sh ethereum 0xABC... audits/PROJECT/source
#
# Does:
#   1. cast etherscan-source for the address (verified source).
#   2. Reads EIP-1967 implementation / admin / beacon storage slots.
#   3. If an implementation is found, fetches its verified source too.
#   4. Dumps runtime bytecode (useful when unverified -> decompile, see Phase 3).
# Degrades gracefully: reports what is missing instead of failing hard.
set -uo pipefail

CHAIN="${1:-}"; ADDR="${2:-}"; OUT="${3:-source}"
if [[ -z "$CHAIN" || -z "$ADDR" ]]; then
  echo "usage: fetch_source.sh <chain> <address> [out_dir]" >&2
  exit 2
fi
if ! command -v cast >/dev/null 2>&1; then
  echo "error: 'cast' (Foundry) not found. Install: curl -L https://foundry.paradigm.xyz | bash && foundryup" >&2
  exit 3
fi
: "${ETH_RPC_URL:?set ETH_RPC_URL to an RPC for $CHAIN (archive node recommended)}"

# EIP-1967 standard slots
SLOT_IMPL=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
SLOT_ADMIN=0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
SLOT_BEACON=0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50

mkdir -p "$OUT"
ADDR_LC="$(echo "$ADDR" | tr '[:upper:]' '[:lower:]')"
base="$OUT/${ADDR_LC}"

slot_to_addr() { # last 40 hex chars of a 32-byte word -> 0x-address (0x0 if empty)
  local raw="${1#0x}"; raw="${raw: -40}"
  if [[ -z "$raw" || "$raw" =~ ^0+$ ]]; then echo ""; else echo "0x${raw}"; fi
}

fetch_verified() { # <address> <dir>
  local a="$1" d="$2"
  mkdir -p "$d"
  if [[ -n "${ETHERSCAN_API_KEY:-}" ]]; then
    echo ">> verified source for $a (chain=$CHAIN) -> $d"
    cast etherscan-source --chain "$CHAIN" "$a" --etherscan-api-key "$ETHERSCAN_API_KEY" -d "$d" \
      && echo "   ok" \
      || echo "   no verified source (unverified, or wrong chain/key) — see Phase 3 Step 4 (decompile)."
  else
    echo "!! ETHERSCAN_API_KEY unset — skipping verified-source fetch for $a."
    echo "   Try Sourcify: https://repo.sourcify.dev/contracts/full_match/<chainId>/$a/"
  fi
}

echo "=== $ADDR on $CHAIN ==="
fetch_verified "$ADDR" "${base}-raw"

echo ">> reading EIP-1967 proxy slots"
impl_raw="$(cast storage "$ADDR" "$SLOT_IMPL" --rpc-url "$ETH_RPC_URL" 2>/dev/null || true)"
admin_raw="$(cast storage "$ADDR" "$SLOT_ADMIN" --rpc-url "$ETH_RPC_URL" 2>/dev/null || true)"
beacon_raw="$(cast storage "$ADDR" "$SLOT_BEACON" --rpc-url "$ETH_RPC_URL" 2>/dev/null || true)"
IMPL="$(slot_to_addr "${impl_raw:-}")"
ADMIN="$(slot_to_addr "${admin_raw:-}")"
BEACON="$(slot_to_addr "${beacon_raw:-}")"

echo "   implementation slot: ${IMPL:-<empty>}"
echo "   admin slot:          ${ADMIN:-<empty>}"
echo "   beacon slot:         ${BEACON:-<empty>}"

if [[ -n "$BEACON" && -z "$IMPL" ]]; then
  echo ">> beacon proxy — querying beacon.implementation()"
  IMPL="$(cast call "$BEACON" "implementation()(address)" --rpc-url "$ETH_RPC_URL" 2>/dev/null || true)"
  echo "   beacon implementation: ${IMPL:-<unknown>}"
fi

if [[ -n "$IMPL" ]]; then
  echo ">> proxy detected — fetching implementation source"
  fetch_verified "$IMPL" "${OUT}/${IMPL,,}-impl"
  echo "   RECORD in source/deployed-vs-audited.md: $ADDR (proxy) -> $IMPL (impl); admin=${ADMIN:-?}"
else
  echo "   no EIP-1967 implementation slot set."
  echo "   If callers hit functions absent from the verified source, check other proxy"
  echo "   shapes (UUPS/transparent/beacon/minimal-proxy EIP-1167/diamond) — Phase 3 Step 2."
fi

echo ">> dumping runtime bytecode (for decompilation if unverified)"
cast code "$ADDR" --rpc-url "$ETH_RPC_URL" > "${base}.bytecode.hex" 2>/dev/null \
  && echo "   wrote ${base}.bytecode.hex" \
  || echo "   could not fetch bytecode."

echo "=== done. Next: classify deltas in source/deployed-vs-audited.md (Phase 4). ==="
