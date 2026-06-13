# Defi-Audits

A curated collection of independent smart contract security audits for DeFi protocols on EVM chains. Each audit includes a full recon, threat model, vulnerability findings with PoC exploit code, and fix recommendations.

## Audits

| Protocol | Chain | Severity | Findings | Status |
|---|---|---|---|---|
| [Agni Finance V3](audits/agni-finance/) | Mantle | 3 H, 3 M, 4 L, 2 I | 12 | Complete |
| [FanTech](audits/fan-tech/) | Mantle | 4 | 4 | Complete |
| [FusionX V3](audits/fusionx-v3/) | Mantle | 2 H, 14 M, 6 L, 2 I | 24 | Complete |
| [Lendle Pooled Markets](audits/lendle-pooled-markets/) | Mantle | 5 H, 3 M, 3 L | 11 | Complete |
| [Merchant Moe](audits/merchant-moe/) | Mantle | 1 C | 1 | In progress |

### Severity Key
- **H** — High (critical, direct fund loss)
- **M** — Medium (broken logic/conditions)
- **L** — Low (best practice / informational)
- **I** — Informational
- **C** — Critical (ongoing assessment)

## Structure

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

Root-level `test/` contains integration fork-tests for live protocols.

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
