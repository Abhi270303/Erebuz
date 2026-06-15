# Phase 1 — Target discovery via DefiLlama pull requests

Goal: pick a fresh audit target and extract its on-chain contract addresses + chains
straight from the DefiLlama adapter that lists it. New protocols show up as PRs to
DefiLlama's adapter repos before/around the time they appear on the site, and the
adapter code itself contains the addresses you need.

## Where new protocols appear

| Repo | What it tracks | Addresses live in |
|------|----------------|-------------------|
| `DefiLlama/DefiLlama-Adapters` | TVL adapters (primary) | `projects/NAME/index.js` |
| `DefiLlama/dimension-adapters` | fees / volume / revenue | adapter file per protocol |
| `DefiLlama/yield-server` | yield/APY pools | `src/adaptors/NAME/` |
| `DefiLlama/defillama-server` | listing metadata | `defi/src/protocols/data2.ts` |

The TVL adapters repo is the main entry point. Browse open + recently-merged PRs:
`https://github.com/DefiLlama/DefiLlama-Adapters/pulls`

## Scanning PRs

Use the Exa MCP or `gh`/`git` if available. With the GitHub CLI:

```bash
# Recently updated PRs (newest first), title + author + branch
gh pr list --repo DefiLlama/DefiLlama-Adapters --state all --limit 40 \
  --json number,title,author,headRefName,updatedAt \
  --jq 'sort_by(.updatedAt) | reverse | .[] | "\(.number)\t\(.title)\t\(.author.login)"'

# Files a specific PR touches (find the projects/NAME/index.js it adds)
gh pr view 13555 --repo DefiLlama/DefiLlama-Adapters --json files \
  --jq '.files[].path'
```

No `gh`? Fetch the PR's `.diff` directly:
`https://github.com/DefiLlama/DefiLlama-Adapters/pull/PR_NUMBER.diff` — or use the Exa
MCP `crawling_exa` tool on the PR URL.

A new-protocol PR almost always adds one new directory `projects/NAME/` with an
`index.js`. That file is your seed.

## Extracting addresses + chains from the adapter

Adapter `index.js` files declare contracts and tracked tokens as constants and pass
them to DefiLlama helpers. Patterns to grep for:

- Hardcoded addresses: `0x` followed by 40 hex chars.
- Constants like `const MARKETPLACE_CONTRACT = "0x..."`, `VAULT`, `STAKING`, `FACTORY`.
- Chain keys in the exported object: `module.exports = { ethereum: {...}, arbitrum: {...} }`
  — the top-level keys are the chains.
- Helper calls that reveal what holds value: `sumTokensExport`, `sumTokens`,
  `sumERC20Exports`, `getLogs` (event-sourced pools), `staking(...)`, `ownTokens`.

```bash
# After locating the adapter file locally or from the diff:
grep -oE '0x[a-fA-F0-9]{40}' projects/NAME/index.js | sort -u
grep -oE '"(ethereum|arbitrum|optimism|base|polygon|bsc|avax|...)"' projects/NAME/index.js | sort -u
```

Real example: PR #13555 (BeraVote) lists its contract addresses inline in the adapter,
with the chain set in the exported config. Treat every distinct address as a node to
acquire source for in Phase 3, and record which chain each lives on.

## Validate the adapter (optional but informative)

If you have the repo checked out, DefiLlama adapters are runnable — running one shows
exactly which contracts/tokens it reads:

```bash
node test.js projects/NAME/index.js
```

## Resolve the protocol slug

Map the project to its canonical DefiLlama slug + metadata (chains, category, audits
link) via the public API:

```bash
curl -s https://api.llama.fi/protocols | jq '.[] | select(.name|test("NAME";"i")) | {name,slug,chains,category,audit_links,url}'
```

Use the DefiLlama REST API directly (free, no auth) — not the DefiLlama MCP. The full
endpoint reference (free vs pro base URLs, path mappings, all endpoint groups) is in
`references/11-defillama-api.md`. Other endpoints useful during recon:

```bash
# Historical TVL + per-chain/per-token breakdown for the resolved slug
curl -s https://api.llama.fi/protocol/SLUG | jq '{name,chains,currentChainTvls}'

# Current TVL only
curl -s https://api.llama.fi/tvl/SLUG

# Closest block to a timestamp (handy for pinning fork blocks in Phase 9)
curl -s https://api.llama.fi/block/ethereum/1700000000
```

## Output of this phase

Write `audits/PROJECT/recon.md` containing:
- Source PR number + URL, author, date.
- Every contract address with its chain and (if known) deploy block.
- The DefiLlama slug, category, and any `audit_links` from the API.
- Links the PR/adapter exposes: website, docs, repo.
- Open questions ("is 0xabc... a proxy?", "which chain is the vault on?").

These addresses + links feed Phase 2 (Exa research) and Phase 3 (source acquisition).
