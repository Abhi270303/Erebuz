# [M] LM Pool Loses Rewards Accrued During Zero-Liquidity Periods — Permanent Value Leak

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-LM-02 — rewardGrowthGlobalX128 is monotonically non-decreasing
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3LmPool` (`accumulateReward`)
- **Source:** verified (repo source)
- **Location:** `v3-lm-pool/contracts/FusionXV3LmPool.sol:L56-L78`

## Description

When `lmLiquidity == 0`, `accumulateReward()` returns without updating `rewardGrowthGlobalX128`. Time still passes and `lastRewardTimestamp` is advanced. Rewards that accrue during this zero-liquidity window are permanently lost — they cannot be recovered when liquidity returns because `lastRewardTimestamp` has already moved forward, skipping that period.

## Root cause

```solidity
// FusionXV3LmPool.sol:L56-L78
function accumulateReward(uint32 currTimestamp) external override onlyPoolOrMasterChef {
    if (currTimestamp <= lastRewardTimestamp) {
        return;
    }
    if (lmLiquidity != 0) {
        // ... calculate rewardGrowth += duration * rewardPerSecond / lmLiquidity
    }
    // else: lmLiquidity == 0 → rewardGrowthGlobalX128 NOT updated
    lastRewardTimestamp = currTimestamp;  // Timestamp advances even without accumulation
}
```

When `lmLiquidity == 0`, the period between `lastRewardTimestamp` and `currTimestamp` is skipped — no `rewardGrowthGlobalX128` is added, but `lastRewardTimestamp` jumps forward. When liquidity is later added, rewards only accrue from the new `currTimestamp`, missing the intermediate window entirely.

## Impact

- **Value leakage:** Any time the LM pool has zero staked liquidity, rewards stop accruing
- **Accumulation:** If the LM pool regularly has zero-liquidity periods (e.g., between farming seasons), the lost rewards are significant
- **Even brief windows cause loss:** A block-by-block reward rate means every second without liquidity burns rewards

## Attack path / preconditions

1. LM pool has staked liquidity (lmLiquidity > 0)
2. All LPs remove their tokens (lmLiquidity → 0)
3. Time passes — rewards flow from MasterChef but `rewardGrowthGlobalX128` doesn't increase
4. New LPs add liquidity (lmLiquidity > 0)
5. `accumulateReward()` starts from the new `currTimestamp`, skipping the intermediate period
6. The rewards that accrued during the zero-liquidity window are permanently unclaimable

## Proof of concept

`POC: pending` — fork test:
1. Stake a position in MC (creates LM pool with lmLiquidity > 0)
2. Remove all LPs from pool (lmLiquidity → 0)
3. Wait several blocks/minutes
4. Re-add liquidity
5. Harvest — verify rewards for the zero-liquidity period were lost

## Recommendation

When `lmLiquidity == 0`, do NOT advance `lastRewardTimestamp`:

```diff
function accumulateReward(uint32 currTimestamp) external override onlyPoolOrMasterChef {
    if (currTimestamp <= lastRewardTimestamp) {
        return;
    }
    if (lmLiquidity != 0) {
        rewardGrowthGlobalX128 += FullMath.mulDiv(...);
        lastRewardTimestamp = currTimestamp;
+   } else {
+       // Don't advance timestamp when no one is staked — rewards should accumulate
+       // for when liquidity returns (or return early without state change)
+       return;
    }
-   lastRewardTimestamp = currTimestamp;
}
```

Alternatively, track the unallocated rewards in a separate accumulator that can be distributed when liquidity returns.

## References

- **Forefy lens:** Lead F-06 (MEDIUM) — LM pool loses rewards during zero-liquidity periods
- **Invariant:** INV-LM-02 (monotonically non-decreasing rewardGrowthGlobalX128)
- This is a known PancakeSwap V3 LM pool design characteristic — the PancakeSwap reference has the same behavior
