# [L] massUpdatePools Unbounded Loop May Exceed Block Gas with Many Pools

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (future governance risk)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`massUpdatePools`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L750-L759`

## Description

`massUpdatePools()` loops from `pid = 1` to `poolLength`, calling `LMPool.accumulateReward()` for each pool with non-zero allocation. With enough pools (50+), this may exceed the block gas limit. Called from `upkeep()`, `add()`, and `set()` — all owner/operator-only functions. While currently bounded by owner control, it's a future governance risk if ownership becomes multi-sig or DAO.

## Root cause

```solidity
for (uint256 pid = 1; pid <= poolLength; pid++) {
    PoolInfo memory pool = poolInfo[pid];
    if (pool.allocPoint != 0) {
        // ...
        LMPool.accumulateReward(currentTime);  // Gas increases linearly with pool count
    }
}
```

## Impact

- **Gas griefing:** When `poolLength` exceeds the gas threshold, `massUpdatePools` (and thus `upkeep`) becomes impossible
- **Owner-only callers limit risk:** Currently `add()` is `onlyOwner`, so only the owner can increase pool count
- **Future risk:** If governance mechanisms add pools without gas awareness, core functions break

## Proof of concept

`POC: pending` — benchmark gas per pool iteration:
```solidity
// Test: measure gas used by accumulateReward per pool
// Estimate max pools before block gas limit (30M on Mantle)
```

## Recommendation

Add a maximum pool count check:
```diff
+ uint256 public constant MAX_POOLS = 50;
+ 
+ function add(uint256 allocPoint, address v3Pool, bool withUpdate) external onlyOwner {
+     require(poolLength < MAX_POOLS, "too many pools");
+     // ...
+ }
```

Also consider making `massUpdatePools()` paginated or range-bound.

## References

- **Forefy lens:** Lead F-08 (LOW) — massUpdatePools unbounded iteration
