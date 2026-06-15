# Phase 7 — Documenting findings

Capture every observation the moment you have it, one finding per file, in the project's
`issues/` folder. Do not batch this for later — the informational note you skip is the
high-severity chain you forget. Run this phase continuously, in parallel with hunting.

## File-per-finding convention

Each finding is its own `.md` in `audits/PROJECT/issues/`, named:

```
SEVERITY-NN-short-slug.md
```

- `SEVERITY` prefix: `H` (high), `M` (medium), `L` (low), `I` (informational), `G` (gas).
- `NN`: zero-padded counter within that severity (`H-01`, `H-02`, `M-01`, ...).
- `slug`: kebab-case summary (`H-01-reentrancy-drains-vault-on-deposit.md`).

A finding's severity can change as you chain it (an `I` that enables an `H` becomes part
of the `H`). Renaming the file is fine; keep a one-line pointer in the old severity's
note if it helps you remember the link.

Copy `assets/finding-template.md` for each new finding. Use `assets/severity-rubric.md`
to assign severity.

## What every finding must contain

1. **Title** — impact-first, specific. "Vault" not "the contract".
2. **Severity** — H/M/L/I/G, with the impact x likelihood reasoning.
3. **Location** — exact `contract:function` and `file:line`; the deployed address; the
   chain. If decompiled, say so.
4. **Description** — the bug, in your own words. What invariant (from `invariants.md`)
   does it violate? Reference the INV id.
5. **Root cause** — the specific line/logic error, not just the symptom.
6. **Impact** — concrete: funds drained, accounting corrupted, DoS, governance hijack,
   who loses what and how much.
7. **Preconditions / attack path** — numbered steps an attacker takes; required state,
   roles, prices, ordering.
8. **Proof of concept** — link to the Foundry test in `pocs/` (Phase 9) once written;
   until then mark `POC: pending`.
9. **Recommendation** — the fix, ideally with a diff. Defensive deliverable.
10. **References** — Solodit findings (Phase 6) and prior audits with the same root
    cause; the exact URLs you retrieved.

## Evidence rules

- Every factual claim ties to code you read (file:line / storage slot / tx hash) or a
  source you actually retrieved. **Never invent** addresses, code snippets, line
  numbers, Solodit hits, or CVE-style references.
- "Looks wrong but unconfirmed" is a valid `I` finding — record it with status
  `unconfirmed` and what would confirm/refute it. Do not inflate it to `H` without proof.
- A finding is not `confirmed` until a passing POC (Phase 9) demonstrates it, unless it
  is a clear spec/quality issue that needs no exploit.

## The running audit log

Keep `audits/PROJECT/audit-log.md` as your top-level auditor's notebook (Phase 8/10):
- Coverage: which contracts/functions reviewed, which not yet.
- Open threads and hunches not yet findings.
- **Chaining ideas**: "L-02 + I-05 might break INV-03 — try in POC."
- Questions for the protocol team.

This log is what lets you put the auditor's hat back on after deep-diving one file and
see the cross-cutting exploit.

## Output of this phase

A growing `issues/` folder (one file per finding, correctly named and severity-tagged)
and an up-to-date `audit-log.md`. These files ARE the report — Phase 10 assembles them.
