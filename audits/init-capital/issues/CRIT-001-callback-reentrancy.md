# CRIT-001: `callback()` + `multicall()` Missing `nonReentrant` — Unbounded Reentrancy with Deferred Health Checks

**Severity:** CRITICAL
**Bug Class:** Reentrancy / Access Control
**Confidence:** HIGH (confirmed by all 4 agents: Pashov, Trail of Bits, Forefy, Solodit)

## Affected Contracts

| Contract | File | Lines |
|----------|------|-------|
| InitCore | `core/InitCore.sol` | 512–520 (`callback()`), 396–410 (`multicall()`) |
| Multicall | `common/Multicall.sol` | 12–27 (`multicall()` base) |

## Root Cause

`callback()` at `InitCore.sol:512` has **no `nonReentrant` modifier** — the only public state-changing function in InitCore without it. `multicall()` at `InitCore.sol:396` also has **no `nonReentrant` modifier**. Every other public state-changing function (`borrow`, `repay`, `mintTo`, `burnTo`, `liquidate`, `flash`, `collateralize`, `decollateralize`, `transferToken`, `createPos`, `setPosMode`) has `nonReentrant`.

```solidity
// InitCore.sol:512–520 — NO nonReentrant
function callback(address _to, uint _value, bytes memory _data)
    public payable virtual returns (bytes memory result)
{
    return ICallbackReceiver(_to).coreCallback{value: _value}(msg.sender, _data);
}

// InitCore.sol:396–410 — NO nonReentrant
function multicall(bytes[] calldata data) public payable virtual override returns (bytes[] memory results) {
    _require(!isMulticallTx, Errors.LOCKED_MULTICALL);
    isMulticallTx = true;
    results = super.multicall(data);
    // ... deferred health check loop ...
    isMulticallTx = false;
}
```

## How the Exploit Works

The exploit chains two missing reentrancy guards with the multicall deferred health mechanism:

**Step 1: Deferred health window.** When `multicall()` executes, it sets `isMulticallTx = true` (`InitCore.sol:398`). The `ensurePositionHealth` modifier (`InitCore.sol:68–72`) skips actual health checks during multicall, only queuing position IDs in `uncheckedPosIds`:

```solidity
modifier ensurePositionHealth(uint _posId) {
    if (isMulticallTx) uncheckedPosIds.add(_posId); // ← deferred!
    _;
    if (!isMulticallTx) _require(_isPosHealthy(_posId), Errors.POSITION_NOT_HEALTHY);
}
```

**Step 2: Callback reentrancy.** A multicall batch can include `callback()` as a sub-call. `callback()` calls the attacker's `coreCallback()` function. **Critically:**

- `multicall()` doesn't set the `ReentrancyGuard` lock (`_status` stays `_NOT_ENTERED`), so any `nonReentrant` function called from inside `coreCallback` passes the guard check.
- `isMulticallTx` is still `true` during the reentrant execution, so `ensurePositionHealth` on any nested call only queues the position — no actual health validation.

**Step 3: Value extraction.** From within `coreCallback`, the attacker calls `CORE.borrow()`, `CORE.decollateralize()`, or `CORE.liquidate()` directly. These normally-protected functions execute with:
- `nonReentrant` → PASSES (multicall never set the lock)
- `onlyAuthorized` → PASSES (attacker's position OR `liquidate()` has no `onlyAuthorized`)
- `ensurePositionHealth` → DEFERRED (isMulticallTx is true)

## Exploit Chain

```
1. Attacker calls core.multicall(data)
   ├── multicall() sets isMulticallTx = true                 (no nonReentrant — _status = _NOT_ENTERED)
   │
   ├── [sub-call 1] core.borrow(pool, amt, posA, exploit)
   │   ├── onlyAuthorized(posA)    ✓  (attacker owns posA)
   │   ├── ensurePositionHealth    →  adds posA to uncheckedPosIds  (DEFERRED)
   │   ├── nonReentrant            ✓  (_status is _NOT_ENTERED)
   │   └── sends `amt` tokens to exploit contract
   │
   ├── [sub-call 2] core.callback(exploit, 0, data)
   │   ├── (no nonReentrant)       ✓  (not guarded)
   │   └── exploit.coreCallback(sender, data) fires
   │       │
   │       └── [inside coreCallback] exploit calls:
   │           └── core.liquidate(victimPos, pool, shares, collPool, 0)
   │               ├── nonReentrant  ✓  (_status is _NOT_ENTERED)
   │               ├── _repay()     →  takes borrowed tokens from exploit contract
   │               │                   →   pays victim's debt
   │               └── removeCollateralTo() → sends victim's collateral (+ bonus) to exploit
   │
   ├── [sub-call 3] exploit transfers liquidated collateral → repays borrow
   │
   └── multicall() final health check
       └── _isPosHealthy(posA)  ✓  (debt repaid, position restored)
```

**Result:** The attacker repays the victim's debt using capital borrowed from their own position in the same atomic transaction, receives the victim's collateral plus the liquidation bonus, then repays their own debt — all within one multicall batch where every intermediate state is never validated. **Profit = liquidation incentive (typically 5%).**

## Impact

1. **Capital-free liquidations:** Any wallet with a healthy position can liquidate any unhealthy position using borrowed protocol funds, keeping the liquidation bonus. No external capital required.

2. **Cross-position manipulation:** An attacker can chain operations across multiple positions where individual health checks would revert but the aggregate end state passes.

3. **Oracle manipulation synergy:** If combined with DEX spot-price manipulation (via wLP `calculatePrice_e36`), the attacker can force favorable liquidation prices during the reentrant window.

4. **Bridge for other exploits:** The unprotected callback acts as a "force multiplier" — any vulnerability in hooks, oracles, or swap helpers becomes chainable through this reentrancy path.

## Proof of Concept

A Foundry fork-test PoC is at `audits/init-capital/pocs/CallbackReentrancy.t.sol`.

**To run:**
```bash
cd audits/init-capital/source/init-capital-contracts
export MANTLE_RPC="https://rpc.mantle.xyz"
forge test --match-contract CallbackReentrancyPoC -vvv
```

The PoC demonstrates:
- `test_ReentrancyProof()` — `callback()` successfully calls back into InitCore during a multicall batch
- `test_MulticallReentrancy()` — nested multicalls through callback are possible (proves no reentrant guard)
- `test_HealthCheckDeferred()` — health check deferral during multicall (structural)

## Mitigation

**Option A (Recommended):** Add `nonReentrant` to both `callback()` and `multicall()`.

```solidity
// InitCore.sol:512
function callback(address _to, uint _value, bytes memory _data)
    public payable virtual nonReentrant  // ← ADD THIS
    returns (bytes memory result)
{
    return ICallbackReceiver(_to).coreCallback{value: _value}(msg.sender, _data);
}

// InitCore.sol:396
function multicall(bytes[] calldata data)
    public payable virtual override nonReentrant  // ← ADD THIS
    returns (bytes[] memory results)
{
    // ...
}
```

**Option B:** Restrict `callback()` to only allow calls to whitelisted hook contracts (e.g., only the `MarginTradingHook` and `MoneyMarketHook` addresses). This prevents arbitrary contracts from receiving callbacks.

**Option C:** Snapshot `uncheckedPosIds` before each multicall sub-call and only validate those snapshot IDs, preventing re-entered operations from queuing deferred positions.

## Detection

**Slither:** Run `slither . --detect reentrancy-no-eth,arbitrary-send-eth,delegatecall-loop` on `core/InitCore.sol` and `common/Multicall.sol`. Slither flags `callback()` for `arbitrary-send-eth` and `multicall()` for `delegatecall-loop`.

**Manual review:** All functions in `InitCore` that modify state should have `nonReentrant`. The two missing cases (`callback`, `multicall`) are trivially identifiable by scanning for `function ... public` without `nonReentrant`.

## References

- Solodit checklist: `SOL-AM-ReentrancyAttack-1`, `SOL-AM-ReentrancyAttack-2`, `SOL-AM-ReentrancyAttack-3`
- Historical precedent: Flasko Vault M-2 (MixBytes), MakerDAO Endgame multicall reentrancy (Sherlock), Condo $9.9M reentrancy exploit
- InitCore.sol:L512–520 (code), L68–72 (ensurePositionHealth modifier), L396–410 (multicall)
