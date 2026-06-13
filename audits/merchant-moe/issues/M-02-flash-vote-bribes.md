# Medium Findings - Merchant Moe Liquidity Book

## MEDIUM [M-02]: Duplicate PID in `vote()` Enables Flash Vote+Unvote Bribe Extraction

**Severity:** MEDIUM (5.5/10)
**Impact:** Users can trigger bribe rewards without net voting contribution
**Status:** Confirmed (code analysis)

### Root Cause

`VeMoe.sol:333-348` — The `vote()` function does not check for duplicate pool IDs (`pids`):

```solidity
function vote(uint256[] calldata pids, int256[] calldata deltaAmounts) external override {
    uint256 length = pids.length;
    if (length != deltaAmounts.length) revert VeMoe__InvalidLength();
    ...
    for (uint256 i; i < length; ++i) {
        uint256 pid = pids[i];
        ...
        (bribes[i], poolVotes) = _vote(user, pid, deltaAmounts[i], userTotalVeMoe);
        ...
    }
    ...
    for (uint256 i; i < length; ++i) {
        uint256 rewardAmount = bribes[i].rewardAmount;
        if (rewardAmount > 0) bribes[i].bribe.claim(msg.sender, rewardAmount);
    }
}
```

A user can call `vote([X, X], [+N, -N])` to:
1. First iteration: vote +N for pool X → `bribe.onModify(user, 0, N, oldTotal)` returns reward R₁
2. Second iteration: vote -N for pool X → `bribe.onModify(user, N, 0, newTotal)` returns reward R₂

Both `bribe.claim()` calls execute in the claim loop at line 357. Net state: user votes = 0, pool votes = 0 change, bribes total votes = 0 change.

### Exploitability

Dependent on bribe contract implementation:
- **Time-weighted accrual** (same block, Δt ≈ 0): R₁ = R₂ = 0, no extraction
- **Per-vote payment at `onModify`** (naive design): User extracts bribes with zero net voting

### Affected Code

- `VeMoe.sol:310-361` — `vote()` function without duplicate PID guards

### Recommendation

Add a `require(!seen[pid])` check or use `EnumerableSet` to prevent duplicate PIDs in a single vote call:
```solidity
uint256[] memory seenPids = new uint256[](type(uint256).max);
for (uint256 i; i < length; ++i) {
    require(seenPids[pids[i]] == 0, "duplicate pid");
    seenPids[pids[i]] = 1;
    ...
}
```
