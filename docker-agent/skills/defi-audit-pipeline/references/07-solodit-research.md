# Phase 6 — Contextual research on Solodit

For every suspicious pattern, missing invariant, or behavioral delta, ask: "has this
exact bug class been found before, and does the same root cause live in this code?"
Solodit (`solodit.cyfrin.io`) is the aggregated memory of the audit industry — use it to
turn a hunch into a confirmed bug class and to enumerate the known pitfalls of this
protocol type. See `references/06-external-skills.md` for MCP install + auth.

## Two modes of use

### Mode A — Enumerate the bug classes for this protocol type (breadth, do early)
Before deep diving, pull the canonical issues for the category (lending, AMM, ERC4626
vault, staking, bridge, perps, stablecoin, NFT-fi):
1. `list_protocol_categories` / `list_tags` to get exact filter values.
2. `search_vulnerabilities` filtered by that category/tag, Impact = High/Medium.
3. Skim titles -> build a checklist of "known ways this protocol type dies." Fold any
   not-yet-covered item into `invariants.md` as something to verify.
Also consult the static checklist at `solodit.cyfrin.io/checklist`.

### Mode B — Match a specific suspicion (depth, do continuously)
When a specific pattern looks off (e.g. spot-price oracle, unguarded initializer,
fee-on-transfer handling, first-depositor inflation, reentrant withdraw):
1. `search_vulnerabilities` with precise keywords for the root cause + the relevant
   filters (Impact, Source firm, Forked-From if it is a known fork).
2. `get_finding` on the closest 1-3 hits; read the root cause, attack path, and fix.
3. **Map it onto the current code**: is the same precondition present here? Is the fix
   that the historical protocol applied present here, or absent? Absent fix on present
   precondition = strong finding.

## Search query craft

- Search by **root cause**, not symptom: "rounding direction shares deposit",
  "stale Chainlink answeredInRound", "delegatecall storage collision", "fee-on-transfer
  balance accounting", "first depositor inflation vault", "unchecked return transfer".
- Filter by **Forked-From** when the target is a fork (Uniswap v2/v3, Aave, Compound,
  Solmate, OZ) — forks inherit their parent's known bugs and often re-break the same
  things the fork-source later fixed.
- Filter by **Protocol Category** for type-specific classes; by **Source** to weight
  toward firms you trust; by **Impact** to focus on High/Medium first.
- Use `list_audit_firms` / `list_tags` / `list_languages` to get valid filter values
  rather than guessing.

## Recording what you find

In each affected `issues/` finding's References section, cite the Solodit finding(s) you
actually retrieved (title + URL/id + firm) and one line on why it applies here. Do not
cite a finding you did not open. If Solodit shows the bug class but the current code is
NOT vulnerable, note that too in `audit-log.md` — ruling things out is real coverage.

## Browser fallback (no MCP key)

Solodit's web UI supports the same filters (Keywords, Source, Impact, Author, Protocol
Name, Protocol Category, Forked-From, Report Tag). Use `crawling_exa` on result/finding
URLs to pull text. The methodology above is identical.

## Output of this phase

A per-protocol-type bug checklist folded into `invariants.md`, plus Solodit references
attached to the relevant `issues/` findings. Confirmed root-cause matches graduate the
finding from "suspicion" toward a POC in Phase 9.
