# Erebuz

**Erebuz** is an autonomous, multi-agent smart contract security audit pipeline. It orchestrates a swarm of specialized AI agents that work in parallel to find vulnerabilities in deployed DeFi protocols, then converges their findings into validated, severity-ranked security reports with executable Foundry proof-of-concept tests.

The audit results in `audits/` are outputs produced by running this pipeline.

## Running

The [`docker-agent/`](docker-agent/) folder contains a self-contained Docker image with everything needed: opencode runtime, Foundry, MCP servers, and the full hunter swarm.

```bash
cd docker-agent
cp .env.example .env   # fill in your API keys
./build.sh
docker run --rm --env-file .env -v "$PWD/out:/work/audits" \
  defi-auditor:latest audit <target>
```

For detailed instructions — CLI one-shot, HTTP service, config, debugging, architecture — see [`docker-agent/DOCKER-AUDITING-AGENT.md`](docker-agent/DOCKER-AUDITING-AGENT.md). For the full pipeline spec see [`erebuz-context.md`](erebuz-context.md).

## Pipeline Overview

| Phase | Step |
|---|---|
| 0 | Workspace scaffold |
| 1 | Target discovery (DeFiLlama PRs) |
| 2 | Project research (docs, TVL, upgradeability) |
| 3 | Source acquisition (block explorers, proxy resolution, bytecode decompile) |
| 4 | Invariants & audited-vs-deployed diff |
| 5 | Bug hunting swarm (x-ray → 5 hunters in parallel → converge) |
| 6 | Solodit historical bug research |
| 7 | Finding document generation |
| 8 | Integration mapping & issue chaining |
| 9 | Foundry fork-test PoCs |
| 10 | Report assembly |

## Outputs from Past Runs

| Protocol | Chain | Severity | Findings | Status |
|---|---|---|---|---|
| [Agni Finance V3](audits/agni-finance/) | Mantle | 3 H, 5 M, 6 L, 4 I | 18 | Complete |
| [FanTech](audits/fan-tech/) | Mantle | 4 | 4 | Complete |
| [FusionX V3](audits/fusionx-v3/) | Mantle | 2 H, 14 M, 6 L, 2 I (+ 2 M, 3 L, 2 I off-chain) | 31 | Complete |
| [Lendle Pooled Markets](audits/lendle-pooled-markets/) | Mantle | 5 H, 3 M, 3 L | 11 | Complete |
| [Init Capital](audits/init-capital/) | — | — | — | Recon |
| [Merchant Moe](audits/merchant-moe/) | Mantle | 1 C, 1 H, 3 M, 2 L | 7 | Complete |
| [Treehouse Protocol](audits/treehouse-protocol/) | — | — | — | Recon |

### Severity Key
- **C** — Critical
- **H** — High (direct fund loss)
- **M** — Medium (broken logic/conditions)
- **L** — Low (best practice / informational)
- **I** — Informational

## Audit Directory Structure

```
audits/<protocol>/
├── recon.md              # Reconnaissance & scope
├── invariants.md         # Protocol invariants & properties
├── integration-map.md    # Dependency & integration mapping
├── audit-log.md          # Timeline & methodology log
├── issues/               # Individual finding reports
├── source/               # Audited source code (fetched from chain / repo)
├── pocs/                 # Foundry PoC exploit test suites
│   └── test/             # Forge test files (forge test -vvv)
├── research/             # Background research (docs, audits, repos)
└── agents/               # (gitignored) Auto-generated pipeline output
```

## Quickstart

```bash
forge build
forge test -vvv

# Run a specific audit's PoC
forge test --root audits/agni-finance/pocs -vvv
```

Requires [Foundry](https://book.getfoundry.sh/).

## Methodology

Each audit follows a multi-lens approach:

1. **Recon** — Scope definition, contract enumeration, privilege mapping
2. **Threat model** — Entry points, assets, trust boundaries, attack tree
3. **Parallel hunt** — 5 agents running independently (Pashov, Trail of Bits, Forefy, Solodit historical lens, invariant fuzzing)
4. **Convergence** — Lead deduplication, corroboration scoring, severity calibration
5. **PoC development** — Foundry fork-test reproduction of each exploit path
6. **Remediation** — Fix recommendations per finding

## Disclaimer

These audits were performed as independent security reviews. They do not constitute a formal audit or guarantee the absence of vulnerabilities. Always exercise caution when interacting with DeFi protocols.
