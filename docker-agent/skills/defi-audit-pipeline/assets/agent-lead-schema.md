# Agent lead schema (fan-out output contract)

Every hunter agent in the swarm emits two artifacts into `audits/PROJECT/agents/`:

1. `AGENT-report.md` — human-readable narrative (what it looked at, reasoning, leads,
   coverage notes). For the auditor to read.
2. `AGENT.leads.jsonl` — one JSON object per line, one line per lead. This is the
   machine-readable feed that `scripts/merge_agent_reports.py` pre-clusters and that the
   converge agent turns into canonical `issues/`.

A **lead** is a candidate, not a finding. Agents produce leads; convergence + a human +
a POC produce findings. Keeping the two separate is what stops five agents from racing to
name `H-01` and lets convergence count corroboration.

## Why JSONL

Append-only, one self-contained record per line, trivially mergeable across agents, and
parseable without a real JSON-array close. An agent can append a lead the instant it finds
one without rewriting the file.

## Lead record fields

Every line is a JSON object. Required fields marked `*`.

| field | type | notes |
|-------|------|-------|
| `agent`*        | string | emitting agent id, e.g. `pashov`, `trailofbits`, `forefy`, `solodit`, `invariant`, `xray` |
| `lead_id`*      | string | unique within the agent: `AGENT-001`, `AGENT-002`, ... |
| `title`*        | string | impact-first, specific (no "the contract") |
| `bug_class`*    | string | normalized class, lowercase-kebab — the clustering key. See list below. |
| `contract`*     | string | contract/facet name as deployed |
| `function`      | string | `function` or `function(sig)`; `""` if file-level |
| `location`      | string | `path/to/File.sol:L120-L145` (verified) or `decompiled:slot/selector` |
| `severity_guess`* | string | `H` \| `M` \| `L` \| `I` \| `G` — provisional, per `assets/severity-rubric.md` |
| `confidence`*   | string | `high` \| `medium` \| `low` — agent's own confidence it is real |
| `invariant`     | string | INV id from `invariants.md` it would break, or `""` |
| `summary`*      | string | 1–3 sentences, the bug in plain words |
| `evidence`*     | string | the exact code/slot/tx the agent actually read. NEVER fabricate. |
| `precondition`  | string | what state/role/price/ordering the attack needs |
| `solodit_ref`   | string | Solodit id/url if matched (agent-solodit), else `""` |
| `needs`         | string | what would confirm/refute (e.g. "fork POC of re-entrant withdraw") |
| `dedupe_key`    | string | auto-derivable: `bug_class|contract|function` (the merge script recomputes this; agents may omit) |

### Example line
```json
{"agent":"pashov","lead_id":"pashov-003","title":"Re-entrant withdraw double-counts shares in Vault","bug_class":"reentrancy","contract":"Vault","function":"withdraw(uint256)","location":"src/Vault.sol:L210-L240","severity_guess":"H","confidence":"medium","invariant":"INV-04","summary":"withdraw() sends ETH before zeroing the share balance, so a malicious receiver can re-enter and withdraw twice against one balance.","evidence":"L228 calls (bool ok,)=msg.sender.call{value:amt}(\"\"); L235 sets shares[msg.sender]=0 AFTER the call.","precondition":"attacker holds shares and controls a contract as the withdrawer","solodit_ref":"","needs":"fork POC: deposit, re-enter in receive(), assert drained > deposited","dedupe_key":"reentrancy|Vault|withdraw(uint256)"}
```

## Canonical `bug_class` values (the clustering vocabulary)

Use these so different agents cluster onto the same row. If none fit, coin a kebab-case
class and note it in the report; convergence will reconcile.

`reentrancy` · `cross-function-reentrancy` · `read-only-reentrancy` ·
`access-control` · `missing-access-control` · `uninitialized-proxy` ·
`storage-collision` · `delegatecall` · `unchecked-return` ·
`oracle-staleness` · `oracle-manipulation` · `spot-price` · `twap` ·
`rounding` · `precision-loss` · `first-depositor-inflation` · `share-accounting` ·
`fee-on-transfer` · `rebasing-token` · `erc777-hook` · `erc20-nonstandard` ·
`integer-overflow` · `unbounded-loop` · `dos` · `gas-griefing` ·
`flash-loan` · `price-manipulation` · `mev-sandwich` · `frontrun` ·
`signature-replay` · `missing-deadline` · `slippage` ·
`liquidation` · `bad-debt` · `interest-accrual` · `collateral-valuation` ·
`bridge-validation` · `cross-chain-replay` ·
`init-frontrun` · `upgrade-gap` · `centralization` · `timelock-bypass` ·
`spec-deviation` · `missing-event` · `quality`

### Web / off-chain bug classes (the off-chain swarm)

Used by the off-chain hunters (`pentestswarm`, `cai`, `hexstrike`, `pentagi`,
`pentestgpt`) that audit the protocol's **web surface and off-chain code** — the dapp
frontend, APIs, RPC/subgraph endpoints, infra, and the repos behind them — rather than
the contracts. Same JSONL contract, OWASP-aligned vocabulary:

`broken-access-control` · `idor` · `auth-bypass` · `privilege-escalation` ·
`sqli` · `nosqli` · `command-injection` · `rce` · `ssti` · `xss` · `csrf` ·
`ssrf` · `open-redirect` · `xxe` · `path-traversal` ·
`api-bola` · `api-bfla` · `mass-assignment` · `graphql-introspection` · `rate-limit` ·
`cors-misconfig` · `security-headers` · `cookie-flags` · `session-fixation` ·
`secret-leak` · `exposed-config` · `exposed-git` · `source-map-leak` · `info-disclosure` ·
`subdomain-takeover` · `dns-misconfig` · `tls-misconfig` ·
`dependency-vuln` · `supply-chain` · `outdated-component` · `known-cve` ·
`wallet-drainer` · `frontend-tampering` · `clickjacking` · `dependency-confusion`

**Field mapping for off-chain leads** (so they still cluster on
`bug_class|contract|function`):
- `contract` → the off-chain asset: hostname / service / repo
  (`app.protocol.xyz`, `api.protocol.xyz`, `github.com/org/frontend`).
- `function` → the concrete locus: endpoint / route / param / file
  (`GET /api/v1/orders?id=`, `src/config.ts`).
- `location` → the full evidence locator: `https://app…/path?param=` or
  `frontend/src/api.ts:L42` or `main.<hash>.js:L1180` (a real, retrieved location).
- `invariant` → usually `""` (no on-chain INV); name the security property instead.
- `evidence` → the actual response/header/bundle line/repo line you retrieved. The
  same no-fabrication rule applies: a URL you did not fetch or a bundle line you did not
  read does not exist.

## Severity & evidence rules (inherited, non-negotiable)

- Severity is provisional (`severity_guess`) until convergence + POC. Use
  `assets/severity-rubric.md` (impact × likelihood).
- `evidence` must reference code the agent actually read (file:line / slot / selector /
  tx). **No invented addresses, line numbers, snippets, or Solodit ids.** If the agent
  could not read it, the lead does not exist.
- An agent that finds nothing in its lane emits an empty `.leads.jsonl` and says so in its
  report. That is a valid, useful result — silence is not failure, fabrication is.
