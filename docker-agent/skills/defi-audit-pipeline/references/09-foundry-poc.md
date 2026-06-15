# Phase 9 — Prove it with Foundry fork-test POCs

A finding without a passing POC is a hypothesis. For each credible exploit chain, write a
Foundry test that forks **real mainnet state** at a recent block and demonstrates the
invariant violation against the actual deployed contracts. These POCs are the evidence in
your responsible-disclosure report — run them only against local forks/testnets.

Requires Foundry (`forge`) and an archive RPC for the target chain.

## Setup

```bash
forge init poc && cd poc
# In foundry.toml:
#   [rpc_endpoints]
#   mainnet = "${ETH_RPC_URL}"
#   [profile.default]
#   evm_version = "cancun"   # match the target's needs
```

Pin a fork block for determinism (e.g. one shortly after the contract's deploy or near
the bug's relevance). Put POCs in `audits/PROJECT/pocs/` and reference them from the
matching `issues/` finding.

## Fork test skeleton

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface ITarget {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

contract ExploitPOC is Test {
    // Deployed addresses from recon.md / source/ (the REAL implementation behind the proxy)
    ITarget constant TARGET = ITarget(0xDEPLOYED_PROXY_ADDRESS);
    address constant ASSET  = 0xUNDERLYING_TOKEN;
    address attacker = makeAddr("attacker");

    function setUp() public {
        // Fork real mainnet at a chosen block
        vm.createSelectFork(vm.rpcUrl("mainnet"), 21_000_000);
    }

    function test_breaks_INV03_solvency() public {
        // ---- Arrange: realistic starting state ----
        deal(ASSET, attacker, 1_000e18);          // fund attacker with the real token
        uint256 backingBefore = TARGET.totalAssets();

        // ---- Act: execute the chained attack path from the finding ----
        vm.startPrank(attacker);
        // ... reproduce the exact steps documented in issues/H-0X-*.md ...
        vm.stopPrank();

        // ---- Assert: the invariant is violated ----
        // e.g. attacker extracted more than they put in, or backing < shares
        uint256 profit = IERC20(ASSET).balanceOf(attacker) - 0; // net of input
        assertGt(profit, 0, "no profit -> not exploitable as written");
        console2.log("attacker net profit:", profit);
        // Or assert the protocol invariant directly:
        // assertLt(TARGET.totalAssets(), backingBefore, "solvency invariant INV-03 broken");
    }
}
```

Run:
```bash
forge test --match-test test_breaks_INV03_solvency -vvvv
```

## Cheatcodes you will reach for

- `vm.createSelectFork(rpc, block)` / `vm.rollFork(block)` — fork and move in time.
- `deal(token, to, amount)` — fund an account with any ERC20 (or ETH) without a whale.
- `vm.prank` / `vm.startPrank` — call as any address (impersonate users, owner, keeper).
- `vm.store` / `vm.load` — read/overwrite storage slots (use the proxy slots from
  Phase 3 to inspect implementation/admin, or to set up adversarial state).
- `vm.warp` / `vm.roll` — advance timestamp/blocks (oracle staleness, vesting, TWAP).
- `vm.expectRevert`, `vm.mockCall` — assert guards / simulate external responses.
- Flash-loan setup: if the chain needs cheap capital, either `deal` the funds or call a
  real Aave/Balancer/Uniswap flash-loan provider on the fork to prove realistic cost.

## What a good POC proves

1. **Realistic preconditions** — starting state matches what is actually on-chain (use
   forked balances/config, not invented ones). If you `deal` or `vm.store` to set up
   state, justify it as reachable.
2. **The documented attack path** — the test mirrors the numbered steps in the finding.
3. **The invariant break** — assert the exact violation: balance drained, `totalAssets <
   totalSupply` backing, access guard bypassed, position un-liquidatable, etc. Reference
   the INV id from `invariants.md`.
4. **Quantified impact** — log funds gained/lost and gas/capital cost, so severity is
   defensible.

## Unverified / decompiled targets

If the target is unverified, you may not have a clean interface. Use low-level calls with
raw selectors (`address(target).call(abi.encodeWithSelector(0x12345678, args))`) derived
in Phase 3, or interact via the proxy. Note in the finding that the POC is built against
decompiled selectors.

## Wire it back

In each proven `issues/` finding, replace `POC: pending` with the test name + file path,
and flip the finding status to `confirmed`. Unproven chains stay `unconfirmed` (often
valid `I`/`L`) — do not overstate severity without a passing test.

## Output of this phase

Passing fork tests in `audits/PROJECT/pocs/`, each tied to a finding and asserting a
named invariant break. With POCs attached, Phase 10 assembles the final report from the
`issues/` files for responsible disclosure to the protocol team.
