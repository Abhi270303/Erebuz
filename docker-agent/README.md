# DeFi Auditing Agent — how to run

A self-contained Docker image that runs the `defi-audit-pipeline` skill on the
**opencode** runtime. Give it a target (protocol name, contract address, or GitHub/PR
URL) and it runs the whitehat audit end-to-end, writing a `REPORT.md` plus findings and
Foundry PoCs.

Two ways to trigger it:
- **CLI one-shot** — `docker run ... audit <target>` (great for cron / CI)
- **HTTP service** — `POST /audit` to a long-running container (great for hosting / webhooks)

> Architecture, design rationale, and security notes live in
> [`../DOCKER-AUDITING-AGENT.md`](../DOCKER-AUDITING-AGENT.md). This file is just how to run it.

---

## 1. Prerequisites

- **Docker** (Desktop or Engine) with the daemon running.
- An **LLM provider API key** (e.g. `ANTHROPIC_API_KEY`).
- For on-chain targets: an **`ETHERSCAN_API_KEY`** (one multichain v2 key) and at least
  one **RPC URL** (`ETH_RPC_URL`); an archive node is recommended for fork PoCs.

Everything the agent needs (the skills, MCP servers, swarm subagents, Foundry, opencode)
is **already inside the image** — nothing to install on the host beyond Docker.

---

## 2. Configure secrets

```bash
cd ..                       # repo root, where .env.example lives
cp .env.example .env
$EDITOR .env                # fill in ANTHROPIC_API_KEY, ETHERSCAN_API_KEY, ETH_RPC_URL, ...
```

Key vars (full list in `.env.example`):

| Var | Purpose | Required? |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | LLM access | **yes** |
| `OPENCODE_MODEL` | `provider/model` — confirm with `opencode models` | recommended |
| `ETHERSCAN_API_KEY` | verified source via `cast` | on-chain targets |
| `ETH_RPC_URL` (+ `*_RPC_URL`) | Foundry fork PoCs | for PoCs |
| `EXA_API_KEY`, `SOLODIT_API_KEY` | research / historical-vuln MCPs | optional |
| `AUDIT_API_TOKEN` | bearer token for the HTTP API | hosted use |

Nothing secret is baked into the image — keys are passed at run time.

---

## 3. Build

```bash
./docker/build.sh           # = docker build -t defi-auditor:latest ./docker
```

First build pulls Node + Foundry + npm deps and takes a few minutes; later builds are
cached. The skills are committed under `docker/skills/`, so the build needs nothing from
your `~/.claude`.

---

## 4. Run — CLI one-shot

```bash
docker run --rm \
  --env-file .env \
  -v "$PWD/out/audits:/work/audits" \
  defi-auditor:latest audit "ethereum:0xYourContractAddress"
```

- `<target>` accepts a **protocol name** (`aave-v3`), `chain:address`, a bare address,
  a **DefiLlama slug**, or a **GitHub / PR URL**.
- Output lands on the host in `./out/audits/<slug>/` — `REPORT.md`, `issues/`, `pocs/`,
  `audit.log`. The agent prints the path to `REPORT.md` on the last line.

Nightly sweep example (cron):

```bash
0 3 * * *  docker run --rm --env-file /srv/auditor/.env \
  -v /srv/auditor/out/audits:/work/audits \
  defi-auditor:latest audit "some-protocol" >> /var/log/auditor.log 2>&1
```

---

## 5. Run — HTTP service

```bash
docker compose -f docker/docker-compose.yml --env-file .env up --build   # API on :8080
```

| Method & path | Body | Returns |
| --- | --- | --- |
| `GET /healthz` | — | `{"ok": true}` |
| `POST /audit` | `{"target": "aave-v3"}` | `202 {job_id, slug, status}` |
| `GET /audit/{job_id}` | — | status; includes `report` (REPORT.md text) when done |
| `GET /audit` | — | all jobs, newest first |

```bash
TOKEN=...   # = AUDIT_API_TOKEN in .env (omit the header if you left it unset)

# kick off an audit
JOB=$(curl -s -XPOST localhost:8080/audit \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"target":"ethereum:0xYourContract"}' | jq -r .job_id)

# poll status / fetch the report
curl -s localhost:8080/audit/$JOB -H "authorization: Bearer $TOKEN" | jq -r '.status'
curl -s localhost:8080/audit/$JOB -H "authorization: Bearer $TOKEN" | jq -r '.report'
```

Reports also persist on disk in `./out/audits/<slug>/`. Stop with `docker compose down`.

---

## 6. Debugging

```bash
# interactive shell in the image
docker run --rm -it --env-file .env defi-auditor:latest bash

# drive the opencode CLI directly (e.g. confirm the skill loaded / pick a model)
docker run --rm -it --env-file .env defi-auditor:latest raw run "list my available skills"
docker run --rm -it --env-file .env defi-auditor:latest raw models

# follow a running HTTP job's live log
tail -f out/audits/<slug>/audit.log
```

---

## 7. Refresh the bundled skills (optional)

The skills are committed under `docker/skills/`. If you edit a skill in your local
`~/.claude/skills` and want the image to pick it up, re-sync then rebuild:

```bash
./docker/prepare.sh         # rsyncs ~/.claude/skills -> docker/skills (excludes caches)
./docker/build.sh
```

---

## 8. Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `No such model` / auth error | `OPENCODE_MODEL` id is wrong — run `... raw models` and copy an exact `provider/model`; check the provider key in `.env`. |
| Skill not used / "skill not found" | Confirm with `... raw run "list my available skills"`. Skills load from `/root/.claude/skills`; ensure the build COPYed them (it does by default). |
| `cast`/source fetch fails | Missing/blocked `ETHERSCAN_API_KEY`; the target chain isn't covered; or the contract is unverified (the pipeline falls back to bytecode). |
| Fork PoC fails to start | `ETH_RPC_URL` (or the chain's `*_RPC_URL`) missing or rate-limited; use an archive node. |
| Subagents don't fan out | opencode version uses `.opencode/agent/` (singular) instead of `.opencode/agents/`; the swarm still runs via the `task` tool. See the root doc §12. |
| Audit is slow / OOM-killed | It's a parallel swarm + `forge` — give it more CPU/RAM (compose caps 4 CPU / 8 GB; tune `deploy.resources`). |
| HTTP `401` | Send `Authorization: Bearer $AUDIT_API_TOKEN`, or unset `AUDIT_API_TOKEN` to disable auth. |

---

## 9. Safety

This is offensive tooling for **defensive** use only. The trigger prompt enforces whitehat
scope: PoCs run against **local forks / testnets only**, never broadcast to live contracts.
In hosted setups, restrict outbound network to your LLM provider + RPCs + explorers, keep
`AUDIT_API_TOKEN` set, and use read-only explorer keys. No wallet private keys belong in
this image.
