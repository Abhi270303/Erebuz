# [M] Upkeep Period Transition Can Create Incorrect Reward Rates — Extended Low-Reward Periods

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** None directly (reward distribution correctness)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`upkeep`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L734-L738`

## Description

When a new `upkeep()` is called before the previous period ends, the remaining undistributed fusionX is carried forward and the `fusionXPerSecond` is recalculated over the new duration. If the new duration is very large (up to `MAX_DURATION = 30 days`), the per-second reward rate could round down to near-zero, distributing rewards very slowly over an extended period.

## Root cause

```solidity
// LBPMasterChefV3.sol:L734-L738
if (latestPeriodEndTime > currentTime) {
    uint256 remainingFusionX = ((latestPeriodEndTime - currentTime) * latestPeriodFusionXPerSecond) / PRECISION;
    fusionXAmount += remainingFusionX;
}
// L739: fusionXPerSecond = (fusionXAmount * PRECISION) / duration;
```

When `duration` is large (up to 30 days = 2,592,000 seconds), the division `fusionXAmount * PRECISION / duration` can produce a very small `fusionXPerSecond`. Combined with `remainingFusionX` carried forward from a previous high-rate period, the effective reward rate drops sharply.

## Impact

- **Extended low-reward periods:** Users staking in MC earn rewards at a much lower rate than intended
- **No upper bound on duration impact:** If `duration` is set to `MAX_DURATION` and the carried-forward amount is small, the rate could be near-zero
- **Protocol economics:** An incorrect upkeep call (accidentally large duration) could take 30 days to correct

## Attack path / preconditions

1. Owner calls `upkeep()` with a short initial duration (e.g., 1 day) and large amount
2. Before the period ends, owner calls `upkeep()` again with a very long duration (e.g., 30 days)
3. The remaining undistributed fusionX from step 1 is carried forward
4. `fusionXPerSecond` is recalculated over the long duration, producing a near-zero rate
5. Users receive minimal rewards for the extended period

## Proof of concept

`POC: pending` — unit test:
1. Call upkeep(amount=1000e18, duration=1 day)
2. Halfway through, call upkeep(amount=1, duration=30 days)
3. Verify fusionXPerSecond is extremely low

## Recommendation

Add minimum reward rate validation:

```diff
function upkeep(uint256 amount, uint256 duration, bool withUpdate) external onlyReceiver {
    // ... existing validation ...
+   require(duration <= MAX_DURATION, "duration too long");
+   // Ensure minimum reward rate
+   uint256 newRate = (fusionXAmount * PRECISION) / duration;
+   require(newRate >= MIN_FUSIONX_PER_SECOND, "reward rate too low");
    // ... rest of function ...
}
```

Also consider not carrying forward remaining undistributed amounts, or capping the carry-forward proportion.

## References

- **Forefy lens:** Lead F-07 (MEDIUM) — Upkeep transition creates incorrect reward rates
- **Note:** Only the receiver can call `upkeep()` — this is owner-level but affects all stakers
