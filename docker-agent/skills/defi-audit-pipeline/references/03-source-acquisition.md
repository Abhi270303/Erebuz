# Phase 3 — Source acquisition (audit the deployed code)

Goal: for every contract address from Phase 1, obtain the **exact source that is live
on-chain**, resolving proxies to their real implementation, and decompiling when no
verified source exists. Store it under `audits/PROJECT/source/ADDR-Name/`.

Requires Foundry (`cast`). Set an explorer API key and RPC per chain:
```bash
export ETHERSCAN_API_KEY=...        # or the chain's explorer key
export ETH_RPC_URL=https://...      # archive node recommended for fork POCs later
```

`scripts/fetch_source.sh CHAIN ADDRESS` automates the verified-source + proxy-slot steps
below; read this file to handle the cases it flags.

## Step 1 — Try to fetch verified source

```bash
# Etherscan-family explorers (works for many EVM chains via --chain):
cast etherscan-source --chain ethereum 0xADDRESS --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -d source/0xADDRESS-raw
# Sourcify fallback (no key): https://repo.sourcify.dev/contracts/full_match/CHAINID/0xADDRESS/
```

If verified source comes back, note the compiler version, optimizer settings, and the
contract name. If it does NOT, the contract is unverified -> Step 4 (decompile) — but
first check whether it is a proxy whose implementation IS verified (Step 2-3).

## Step 2 — Detect a proxy

A contract is likely a proxy if: verified source is tiny / a known proxy contract
(`ERC1967Proxy`, `TransparentUpgradeableProxy`, `BeaconProxy`, `Proxy`), the ABI is
mostly a fallback, or callers interact with functions not in the verified source.
Confirm by reading standard storage slots with `cast storage`.

### EIP-1967 (transparent / UUPS) standard slots
- Implementation: `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
- Admin:          `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
- Beacon:         `0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50`

```bash
SLOT_IMPL=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
cast storage 0xPROXY $SLOT_IMPL --rpc-url "$ETH_RPC_URL"     # right-most 40 hex = impl
```

### Other proxy shapes
- **UUPS (EIP-1822)**: also uses the EIP-1967 impl slot; upgrade logic lives in the
  implementation (`upgradeTo`), guarded by `_authorizeUpgrade` — check that guard.
- **Beacon**: read beacon slot above, then call `implementation()` on the beacon:
  `cast call 0xBEACON "implementation()(address)" --rpc-url "$ETH_RPC_URL"`.
- **Transparent**: admin calls hit the proxy; everyone else is delegated — find the
  `ProxyAdmin` via the admin slot.
- **Minimal proxy / clones (EIP-1167)**: bytecode is the 45-byte template
  `363d3d373d3d3d363d73<impl-20-bytes>5af43d82803e903d91602b57fd5bf3`; the implementation
  address is embedded in the bytecode. Get it from:
  `cast code 0xCLONE --rpc-url "$ETH_RPC_URL"` and read the 20 bytes after `363d3d...73`.
- **Diamond (EIP-2535)**: no single impl; facets are mapped per-selector. Enumerate via
  the loupe: `cast call 0xDIAMOND "facets()((address,bytes4[])[])" --rpc-url ...` then
  fetch source for each facet address.

Many explorers also auto-detect proxies and expose a "Read as Proxy" / implementation
link — but verify the slot yourself; UIs can lag upgrades.

## Step 3 — Fetch the implementation source

Take the implementation (or each facet) address from Step 2 and repeat Step 1 on it.
Record the proxy -> implementation relationship in `source/deployed-vs-audited.md`. If
the implementation is verified, you now have the real logic; audit that, while keeping
the proxy's storage layout and admin powers in scope.

## Step 4 — Decompile unverified bytecode

When neither proxy nor implementation is verified, work from bytecode:

```bash
cast code 0xADDRESS --rpc-url "$ETH_RPC_URL" > source/0xADDRESS-Name/bytecode.hex
```

Decompilation options (use what is installed / available; cross-check more than one):
- **heimdall-rs** — `heimdall decompile 0xADDRESS --rpc-url "$ETH_RPC_URL"` produces
  Solidity-like output + decoded storage and selectors. Strong default.
- **Dedaub** decompiler (`app.dedaub.com`) — paste bytecode/address for high-quality
  output; good for complex contracts.
- **panoramix** / ethervm.io — quick selector + logic sketch.

Decompiled output is approximate: recover the function selectors and storage layout
first (`cast 4byte` / 4byte directory to name selectors), then reason about logic.
Flag in `source/deployed-vs-audited.md` that this contract is unverified and that
findings rest on decompilation.

## Step 5 — Selectors and ABI sanity

```bash
cast interface 0xADDRESS --chain ethereum --etherscan-api-key "$ETHERSCAN_API_KEY"  # if verified
# decode unknown selectors:
cast 4byte 0x12345678
```

## Output of this phase

`source/ADDR-Name/` per contract containing the verified or decompiled source, and
`source/deployed-vs-audited.md` recording for each address: is-proxy?, implementation
address, verified?, compiler, and which chain/deploy block. This is the actual audit
surface. Proceed to Phase 4 to diff it against what was audited and to extract
invariants.
