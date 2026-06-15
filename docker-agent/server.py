#!/usr/bin/env python3
"""HTTP front-end for the containerized DeFi auditing agent.

Endpoints
---------
  GET  /healthz            liveness probe
  POST /audit              {"target": "..."} -> {"job_id", "slug", "status"}
  GET  /audit/{job_id}     job status + (when done) the REPORT.md contents
  GET  /audit              list jobs

Each job shells out to `opencode run` (same prompt the CLI uses) in a
background task and streams logs to audits/<slug>/audit.log. Reports land in
audits/<slug>/REPORT.md, which is also persisted on the mounted volume.

Auth: if AUDIT_API_TOKEN is set, every request must send
`Authorization: Bearer <token>`.
"""
import asyncio
import json
import os
import re
import time
import uuid
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

AUDITS_ROOT = Path(os.environ.get("AUDITS_ROOT", "/work/audits"))
API_TOKEN = os.environ.get("AUDIT_API_TOKEN", "")
OPENCODE_MODEL = os.environ.get("OPENCODE_MODEL", "")

app = FastAPI(title="DeFi Auditing Agent", version="1.0")
JOBS: dict[str, dict] = {}


def slugify(target: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", target.lower()).strip("-")[:48]
    return s or "target"


def require_auth(authorization: str | None):
    if not API_TOKEN:
        return
    if authorization != f"Bearer {API_TOKEN}":
        raise HTTPException(status_code=401, detail="invalid or missing bearer token")


def build_prompt(target: str, slug: str) -> str:
    return (
        "You are a whitehat DeFi security auditor running fully autonomously and "
        "non-interactively. Use the `defi-audit-pipeline` skill and run it END TO END "
        f"against this target:\n\n    {target}\n\n"
        "The target may be a protocol name, a \"chain:address\" pair, a bare contract "
        "address, a DefiLlama slug, or a GitHub / pull-request URL. Resolve it, scaffold "
        f"the workspace under audits/{slug}/, acquire exactly the on-chain source (handle "
        "proxies/bytecode), reconstruct invariants, run the parallel hunter swarm, converge "
        "the leads, write per-finding files and Foundry fork-test PoCs where warranted, and "
        f"produce a final audits/{slug}/REPORT.md.\n\n"
        "Hard rules: whitehat scope only; PoCs run against local forks/testnets ONLY, never "
        "broadcast to live contracts; if an MCP/API key is missing, say so and continue; "
        "never invent addresses, source, findings, or Solodit hits. Print the absolute path "
        "to REPORT.md on the last line."
    )


async def run_job(job_id: str, target: str):
    job = JOBS[job_id]
    slug = job["slug"]
    work = AUDITS_ROOT / slug
    agents_dst = work / ".opencode" / "agents"
    agents_dst.mkdir(parents=True, exist_ok=True)
    # Make the hunter swarm discoverable to opencode's task tool.
    src = Path("/opt/audit/agents")
    if src.is_dir():
        for f in src.glob("*.md"):
            (agents_dst / f.name).write_bytes(f.read_bytes())

    cmd = ["opencode", "run"]
    if OPENCODE_MODEL:
        cmd += ["--model", OPENCODE_MODEL]
    cmd.append(build_prompt(target, slug))

    job.update(status="running", started_at=time.time())
    _persist(job)

    log_path = work / "audit.log"
    with open(log_path, "wb") as log:
        proc = await asyncio.create_subprocess_exec(
            *cmd, cwd="/work", stdout=log, stderr=asyncio.subprocess.STDOUT
        )
        job["pid"] = proc.pid
        rc = await proc.wait()

    report = work / "REPORT.md"
    job.update(
        status="completed" if rc == 0 else "failed",
        exit_code=rc,
        finished_at=time.time(),
        report_path=str(report) if report.exists() else None,
    )
    _persist(job)


def _persist(job: dict):
    work = AUDITS_ROOT / job["slug"]
    work.mkdir(parents=True, exist_ok=True)
    (work / "job.json").write_text(json.dumps(job, indent=2))


class AuditRequest(BaseModel):
    target: str


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.post("/audit")
async def create_audit(req: AuditRequest, authorization: str | None = Header(default=None)):
    require_auth(authorization)
    target = req.target.strip()
    if not target:
        raise HTTPException(status_code=400, detail="target is required")
    job_id = uuid.uuid4().hex[:12]
    job = {"job_id": job_id, "target": target, "slug": slugify(target),
           "status": "queued", "created_at": time.time()}
    JOBS[job_id] = job
    _persist(job)
    asyncio.create_task(run_job(job_id, target))
    return JSONResponse(status_code=202, content=job)


@app.get("/audit")
def list_audits(authorization: str | None = Header(default=None)):
    require_auth(authorization)
    return sorted(JOBS.values(), key=lambda j: j["created_at"], reverse=True)


@app.get("/audit/{job_id}")
def get_audit(job_id: str, authorization: str | None = Header(default=None)):
    require_auth(authorization)
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="unknown job_id")
    out = dict(job)
    rp = job.get("report_path")
    if rp and Path(rp).exists():
        out["report"] = Path(rp).read_text()
    return out


if __name__ == "__main__":
    import uvicorn
    AUDITS_ROOT.mkdir(parents=True, exist_ok=True)
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
