# syntax=docker/dockerfile:1
#
# DeFi auditing agent — opencode runtime + Foundry + audit skill swarm.
# Self-contained: the build context is the docker/ directory, and the skills,
# MCP servers, and swarm agents are committed under it (skills/, mcp/, agents/).
# Builds on any machine with no dependency on the host's ~/.claude.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/root \
    PATH="/root/.foundry/bin:/root/.local/bin:${PATH}" \
    PIP_BREAK_SYSTEM_PACKAGES=1

# ---- System dependencies ---------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git bash jq unzip \
      python3 python3-pip python3-venv build-essential \
    && rm -rf /var/lib/apt/lists/*

# ---- Node.js 22 (opencode runtime + node-based MCPs) -----------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---- Foundry (forge / cast / anvil) ----------------------------------------
RUN curl -L https://foundry.paradigm.xyz | bash \
    && /root/.foundry/bin/foundryup

# ---- opencode CLI ----------------------------------------------------------
RUN npm install -g opencode-ai

# ---- HTTP API wrapper deps -------------------------------------------------
RUN pip3 install --no-cache-dir fastapi "uvicorn[standard]"

# ---- Audit skills (opencode auto-loads ~/.claude/skills) -------------------
# Each essential skill is bundled explicitly so the image is fully self-contained
# and builds on any machine (no dependency on the builder's ~/.claude).
# (Dockerfile syntax forbids inline comments after an instruction, so the lens
#  each skill provides is noted here instead.)
#   defi-audit-pipeline  = orchestrator (required)      solidity-auditor   = pashov lens
#   x-ray                = pre-audit threat model        smart-contract-audit = multi-expert/Forefy
#   solodit              = historical-vuln search        foundry-poc        = PoC generator
#   defi-fork-audit      = fork-test exploit PoCs        defi-data          = DefiLlama reference
COPY skills/defi-audit-pipeline/  /root/.claude/skills/defi-audit-pipeline/
COPY skills/solidity-auditor/     /root/.claude/skills/solidity-auditor/
COPY skills/x-ray/                /root/.claude/skills/x-ray/
COPY skills/smart-contract-audit/ /root/.claude/skills/smart-contract-audit/
COPY skills/solodit/              /root/.claude/skills/solodit/
COPY skills/foundry-poc/          /root/.claude/skills/foundry-poc/
COPY skills/defi-fork-audit/      /root/.claude/skills/defi-fork-audit/
COPY skills/defi-data/            /root/.claude/skills/defi-data/

# ---- Local MCP servers + subagent swarm ------------------------------------
COPY mcp/    /opt/audit/mcp/
COPY agents/ /opt/audit/agents/

# ---- opencode config (MCPs + allow-all permissions for headless) -----------
COPY opencode.json /root/.config/opencode/opencode.json

# ---- Entrypoint + HTTP server ----------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY server.py     /opt/audit/server.py
RUN chmod +x /usr/local/bin/entrypoint.sh

# Audit artifacts are written here; mount a volume to persist them.
WORKDIR /work
VOLUME ["/work/audits"]
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve"]
