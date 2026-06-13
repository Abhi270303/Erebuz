# Low Findings - Merchant Moe Liquidity Book

## LOW [L-02]: `VeMoe._vote` Reentrancy via `bribe.onModify` → `setBribes`

**Severity:** LOW (2.5/10)
**Impact:** Potential double-counting of bribes if a bribe contract re-enters `setBribes`
**Status:** Confirmed (code analysis)

### Root Cause

`VeMoe.sol:616-624` — The `_vote` function calls `bribe.onModify()` as an external call after updating `_bribesTotalVotes`. While the CEI pattern is partially followed (storage updated before external call), there is no reentrancy guard preventing a malicious bribe from calling `setBribes`:

```solidity
// VeMoe.sol:617-624
IVeMoeRewarder bribe = user.bribes[pid];

if (address(bribe) != address(0)) {
    uint256 totalVotes = _bribesTotalVotes[bribe][pid];
    _bribesTotalVotes[bribe][pid] = totalVotes.addDelta(deltaAmount);

    bribeReward = BribeReward({
        bribe: bribe,
        rewardAmount: bribe.onModify(msg.sender, pid, userOldVotes, userNewVotes, totalVotes)
        //              ^--- external call, can re-enter setBribes
    });
}
```

### Attack Chain

1. User calls `vote([X], [+N])` → `_vote` → `bribe_A.onModify(user, X, 0, N, oldTotal)` returns R₁
2. `bribe_A` (malicious) re-enters `setBribes([X], [bribe_B])`
3. `setBribes` transfers `userVotes=N` from `bribe_A` → `bribe_B`, calling both `onModify` + `claim` on each
4. Returns to outer `_vote`, returns R₁
5. Outer `vote()` claim loop calls `bribe_A.claim(user, R₁)` — user receives bribes from both A and B

### Mitigations

- Requires a malicious or whitelisted bribe contract (must pass `RewarderFactory` type check)
- Code comments at `VeMoe.sol:404,413` show developers were aware of similar vectors in `setBribes`

### Affected Code

- `VeMoe.sol:622` — `bribe.onModify(...)` external call inside `_vote` without reentrancy protection

### Recommendation

Add a `nonReentrant` modifier to `vote()` or add a reentrancy lock specific to the bribe callback path.
