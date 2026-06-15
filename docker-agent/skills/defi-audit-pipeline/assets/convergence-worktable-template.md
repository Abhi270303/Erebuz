# Convergence worktable (template)

`agent-converge` fills this in (helped by `scripts/merge_agent_reports.py`) and saves it
as `audits/PROJECT/agents/convergence.md`. It is the audit trail for how a pile of
overlapping leads became a ranked set of findings. Copy, then replace every `<...>`.

---

## Run summary

- Project: `<name>`
- Hunters that ran: `<pashov, trailofbits, forefy, solodit, invariant>`
- Hunters NOT run (skill/MCP missing): `<e.g. forefy — not installed>`
- Hot-contract set (from x-ray): `<Vault, Router, OracleAdapter>`
- Total leads ingested: `<N>` -> after dedupe: `<M>` candidate findings.

## Coverage matrix (be honest about gaps)

Rows = hunters; columns = hot contracts. Cell = # leads raised, or `clean` (looked, found
nothing), `–` (did not look), `n/r` (agent not run).

| agent \ contract | `<Vault>` | `<Router>` | `<OracleAdapter>` |
|------------------|-----------|------------|-------------------|
| pashov           |           |            |                   |
| trailofbits      |           |            |                   |
| forefy           |           |            |                   |
| solodit          |           |            |                   |
| invariant        |           |            |                   |

**Gaps called out:**
- `<OracleAdapter only seen by 1 lens — thin>`
- `<no Slither this run -> detector-class bugs under-covered>`

## Clusters (one row per dedupe_key)

`dedupe_key = bug_class|contract|function`. "Agents" = corroboration (recorded, never a
gate). "Decision" = promote / merge-into / split / drop (+ reason).

| dedupe_key | agents (corrob.) | max sev_guess | confidence | -> issue file | decision / reason |
|------------|------------------|---------------|-----------|---------------|-------------------|
| `reentrancy\|Vault\|withdraw(uint256)` | pashov, invariant (2) | H | high | `H-01-...md` | promote — two lenses, INV-04 break re-read |
| `rounding\|Vault\|deposit(uint256)`    | trailofbits (1)       | M | medium | `M-01-...md` | promote — single lens, mark unconfirmed |
| `<key>` |  |  |  |  | drop — cited L210 but deployed src ends L180 (fabricated loc) |

## Dropped leads (kept for the record, not deleted)

| agent | lead_id | why dropped |
|-------|---------|-------------|
| `<solodit>` | `<solodit-004>` | evidence did not survive re-read — no such modifier in deployed source |

## Promoted findings (the queue handed to the human)

Ranked. All `Status: unconfirmed` until a Phase 9 POC passes.

| issue file | severity | contract.fn | invariant | corroboration | POC needed (Phase 9) |
|------------|----------|-------------|-----------|---------------|----------------------|
| `H-01-...md` | High | `Vault.withdraw` | INV-04 | pashov+invariant | fork: re-enter, assert drained>deposited |

## Chain candidates (-> Phase 8, also appended to audit-log.md)

- `<I-02 (stale price tolerated) + L-03 (no slippage cap) -> INV-02 solvency break>`
- `<which findings combine, which invariant falls, rough attack sketch>`
