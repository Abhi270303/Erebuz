# Phase 4 — Invariants and the audited-vs-deployed diff

Two jobs, done together because they feed each other: (a) reconstruct what must always
be true about this protocol, and (b) find where the **deployed** code differs from what
was **audited** — unaudited deltas are where bugs hide.

## Part A — Audited-vs-deployed diff

Inputs: deployed source (Phase 3) + the audited commit (Phase 2 `research/audits.md` and
`research/repos.md`).

1. **Get the audited code at the audited commit.**
   ```bash
   git clone REPO_URL audited && cd audited && git checkout AUDITED_COMMIT
   ```
   If no commit is published, use the release/tag nearest the audit date and note the
   uncertainty.

2. **Normalize then diff** against the deployed implementation source. Compare logic,
   not formatting. Watch for: flattened vs multi-file, renamed files, inlined libs.
   ```bash
   diff -ruN audited/src/Contract.sol source/0xIMPL-Contract/Contract.sol
   ```

3. **Classify every delta** in `source/deployed-vs-audited.md`:
   - Identical -> audited, lower priority (still re-verify the audit's own findings were
     actually fixed — re-check each prior finding's location).
   - Cosmetic-only -> note and move on.
   - **Behavioral change post-audit** -> HIGH priority. New params, changed math,
     added/removed checks, new external calls, changed access control, new functions,
     compiler-version bump, constructor/initializer changes.
   - **Deployed but never audited** (contracts/facets with no audit coverage) -> HIGH
     priority. List them explicitly as out-of-audit-scope-yet-live.

4. **Confirm prior findings were fixed.** For each High/Medium in the prior report,
   locate the code today and verify the fix exists and is correct. "Fixed in report"
   often means "fixed differently / reintroduced."

## Part B — Reconstruct invariants

An invariant is a property that must hold across **all** states and callers. Bugs are
ways to violate invariants, so you cannot recognize a bug until the invariants are
written down. Build the list from three sources:

1. **Docs/whitepaper** (Phase 2 `research/docs.md`) — promises like "shares never lose
   backing", "only governance upgrades", "fees <= 10%".
2. **The code** — `require`/`revert` checks, modifiers, and `assert`s encode intended
   invariants; accounting variables imply conservation laws.
3. **The protocol type** — every category has canonical invariants. Pull the standard
   set for this type (lending, AMM/DEX, vault/ERC4626, staking, bridge, stablecoin,
   perps, NFT-fi). Solodit categories/tags (Phase 6) enumerate these.

### Common invariant families to instantiate
- **Solvency / conservation**: `sum(user balances) <= totalAssets`; protocol cannot pay
  out more than it holds; no value created from nothing.
- **Share/asset accounting (ERC4626)**: round in the protocol's favor; first-depositor
  inflation guarded; `convertToShares/Assets` monotonic; no donation attack.
- **Access control**: only `role` can call privileged fns; ownership transfer is
  two-step; init can run once; no missing `onlyX` on a state-changing fn.
- **Oracle / pricing**: price source is manipulation-resistant (TWAP, not spot;
  Chainlink staleness + `answeredInRound` checks); decimals handled.
- **Liquidation / health**: a position can always be liquidated when unhealthy; health
  factor math cannot be gamed; bad debt is socialized correctly.
- **Reentrancy / CEI**: state updated before external calls; cross-function and
  cross-contract reentrancy guarded; ERC777/ERC721 hooks considered.
- **Upgrade safety**: storage layout preserved across upgrades; `_authorizeUpgrade`
  guarded; initializer cannot be re-run; gap variables present.
- **Pausing / emergency**: pause actually blocks the value-moving paths; no withdraw
  bypass while paused.

### Write `invariants.md`
For each invariant record: ID, statement, where it is (or should be) enforced, how it
could break, and status:
- `enforced` — checked in code (cite file:line).
- `assumed` — relied on but not checked (suspicious).
- **`missing`** — the docs/type imply it but nothing enforces it. **Call these out
  explicitly**; missing invariants are frequently the finding itself.

```
INV-03  totalSupply of shares is fully backed by underlying held by the vault.
  enforced-by: none found — deposit() mints before pulling tokens (Vault.sol:142)
  breaks-if:   reentrant deposit / fee-on-transfer token / first-deposit inflation
  status:      MISSING -> candidate finding, see issues/, test in POC
```

## Output of this phase

`invariants.md` (with missing ones flagged) + a completed `source/deployed-vs-audited.md`
delta classification. The behavioral deltas and missing/assumed invariants are your
prioritized hunting list for Phase 5.
