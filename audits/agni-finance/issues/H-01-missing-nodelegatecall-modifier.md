# H-01: Missing noDelegateCall Modifier Enables Delegatecall Storage Collision Attack

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** INV-01 (Pool reserves always balance — lock modifier bypass under delegatecall)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPool (all external functions)
- **Deployed address:** N/A (implementation contract)
- **Source:** verified
- **Location:** source/core/AgniPool.sol:L1-L891 (entire contract lacks NoDelegateCall)

## Description

AgniPool does not inherit the `NoDelegateCall` abstract contract, unlike the canonical Uniswap V3 which uses it on all external functions (`mint`, `burn`, `swap`, `flash`, `collect`, `setFeeProtocol`, `collectProtocol`, `setLmPool`). Without this protection, a malicious proxy contract that delegatecalls into AgniPool will use the proxy's own storage rather than the pool's, enabling the caller to bypass the `lock` modifier and manipulate pool state arbitrarily.

The comment at line 464 ("`noDelegateCall is applied indirectly via _modifyPosition`") is incorrect — no such protection exists anywhere in the contract. This omission was confirmed by all four audit agents independently.

## Root cause

AgniPool (source/core/AgniPool.sol) does not:

1. Import the `NoDelegateCall` abstract contract
2. Store `address(this)` at construction time as the "original" address
3. Include a `noDelegateCall` modifier on any external function
4. Perform `require(address(this) == original)` checks anywhere

The `lock` modifier (line 98-103) writes `slot0.unlocked` to the executing contract's storage — under `delegatecall`, this is the proxy's storage, not the pool's.

## Impact

An attacker can deploy a proxy contract with the same storage layout as `AgniPool`, set `slot0.unlocked = true` (bypassing the reentrancy guard), and delegatecall into `AgniPool` to:

- Execute swaps with attacker-controlled `sqrtPriceX96` and `tick` values
- Manipulate fee growth and protocol fee accounting
- Bypass the `onlyFactoryOrFactoryOwner` modifier by controlling the `factory` storage slot
- Corrupt tick/liquidity state for cross-contract attacks

If a user or periphery contract is tricked into interacting with the proxy (e.g., via address collision, bridge integration, or off-chain misdirection), funds can be stolen.

## Attack path / preconditions

1. Attacker deploys a proxy contract whose storage layout exactly matches `AgniPool.sol`'s `Slot0`, `poolFees`, `_liquidity`, etc.
2. Proxy sets `slot0.unlocked = true` and optionally sets `sqrtPriceX96`, `tick` to attacker-desired values
3. Proxy sets `factory` to an attacker-controlled address (bypassing `onlyFactoryOrFactoryOwner`)
4. Proxy delegatecalls `AgniPool.swap()` — the `lock` modifier reads proxy's `slot0.unlocked` (true → passes)
5. Swap executes using proxy-controlled price state, but `TransferHelper.safeTransfer` sends real pool tokens
6. Attacker drains funds from the real pool or manipulates external integrators

## Proof of concept

`POC: pending` — requires deploying a minimal proxy with matching storage layout and demonstrating the `lock` bypass.

**Needs:**
- Fork POC: deploy proxy with same storage layout as AgniPool, set `slot0.unlocked = true`, delegatecall `swap()`, verify lock bypass and state corruption

## Recommendation

Adopt the standard Uniswap V3 `NoDelegateCall` pattern:

```solidity
// Add to AgniPool.sol
import "./NoDelegateCall.sol";

contract AgniPool is IAgniPool, NoDelegateCall, ... {
    // ...
}
```

Then add the `noDelegateCall` modifier to all external functions: `mint`, `burn`, `swap`, `flash`, `collect`, `collectProtocol`, `setFeeProtocol`, `setLmPool`, `initialize`, and `increaseObservationCardinalityNext`.

```diff
- function swap(...) external override lock {
+ function swap(...) external override lock noDelegateCall {
```

## References

- **trailofbits** — "Missing noDelegateCall modifier allows delegatecall storage collision" (high)
- **forefy FORE-001** — "Missing noDelegateCall modifier enables delegatecall-based storage manipulation" (M)
- **solodit solodit-001** — "Missing noDelegateCall modifier exposes AgniPool to delegatecall attacks" (H)
- **invariant INV-01 lead** — "No noDelegateCall protection enables storage collision attacks on proxy contracts" (high)
- Solodit: Uniswap V3-core PR #327 — https://github.com/Uniswap/v3-core/pull/327 (original PR adding noDelegateCall)
- Solodit: Uniswap V3-core issue #523 — https://github.com/Uniswap/v3-core/issues/523 (discussion of why it exists)
