# [M] Malicious LM Pool via Factory Owner setLmPool — Centralization Risk in Pool Swap Hot Path

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-POOL-11 — Only factory or factory owner may set LM pool
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3Factory` (`setLmPool`) / `FusionXV3Pool` (`swap`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3Pool.sol:L902-L905` (setLmPool), `L647-L649` and `L733-L735` (lmPool calls in swap)

## Description

`setLmPool()` on `FusionXV3Pool` (called via `FusionXV3Factory.setLmPool()` by the factory owner or LM pool deployer) can set an arbitrary contract as the LM pool. The LM pool address is called during every swap's hot path — `lmPool.accumulateReward()` and `lmPool.crossLmTick()`. A compromised factory owner can set a malicious LM pool that corrupts reward tracking, DoS swaps, or re-enters the pool.

Additionally, `setLmPool` on the pool itself lacks the `lock` modifier (compare with `setFeeProtocol` and `collectProtocol` which use `lock`), meaning it can be called during an active swap.

## Root cause

```solidity
// FusionXV3Pool.sol:L902-L905 — no lock modifier
function setLmPool(address _lmPool) external override onlyFactoryOrFactoryOwner {
    lmPool = IFusionXV3LmPool(_lmPool);
    emit SetLmPoolEvent(address(_lmPool));
}
```

The LM pool is called inside every swap:
```solidity
// L647-649 (during swap execution, after unlocked=false)
if (address(lmPool) != address(0)) {
    lmPool.accumulateReward(cache.blockTimestamp);
}

// L733-735 (during tick crossing)
if (address(lmPool) != address(0)) {
    lmPool.crossLmTick(step.tickNext, zeroForOne);
}
```

## Impact

- **Reward manipulation:** Malicious LM pool can return fabricated `rewardGrowthGlobalX128` values, causing MasterChef to over-allocate rewards to attacker positions
- **Swap DoS:** Malicious LM pool can revert on `crossLmTick`, blocking all swaps that cross the initialized tick
- **Reentrancy via LM pool:** Though the pool's `lock` prevents reentrant state mutation, a malicious LM pool can manipulate its own storage or call out to other contracts
- **Core functionality at risk:** Every swap calls the LM pool — this is a central point of failure

## Attack path / preconditions

- **Precondition:** Factory owner key is compromised OR LM pool deployer is malicious
- This is a **centralization risk finding**, not an unconditional exploit
- Severity reflects that the factory owner is currently a single address (per INV-FAC-04)

## Proof of concept

`POC: pending` — conceptual only (requires compromised owner):
1. Factory owner calls `factory.setLmPool(poolAddress, maliciousContract)`
2. Any swap on that pool triggers the malicious contract
3. The malicious contract reverts, DoS-ing the pool; or returns fake reward data

## Recommendation

1. Add `lock` modifier to `setLmPool()` on the pool:
```diff
- function setLmPool(address _lmPool) external override onlyFactoryOrFactoryOwner {
+ function setLmPool(address _lmPool) external override onlyFactoryOrFactoryOwner lock {
```

2. Document that the factory owner must be a multi-sig with timelock
3. Consider adding an LM pool whitelist or immutability option (set-once)

## References

- **Pashov lens:** Lead #6 (MEDIUM) — setLmPool lacks lock modifier
- **Trail of Bits lens:** Lead #6 (MEDIUM) — swap calls lmPool within unlocked window
- **Solodit lens:** Lead SOL-003 (HIGH) — Factory owner can set arbitrary malicious LM pool
- **Historical:** PancakeSwap V3 PeckShield audit (2023-03) reviewed setLmPool authorization; acknowledged centralization risk
- **Invariant:** INV-POOL-11 (enforced — onlyFactoryOrFactoryOwner modifier)
