# Containerizing the DeFi Audit Pipeline → a hostable, LLM-triggered auditing agent

This doc explains how to turn the **`defi-audit-pipeline` skill** into a single Docker
image you can run on any machine, triggered by an LLM, either as a one-shot CLI command
or as a long-running HTTP service.

A ready-to-build scaffold lives in [`docker/`](docker/). The short version:

```bash
cp .env.example .env && $EDITOR .env     # add API keys
./docker/build.sh                        # stage context + docker build
# one-shot:
docker run --rm --env-file .env -v "$PWD/out/audits:/work/audits" \
  defi-auditor:latest audit aave-v3
# or hosted:
docker compose -f docker/docker-compose.yml --env-file .env up --build
curl -XPOST localhost:8080/audit -H 'content-type: application/json' \
  -d '{"target":"ethereum:0xYourContract"}'
```

---

## 1. What "the skill" actually is (and why it isn't already a program)

`defi-audit-pipeline` is **not** a binary or a service. It's a bundle of
*instructions + helpers* that only does anything inside an agentic LLM harness. It lives
at `~/.claude/skills/defi-audit-pipeline/` and contains:

| Part | What it is |
| --- | --- |
| `SKILL.md` | The orchestrator prompt — the 9-phase whitehat workflow |
| `references/*.md` | Per-phase playbooks (source acquisition, invariants, swarm, PoCs…) |
| `agents/agent-*.md` | The hunter **swarm** — one subagent per audit lens (pashov, Trail of Bits, Forefy, Solodit, invariant) + a convergence agent |
| `scripts/*` | Real code the agent shells out to: `scaffold_project.py`, `fetch_source.sh`, `dispatch_agents.sh`, `merge_agent_reports.py` |
| `assets/*` | Finding template, severity rubric, lead schema |

It drives **external capabilities** that are *not* in the bundle and must be present in
the image or reachable over the network:

- **An LLM agent runtime** that reads skills and can call tools — here, **opencode**.
- **Foundry** (`forge`, `cast`, `anvil`) — source fetching, storage reads, fork PoCs.
- **MCP servers / APIs** — chainlist + DefiLlama (your local Python servers in
  `.opencode/`), plus optionally **Exa** (web research) and **Solodit** (historical bugs).
- **Companion skills** the pipeline orchestrates — `solidity-auditor`, `x-ray`,
  `smart-contract-audit`, `foundry-poc`, `solodit`.

So "dockerize the skill" really means: **bake the runtime + the skill + every tool it
shells out to into one image, feed secrets via env, and expose a trigger.**

---

## 2. Why opencode is the runtime

You already run this repo on opencode (`opencode.json` with the chainlist/defillama MCPs
and allow-all permissions). Three properties make it ideal for a container:

1. **It natively loads `.claude/skills`.** opencode discovers `SKILL.md` files from
   `.claude/skills/`, `~/.claude/skills/`, `.opencode/skills/`, and `.agents/skills/`,
   and exposes them through a native `skill` tool. Your skill works **unmodified** — just
   copy it to `~/.claude/skills/` in the image. (Toggle off with
   `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` if ever needed.)
2. **Headless by design.** `opencode run "<prompt>"` runs non-interactively, streams to
   stdout, and exits — and in non-interactive mode permissions are auto-approved. That's
   exactly what an unattended container wants.
3. **Built-in HTTP server.** `opencode serve` exposes an HTTP API (with optional
   `OPENCODE_SERVER_PASSWORD` basic auth), and `opencode run --attach <url>` can reuse it
   to avoid MCP cold-boot on every job.

> **The LLM "trigger"** is just the prompt we hand to `opencode run`: *"use the
> `defi-audit-pipeline` skill and audit `<target>`."* The model then reads the skill and
> autonomously executes the 9 phases, fanning out the hunter swarm via the `task` tool.

---

## 3. Architecture

```
                 ┌──────────────────────────── Docker image: defi-auditor ───────────────────────────┐
   trigger       │                                                                                    │
 ──────────────► │  entrypoint.sh                                                                     │
  CLI:  audit X  │    ├── audit <target> ──► opencode run "<prompt: use defi-audit-pipeline on X>"    │
  HTTP: POST     │    └── serve ──────────► server.py (FastAPI)  ──► opencode run (one subprocess/job)│
   /audit {X}    │                                  │                                                 │
                 │                                  ▼                                                 │
                 │                          opencode runtime                                          │
                 │             reads ~/.claude/skills/defi-audit-pipeline                              │
                 │             + companion skills, spawns the hunter swarm (task tool)                │
                 │                                  │                                                 │
                 │     ┌────────────┬───────────────┼───────────────┬───────────────┐                │
                 │     ▼            ▼               ▼               ▼               ▼                │
                 │  Foundry      Python         chainlist MCP   defillama MCP   Exa/Solodit          │
                 │ forge/cast/   scaffold/      (local py)      (local py)      (optional, net)      │
                 │   anvil       merge                                                                │
                 └─────────────────────────────────────┬──────────────────────────────────────────┘
                                                        ▼
                                       /work/audits/<slug>/  (mounted volume)
                                       REPORT.md · issues/ · pocs/ · agents/ · job.json
```

Everything is one image. The only things that cross the boundary: **secrets in**
(env vars), **reports out** (mounted volume), and **network egress** to RPCs / block
explorers / research APIs / the LLM provider.

---

## 4. What goes in the image

See [`docker/Dockerfile`](docker/Dockerfile). Layer by layer:

| Layer | Why |
| --- | --- |
| `debian:bookworm-slim` + `curl git bash jq python3 build-essential` | base + the scripts' shell/python needs |
| Node.js 22 | opencode runtime (and node-based MCPs like Solodit) |
| Foundry via `foundryup` | `forge`/`cast`/`anvil` for source fetch + fork PoCs |
| `npm i -g opencode-ai` | the agent runtime |
| `pip install fastapi uvicorn` | the HTTP trigger |
| `COPY skills/<each> → /root/.claude/skills/` | the pipeline + 7 companion skills, each bundled explicitly |
| `COPY mcp → /opt/audit/mcp` | your chainlist/defillama MCP servers |
| `COPY agents → /opt/audit/agents` | the hunter-swarm subagents (12) |
| `COPY opencode.json → /root/.config/opencode/` | MCP wiring + allow-all + `task`/`skill` perms |
| `COPY entrypoint.sh, server.py` | the two triggers |

### Self-contained by design

Docker can only `COPY` files **inside the build context**, and the skills originally
live in `~/.claude/skills` — outside this repo. Rather than vendor them at build time,
the essential skills, MCP servers, and swarm agents are **committed directly** under
`docker/skills/`, `docker/mcp/`, and `docker/agents/` (~2.8 MB total, no `node_modules`).
The Dockerfile COPYs each skill explicitly, so the image builds on **any machine** with
no dependency on the builder's `~/.claude`.

To re-sync those bundled copies after you edit a skill locally, run the optional
[`docker/prepare.sh`](docker/prepare.sh) (it rsyncs from `~/.claude/skills`, excluding
caches/`node_modules`).

---

## 5. Secrets & configuration

All config is env vars — copy [`.env.example`](.env.example) to `.env` and fill in.
Nothing secret is baked into the image.

| Var | Purpose | Required? |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` (or other provider key) | LLM access | **yes** |
| `OPENCODE_MODEL` | `provider/model`, e.g. `anthropic/claude-sonnet-4-6` — confirm with `opencode models` | recommended |
| `ETHERSCAN_API_KEY` | verified source via `cast`/block explorers (one multichain v2 key) | for on-chain targets |
| `ETH_RPC_URL` (+ per-chain `*_RPC_URL`) | Foundry fork PoCs; archive nodes recommended | for PoCs |
| `EXA_API_KEY` | web research MCP | optional |
| `SOLODIT_API_KEY` | historical-vuln MCP | optional |
| `AUDIT_API_TOKEN` | bearer token for the HTTP API (unset = open) | for hosted use |
| `OPENCODE_SERVER_PASSWORD` | only if you also expose `opencode serve` directly | optional |

The pipeline is explicitly designed to **degrade gracefully**: missing a key means that
lens is skipped with a note, not a crash.

---

## 6. Build

```bash
cp .env.example .env        # then edit in your keys
./docker/build.sh           # docker build -t defi-auditor:latest (skills already bundled)
```

First build is slow (Foundry + Node + npm). Subsequent builds are cached. The skills are
already committed in the context, so a build needs nothing from your `~/.claude`; run
`./docker/prepare.sh` only when you want to refresh them from a locally edited skill.

---

## 7. Run — CLI one-shot (cron / CI / ad-hoc)

```bash
docker run --rm \
  --env-file .env \
  -v "$PWD/out/audits:/work/audits" \
  defi-auditor:latest audit "ethereum:0xYourContractAddress"
```

`<target>` accepts a **protocol name**, `chain:address`, a bare address, a DefiLlama
slug, or a **GitHub / PR URL**. The agent writes everything under
`out/audits/<slug>/` and prints the path to `REPORT.md`. This composes naturally with
cron — e.g. nightly sweeps of your `deployed-unaudited-protocols.md` list.

Debug shells:

```bash
docker run --rm -it --env-file .env defi-auditor:latest raw run "list my available skills"
docker run --rm -it --env-file .env defi-auditor:latest bash
```

---

## 8. Run — HTTP service (hosted / webhook)

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
TOKEN=...   # = AUDIT_API_TOKEN
JOB=$(curl -s -XPOST localhost:8080/audit \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"target":"ethereum:0xYourContract"}' | jq -r .job_id)

curl -s localhost:8080/audit/$JOB -H "authorization: Bearer $TOKEN" | jq -r '.status, .report'
```

Each job runs `opencode run` in a background subprocess and streams to
`out/audits/<slug>/audit.log`; state is mirrored to `job.json`. See
[`docker/server.py`](docker/server.py).

> **Scaling note:** the current server runs jobs in-process. For real concurrency put a
> queue (Redis/RQ, Celery, or a cloud queue) in front and run N worker containers, or set
> `OPENCODE_SERVER_PASSWORD`, start `opencode serve` once, and have workers
> `opencode run --attach` it to keep MCPs warm.

---

## 9. Hosting options

- **Any Docker host / VM** — `docker compose up -d`. Put it behind Caddy/nginx with TLS;
  keep `AUDIT_API_TOKEN` set. Simplest.
- **Fly.io / Render / Railway** — point at `docker/Dockerfile`, set env vars as secrets,
  attach a volume at `/work/audits`. Give it real CPU/RAM (see below).
- **AWS ECS/Fargate / GCP Cloud Run** — works, but audits are **long-running** (minutes
  to hours) and Cloud Run's request timeout makes the **CLI-on-a-queue** pattern (SQS/Pub-
  Sub → Fargate task per job) a better fit than the synchronous HTTP server.
- **Kubernetes** — run the HTTP service as a Deployment + a `Job` per audit, or a worker
  Deployment pulling from a queue. Mount a PVC at `/work/audits`.

---

## 10. Security & safety

This is offensive tooling for **defensive** use. Treat the container accordingly:

- **Whitehat scope is enforced in the prompt** (fork/testnet PoCs only, never broadcast to
  live contracts). Keep that clause — it's load-bearing.
- **Egress allow-list.** The agent reaches the LLM provider, RPCs, block explorers, and
  research APIs. In hosted environments, restrict outbound network to those hosts so a
  prompt-injected page in fetched source can't exfiltrate or pivot.
- **Scope the keys.** Use a read-only block-explorer key and **non-custodial** RPCs. There
  is no reason for any wallet/private key to exist in this image — PoCs use anvil's funded
  test accounts on a fork.
- **Auth the HTTP API** (`AUDIT_API_TOKEN`) and never expose it unauthenticated.
- **Resource limits.** The parallel swarm + `forge` are CPU/RAM heavy; the compose file
  caps 4 CPU / 8 GB — tune per host. Set a wall-clock timeout per job.
- **Non-root** (hardening TODO): the scaffold runs as root for `foundryup` simplicity; add
  a non-root `USER` and writable `/work` for production.

---

## 11. Cost & model notes

A full audit fans out a multi-agent swarm and can burn a lot of tokens — budget per audit,
not per request. Levers: set `OPENCODE_MODEL` to a cheaper model for routine sweeps and a
stronger one for deep dives; cap iterations via opencode agent `steps`; and gate which
targets get the full swarm vs. a single-lens pass. Confirm the exact model id with
`opencode models` (ids change; `anthropic/claude-sonnet-4-6` in the compose file is only
an example).

---

## 12. Limitations & things to verify

- **opencode version drift.** Skill loading from `.claude/skills` and the headless `run` /
  `serve` commands are current as of writing, but opencode moves fast. The one thing to
  confirm on your version is the **subagent directory** name — recent docs use
  `.opencode/agents/` (plural); some versions used `.opencode/agent/`. The entrypoint
  copies the swarm into `.opencode/agents/`; if your version differs, adjust one path. As a
  fallback, the skill drives the swarm via the `task` tool and its own
  `dispatch_agents.sh`, so it still functions even if a few subagents aren't auto-registered.
- **Subagent frontmatter.** The swarm files are Claude-format (`description` + `tools`).
  opencode honors `description` and the (deprecated-but-supported) `tools` field; if a
  subagent misbehaves, add `mode: subagent` to its frontmatter.
- **Adding Exa & Solodit.** They're optional and not wired into the baked `opencode.json`.
  Add them as MCP entries (Exa as a remote MCP with `EXA_API_KEY`; Solodit via its node
  server) and the research/historical-vuln phases light up. Without them the pipeline still
  runs the on-chain and invariant lenses.
- **Determinism.** LLM audits are non-deterministic and **not a substitute for a human
  audit**. Treat output as triaged leads + reproducible PoCs to verify, not ground truth.

---

## 13. File manifest (added by this doc)

```
.env.example                     # secrets template
DOCKER-AUDITING-AGENT.md         # this doc
docker/
  Dockerfile                     # the image (COPYs each bundled skill explicitly)
  opencode.json                  # in-image runtime config (MCPs + permissions)
  entrypoint.sh                  # audit | serve | raw | <cmd> dispatch
  server.py                      # FastAPI HTTP trigger
  docker-compose.yml             # hosted service
  build.sh                       # docker build
  prepare.sh                     # OPTIONAL: re-sync bundled skills from ~/.claude/skills
  .dockerignore / .gitignore
  skills/                        # COMMITTED: defi-audit-pipeline + 7 companions
  mcp/                           # COMMITTED: mcp-chainlist.py, mcp-defillama.py
  agents/                        # COMMITTED: the 12 hunter-swarm subagents
```
