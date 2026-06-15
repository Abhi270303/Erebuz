# Phase 5 (swarm) — Parallel agent bug hunt and convergence

Phase 5 is where the hunting happens. Instead of running each external skill by hand and
mentally merging the output, dispatch one **subagent per audit lens**, let them hunt the
same hot contracts **in parallel** in isolated contexts, then **converge** their leads
into one deduplicated, corroborated, severity-ranked set. Fan-out, then fan-in.

This is a map-reduce over the codebase: `agent-xray` scopes the work, five hunters map
over the hot set, `agent-converge` reduces. The agents live in `agents/`; their output
contract is `assets/agent-lead-schema.md`; the swarm overview is `agents/README.md`.

Read this whole file before dispatching. The agents only behave well if the orchestrator
(you) enforces same-scope, leads-not-findings, and union-not-vote.

## Preconditions

Do not start the swarm until:
- Phases 0–4 are done: workspace scaffolded, source acquired and de-proxied in `source/`,
  `deployed-vs-audited.md` classified, and **`invariants.md` written** (the hunters and
  the convergence step both key off it).
- The agents are installed as Claude Code subagents:
  ```bash
  bash scripts/dispatch_agents.sh --install        # agents/agent-*.md → .claude/agents/
  ```
- The external skills/MCPs are installed (see `references/06-external-skills.md`). Any
  hunter whose skill is missing falls back to manual methodology and says so — it never
  fabricates. `agent-invariant` has no external dependency and always runs.

## The agents (one lens each)

| agent | wraps | primary lens |
|-------|-------|--------------|
| `agent-xray`        | pashov `x-ray`            | pre-flight threat model, entry points, hot set |
| `agent-pashov`      | pashov `solidity-auditor` | broad multi-agent Solidity bug hunt |
| `agent-trailofbits` | ToB + Slither             | detectors, entry-points, spec-to-code, properties |
| `agent-forefy`      | Forefy skill              | multi-language + attacker-story flows + POC drafts |
| `agent-solodit`     | Solodit MCP               | historical bug-class matching onto deployed lines |
| `agent-invariant`   | none (manual)             | first-principles invariant-breaking (always on) |
| `agent-converge`    | none (merge/dedupe)       | fan-in → canonical `issues/` |

Each hunter writes `agents/<id>-report.md` (narrative) and `agents/<id>.leads.jsonl`
(machine-readable leads). `agent-xray` writes `agents/x-ray.md`. `agent-converge` writes
`agents/convergence.md` and the canonical `issues/` files.

## Dispatch order

### Step 1 — x-ray first, alone
Run `agent-xray` by itself. It produces `agents/x-ray.md`: codebase overview, threat
model, entry points, integrations, and a **ranked hot-contract list** (2–5 contracts:
most value, most privileged, most-changed since the audited commit). It also appends any
invariants it spots to `invariants.md`. Read `x-ray.md` — its hot list is the scope every
hunter below must use. Do not skip this; same-scope is what makes corroboration meaningful.

### Step 2 — five hunters in parallel
Dispatch all five hunters **at once**, one Task/subagent call each, every one pointed at
the **same** hot-contract set + `invariants.md` + `x-ray.md`:

```
agent-pashov      agent-trailofbits      agent-forefy      agent-solodit      agent-invariant
```

Each runs in its own isolated context, hunts its lens, and returns only a short summary;
its full output lands in `agents/<id>-report.md` + `agents/<id>.leads.jsonl`. Because
`agent-pashov`'s underlying `solidity-auditor` is non-deterministic, it may run 2–3× and
union its own results before writing.

`scripts/dispatch_agents.sh --plan PROJECT` prints the dispatch checklist and the exact
feed files to expect, and flags any hunter feed that is missing so you know the fan-out
completed before you converge.

### Step 3 — converge last
Once **all** hunters that are going to run have written their `.leads.jsonl`, run
`agent-converge`. First it merges:
```bash
python scripts/merge_agent_reports.py PROJECT
```
which reads every `agents/*.leads.jsonl` (ignoring `_`-prefixed working files), recomputes
each lead's `dedupe_key = bug_class|contract|function`, clusters shared keys, and writes
`agents/_merged.leads.jsonl` + `agents/_worktable.md` (clusters + coverage matrix,
pre-filled from `assets/convergence-worktable-template.md`). Then `agent-converge` applies
the convergence rules below.

## Convergence rules

The reduce step. `agent-converge` is the **only** agent allowed to write to `issues/`.

1. **Cluster & dedupe.** Collapse each `dedupe_key` cluster to one candidate. Record how
   many independent lenses raised it (the corroboration count). Merge near-duplicates the
   key missed (same root cause phrased two ways; one agent's `function` blank); split a
   cluster if two different bugs collided on one key.
2. **Union, not vote.** Keep single-agent leads. A bug only one lens caught is frequently
   the real one. Corroboration raises `confidence`; it never gates inclusion.
3. **Corroborate & set confidence.** Higher confidence when ≥2 lenses agree on the root
   cause, or one lens + a matching `solodit_ref`, or one lens + an invariant break you
   re-read. A lone low-confidence lead stays in, marked `unconfirmed`, with what would
   confirm it written into the finding's POC/needs section.
4. **Evidence survives or the finding dies.** Re-read the cited code before promoting.
   Drop only leads whose evidence does not survive that read; record drops in
   `convergence.md` — never silently delete, never carry a fabricated location forward.
5. **Normalize survivors.** Write each as `issues/SEVERITY-NN-slug.md` from
   `assets/finding-template.md`; assign severity from `assets/severity-rubric.md`
   (reconcile the hunters' `severity_guess`; your call wins, justified); set
   `Status: unconfirmed`; set `Invariant broken` from the lead's `invariant` field; in
   **References** list which agents raised it + any `solodit_ref`.
6. **Coverage matrix.** In `convergence.md`, rows = hunters that ran, columns = hot
   contracts, cell = leads raised (or `–`/`clean`/`not-run`). Call out thin coverage
   (contracts only one lens saw) and lenses that did not run + the bug class thereby
   under-covered (no Slither → detector gaps; no Solodit → weak historical matching).
7. **Route onward.** Chains → `audit-log.md` "Chaining ideas" for Phase 8; each High/Medium
   lead's `needs` → the finding's POC section for Phase 9.

The output is a ranked queue of documented-but-unproven findings, not a verdict. Phases
6–9 proceed exactly as before from the `issues/` files the swarm produced.

## claude.ai fallback (no parallel subagents)

On claude.ai there are no parallel Task subagents. Run the same lenses **sequentially** in
one context, in the same order (x-ray → the five hunters → converge), writing each agent's
`agents/<id>.leads.jsonl` as you finish it, then do the convergence inline. Same artifacts
and same rules; slower, with less context isolation, so summarize each lens tightly before
moving to the next to protect the context window.

## Graceful degradation

The swarm is designed to lose limbs and keep working. If only `agent-invariant` can run
(no external skills installed), that alone is a valid Phase 5 pass — `agent-converge` will
promote its leads and the coverage matrix will honestly show the single-lens gap. Install
more lenses (Phase 5 setup) to widen coverage; never paper over a missing lens with
invented findings.

## Output of this phase

- `agents/x-ray.md` — threat model + hot-contract scope.
- `agents/<id>-report.md` + `agents/<id>.leads.jsonl` — per-lens narratives and leads.
- `agents/_merged.leads.jsonl` + `agents/_worktable.md` — merged, clustered leads.
- `agents/convergence.md` — clusters, merge/drop decisions, coverage matrix, chains.
- `issues/SEVERITY-NN-slug.md` — the canonical findings, handed to Phase 6 (Solodit
  context), Phase 8 (chaining), and Phase 9 (POCs).
