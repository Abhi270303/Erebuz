# H-02: LM Pool External Calls During Swap Enable Reentrancy, DoS, and State Inconsistency

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** INV-08 (LM Pool reward accumulation only during swaps — violates if LM pool is malicious); INV-01 (Pool reserves always balance)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPool (`swap`)
- **Deployed address:** N/A (implementation contract)
- **Source:** verified
- **Location:** source/core/AgniPool.sol:L632-L634, L718-L720

## Description

`AgniPool.swap()` makes two external calls to the LM pool (`IAgniLmPool`) during the swap critical path with no reentrancy protection beyond the `slot0.unlocked` flag (which prevents re-entering only this specific pool, not other contracts), no try/catch error handling, and no return-value verification:

1. **Line 633**: `lmPool.accumulateReward(cache.blockTimestamp)` — called after `slot0.unlocked = false` but before swap execution completes. The pool is in a mid-swap inconsistent state.
2. **Line 719**: `lmPool.crossLmTick(step.tickNext, zeroForOne)` — called inside the swap loop **before** `ticks.cross()` (line 722) and **before** `state.sqrtPriceX96`/`tick` are finalized in storage (lines 754-762).

The LM pool implementation is an unaudited external dependency (only an interface is provided: `IAgniLmPool.sol`). The `setLmPool()` function is callable by the factory owner or the LM pool deployer, and the deployer address is settable by the owner at any time.

## Root cause

Three distinct issues at the same external call site:

1. **No reentrancy isolation**: The LM pool external calls execute with the pool in an inconsistent mid-swap state. While `slot0.unlocked` prevents re-entering the same pool, a malicious LM pool can re-enter other pools, interact with external DeFi protocols, or manipulate the swap context.

2. **No error handling**: Neither `accumulateReward()` nor `crossLmTick()` have try/catch guards. If the LM pool reverts for any reason (malicious, buggy, or gas griefed), all swaps on that pool are permanently DoS'd.

3. **Cross-tick ordering**: `crossLmTick()` is called on the LM pool before the core tick crossing logic completes, so the LM pool observes the old tick state, not the post-cross state — creating potential accounting inconsistencies.

## Impact

Three classes of impact depending on the LM pool implementation:

### Reentrancy (High)
A malicious or compromised LM pool can re-enter the AgniPool during `accumulateReward()` or `crossLmTick()` with the pool in mid-swap state, potentially:
- Manipulating price calculations
- Draining fees via manipulated accounting
- Exploiting unbalanced reserves for arbitrage

### Denial of Service (Medium)
If the LM pool reverts on either call, all swaps on the pool are permanently blocked. Since `lmPool.deployer` is a mutable role (settable by owner), this creates a censorship vector:
- LPs can still burn/collect (core positions are safe)
- Protocol fee collection still works
- But the pool becomes a ghost town — no swaps, no trading, no arbitrage

### State Inconsistency (Low)
`crossLmTick()` reads the pre-cross tick state, while the pool continues to update. If the LM pool implementation depends on accurate tick/oracle state, its observations will be inconsistent with the finalized AMM state.

## Attack path / preconditions

### Path A: Reentrancy
1. Factory owner (or LM pool deployer via `setLmPool`) sets a malicious LM pool on a target pool
2. A user calls `swap()` on the target pool
3. At line 633, `lmPool.accumulateReward()` executes malicious code that re-enters another pool or external protocol
4. The re-entered code observes the target pool in its inconsistent mid-swap state
5. Attacker exploits the inconsistent state for profit

### Path B: DoS
1. Owner or LM pool deployer sets a reverting LM pool on any pool
2. All subsequent `swap()` calls to that pool revert at line 633 or 719
3. The pool is effectively dead for trading (LPs can still exit via `burn()`)

## Proof of concept

`POC: pending`

**Needs:**
- Fork POC A: deploy a mock LM pool that re-enters `swap()` during `accumulateReward()`, verify the reentrancy
- Fork POC B: deploy a mock LM pool that reverts on `accumulateReward()`, set it via `setLmPool()`, call `swap()` and confirm revert

## Recommendation

### Primary fix: Isolate LM pool external calls
Move both LM pool calls to execute **after** swap state is fully finalized and balance checks pass, or implement a separate reentrancy guard for the LM pool call path:

```diff
- lmPool.accumulateReward(cache.blockTimestamp);
+ // Move to end of swap, after state finalization
```

### Secondary fix: Add try/catch guards
Wrap the LM pool calls to prevent DoS:

```diff
- lmPool.accumulateReward(cache.blockTimestamp);
+ if (address(lmPool) != address(0)) {
+     (bool success, ) = address(lmPool).call(
+         abi.encodeWithSelector(IAgniLmPool.accumulateReward.selector, cache.blockTimestamp)
+     );
+     // Emit event on failure instead of reverting
+     if (!success) emit LmPoolRewardFailed(cache.blockTimestamp);
+ }
```

### Tertiary fix: Fix tick crossing order
Move `lmPool.crossLmTick()` after `ticks.cross()` and state update, or at minimum document the ordering assumption.

## References

- **trailofbits** — "LM Pool accumulateReward() called mid-swap with reentrancy risk" (high)
- **trailofbits** — "LM pool external call path crosses tick before oracle observation is finalized" (medium)
- **forefy FORE-002** — "Malicious LM pool can permanently DoS all swaps on any pool" (M)
- **solodit solodit-002** — "LM pool external call during swap opens reentrancy vector before balance checks" (H)
- **invariant INV-08 lead** — "LM pool external calls during swap are not reentrancy-protected beyond unlocked flag" (medium)
