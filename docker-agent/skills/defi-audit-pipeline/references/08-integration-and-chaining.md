# Phase 8 — Integration mapping and finding chaining

The phase that turns a pile of lows into a high. After reviewing each Solidity file, map
how it connects to everything else, then deliberately combine findings to defeat an
invariant, access control, or a modifier. This is the auditor's top-level perspective —
step back from the single file and look at the system.

## Part A — Per-file dependency mapping

After auditing each file, append to `audits/PROJECT/integration-map.md`:

### Internal (file-to-file)
- Functions this contract **calls** on other in-scope contracts, and who calls **into**
  it. Note `delegatecall` (shared storage — collision risk) vs `call`/`staticcall`.
- Shared state: contracts that read/write the same storage, registries, or config.
- Trust edges: which contract trusts another's return values without validation.

### External (third-party integrations)
For every external dependency, record the assumption being made and how it can break:
- **Tokens**: ERC20 quirks — fee-on-transfer, rebasing, non-standard return, ERC777
  hooks, blocklists (USDC/USDT), >18 decimals, double-entrypoint.
- **Oracles**: Chainlink (staleness, `answeredInRound`, decimals, L2 sequencer uptime),
  TWAP vs spot, single-source.
- **Other protocols**: Uniswap/Curve pools, Aave/Compound, LayerZero/CCIP bridges,
  ERC4626 vaults — what does the integration assume about their behavior, fees, pausing,
  or upgradeability?
- **Infra**: keepers/relayers, governance/timelock, multisig — what can the privileged
  caller do, and what happens if it is malicious or compromised?

Build the call/trust graph (a simple text adjacency list is enough) so cross-contract
and cross-function paths are visible at a glance.

## Part B — Chain the findings

Re-read every `issues/` note, including `I`/`L`, with one question: **what does this let
me combine?** Concrete chaining patterns:

- **Small math/rounding edge + a loop or repeatable call** -> drain via repetition.
- **Missing access-control check on a setter + a function that trusts that value** ->
  attacker sets the value, then exploits the trusting function.
- **A view returning manipulable data (spot price, balance) + a function that acts on
  it** -> manipulate, then act (often inside one tx / flash loan).
- **Reentrancy entry point + an accounting update after an external call** -> re-enter
  to double-count or skip state changes (cross-function/cross-contract reentrancy too).
- **Initializer/upgrade gap + storage-collision in a proxy** -> hijack the proxy.
- **Two individually-bounded operations whose composition is unbounded** -> bypass a cap.
- **Fee-on-transfer/rebasing token + balance-based accounting** -> mint phantom shares.
- **Flash loan to satisfy a precondition cheaply** -> turn an "unrealistic precondition"
  low into a practical high.

For each chain, write/upgrade an `issues/` finding describing the **combined** attack
path end to end, the invariant it breaks (cite the INV id), and the realistic
precondition (who/what/when). Note the chain idea in `audit-log.md` first if not yet
proven.

## Part C — Iterate across the whole system

- Cover every contract, facet, and branch — track coverage in `audit-log.md`.
- Each time you learn something new, return to Phase 4 (does it reveal a new/missing
  invariant?) and re-scan earlier files with the new lens.
- Ask the system-level questions: can value leave without equivalent value entering? Can
  any single role move funds? What happens at pause/unpause, upgrade, migration, or
  extreme price? What does a flash loan make affordable?

## Output of this phase

A populated `integration-map.md` (internal + external dependency graph with assumptions)
and chained, higher-impact findings in `issues/` whose attack paths are end-to-end and
invariant-referenced. The strongest chains go to Phase 9 for a fork-test POC.
