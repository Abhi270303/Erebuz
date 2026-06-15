#!/usr/bin/env bash
# build.sh — build the self-contained image.
#
# Skills, MCP servers, and the swarm agents are committed under docker/ and the
# Dockerfile COPYs them directly, so a build needs nothing from the host's
# ~/.claude. To refresh those bundled copies from your local ~/.claude/skills,
# run ./docker/prepare.sh first (optional).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
docker build -t "${IMAGE:-defi-auditor:latest}" "$HERE"
echo ">> Built ${IMAGE:-defi-auditor:latest}"
