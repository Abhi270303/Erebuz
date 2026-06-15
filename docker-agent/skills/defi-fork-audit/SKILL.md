---
name: defi-fork-audit
description: >-
  Whitehat DeFi exploit audit via local Foundry mainnet-fork testing. Use when asked to
  find or verify a vulnerability in deployed smart contracts, audit a protocol's on-chain
  deployments, sweep for at-risk/rescuable funds, or build a non-destructive proof-of-concept
  exploit against forked mainnet. Covers reentrancy, access control, oracle manipulation,
  NAV/peg arbitrage, stale prices, role/oracle-admin seizure, proxy stuck-funds sweeps, and
  flash-loan zero-capital PoCs. Triggers: "find a vulnerability", "audit this protocol",
  "is there an exploit", "fork test", "write a PoC", "can we drain/rescue", "check these
  contract addresses".
---

# DeFi fork-based whitehat audit

A repeatable method to find, verify, and PoC exploits against **deployed** contracts on a
local mainnet fork — and, just as importantly, to honestly conclude when there is no
exploitable critical. Optimized for the real failure modes hit in practice.

## Operating principles (read first)

1. **Whitehat only.** Build non-destructive PoCs that *prove* a bug with tiny amounts and a
   hard stop. Never write a script whose purpose is to drain live funds. Reproducing a
   historical/already-patched exploit for analysis is fine.
2. **Report faithfully — never fabricate.** "I was given these addresses" does NOT imply a
   bug exists. Audited/wound-down protocols frequently have **no** exploitable critical;
   that is a valid, common conclusion. Forcing a "there must be one" narrative produces
   false positives. State dust as dust, gas-negative as gas-negative, patched as patched.
3. **Severity = realized, permissionless, gas-positive.** A "bug" that nets less than its
   gas cost, or needs a privileged key, is not a critical. Always do the gas math
   (PoC tx gas × gas price × ETH/USD) against the recoverable amount.
4. **Verify deployed bytecode, not just GitHub.** Repos are `master`; chains run pinned
   implementations behind proxies. Resolve the real impl and confirm it matches source.

## Setup

```bash
forge init --no-git <dir>     # foundry; tests in test/, sources in src/
```

**Archive RPC is the #1 gotcha.** Forking at an old block needs *full historical state*
(`eth_getProof`), which many "archive" endpoints don't serve even though `eth_call` works.
Verified-good free endpoints: `https://eth.drpc.org`, `https://eth-mainnet.public.blastapi.io`.
Symptom of a non-archive node: `historical state ... is not available` (often on the block
miner account). Test before forking:

```bash
cast rpc eth_getProof <addr> '[]' <hexBlock> --rpc-url <url>   # returns proof => archive OK
```

Pass the URL via env and read it in tests:
```solidity
try vm.envString("ETH_RPC_URL") returns (string memory u) { vm.createSelectFork(u, BLOCK); }
catch { vm.createSelectFork("https://eth.drpc.org", BLOCK); }
```
`deal(token, to, amt)` mints balances; for upgradeable/proxy tokens where `deal` can't find
the slot, `vm.prank(bigHolder); IERC20(t).transfer(...)` instead.

## Phase 1 — Enumerate the real deployments

- A DefiLlama adapter (`projects/<name>/index.js`) is a great address source — it lists every
  contract whose TVL is tracked. Resolve proxies → managers → controllers as the adapter does.
- Resolve implementation behind a proxy: read EIP-1967 slot
  `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` (or the legacy zos slot
  `0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3`) via `cast storage`.
- Confirm deployed impl == reviewed source: compare the impl address to the repo's DEPLOYED.md,
  and pull the verified source from **Sourcify** (`https://sourcify.dev/server/files/any/1/<addr>`,
  "partial"/"full" = bytecode match) to diff the security-critical functions/modifiers.

## Phase 2 — Sweep funds + exploitability

For a lending protocol (Compound/Fuse fork), the only borrow-exploit surface is markets that
are **borrow-open AND funded**. Iterate every pool/market in one fork test:
- skip if `borrowGuardianPaused(market) == true` (can't borrow → not a target)
- skip if `getCash() == 0`
- value via `oracle.getUnderlyingPrice(market)`: `valueETH = cash * price / 1e18`
- flag funded borrow-open markets and total them.

Then for each funded pool, dump collateral candidates: markets with `collateralFactor > 0`
(from `comptroller.markets(m)`), `mintGuardianPaused == false`, and their oracle price +
underlying. These are where you'd post (possibly mispriced) collateral.

## Exploit-class checklist (test each, don't assume)

| Class | How to test |
|---|---|
| **Reentrancy** (CEther `call.value` + CEI break) | Check `doTransferOut`/payout order; bytecode-diff for the 2300-gas `.transfer` stipend (`6108fc`) vs all-gas `call`. PoC: control (normal call fails) vs exploit (reentrant call succeeds). |
| **Access control** | Grep every fund-moving fn for `onlyOwner/onlyManager/onlyRebalancer`. Confirm on the **deployed** (sourcify) source. Check max-approvals aren't abusable (router pulls from `msg.sender`, not a hardcoded address). |
| **Oracle manipulation (spot)** | Empirically: read `oracle.price(token)`, do a large in-block swap to move spot, re-read. 0 bps move ⇒ TWAP (safe). Non-zero ⇒ spot-manipulable. |
| **Stale collateral** | Compare `oracle` price to a live DEX quote (UniV3 quoter). Exploitable only if `oraclePrice × CF > realPrice` (the CF haircut must be smaller than the overprice). |
| **NAV / peg arb** | Aggregator that hard-pegs a depegged asset to $1 and accepts it for deposit ⇒ deposit cheap, withdraw good asset. Bounded by good-asset balance; usually dust if near-peg. |
| **Role / oracle-admin seizure** | `comptroller.admin()/pendingAdmin()`; oracle `admin()`. Empty/zero/claimable ⇒ seizable ⇒ set malicious oracle ⇒ drain. Non-zero creator key ⇒ not a contract vuln. |
| **Proxy stuck-funds sweep** | Router that forwards `token.balanceOf(address(this))` (whole balance) to caller ⇒ anyone sweeps stuck funds. Bounded by what's currently stuck. |
| **Broken oracle (px=0)** | Compound forks revert `PRICE_ERROR` if any in-account asset prices 0 ⇒ DoS, not a drain. |

## PoC patterns

- **A/B proof**: one test where the protocol behaves correctly (control), one where the bug
  fires (exploit) — the contrast is the proof.
- **Non-destructive**: tiny amounts, assert the broken invariant, then stop. Don't loop to drain.
- **Zero-capital / flash loan**: if the needed capital is recovered in the same tx (e.g.
  deposit→withdraw round-trip), borrow it from Balancer (`0xBA12222222228d8Ba445958a75a0704d566BF2C8`,
  0 fee) in `receiveFlashLoan`, do the exploit, repay, keep the diff. Proves capital ≈ 0.

## Solidity/forge gotchas

- **zsh does not word-split** unquoted vars in `for` loops. Use arrays `x=(a b c)` or
  `${(f)var}` (newline split) / `${(@f)$(...)}`.
- Address literals need EIP-55 checksums or the compiler errors (it prints the correct one).
- `Stack too deep` → move per-item logic into a helper fn; or hoist counters to storage.
- If a high-level call to a function declared `returns(bool)` reverts on return-decode but the
  trace shows it returned, the deployed ABI may return nothing — drop the return type in your
  interface.
- 0x v3 `LibOrder.Order` must be declared with all 14 fields in order so the selector resolves;
  pass empty `Order[][]` for no-swap paths.

## Output

Write a `FINDINGS.md`: per finding give severity, root cause with code refs + deployed
addresses, the attack path, the PoC test name + its printed result, the realistic $ (with gas
math), and remediation. End with an overall verdict — including "nothing exploitable" when
that's the truth.
