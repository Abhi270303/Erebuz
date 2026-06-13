# [L] IFO _claimPoints Uses msg.sender Instead of _user Parameter — Incorrect Internal Implementation

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (code quality — not exploitable in current code paths)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `IFOInitializableV3` (`_claimPoints`)
- **Source:** verified (repo source)
- **Location:** `ifo/contracts/IFOInitializableV3.sol:L462-L474`

## Description

Internal function `_claimPoints(address _user)` takes a `_user` parameter but uses `_userInfo[msg.sender]` at L466 instead of `_userInfo[_user]`. Currently only called from `harvestPool()` where `msg.sender == _user`, so functionally identical. However, the code is semantically incorrect and could break if the function were ever called from a different context.

## Root cause

```solidity
function _claimPoints(address _user) internal {
    if (!_hasClaimedPoints[_user]) {
        uint256 sumPools;
        for (uint8 i = 0; i < NUMBER_POOLS; i++) {
            sumPools = sumPools.add(_userInfo[msg.sender][i].amountPool); // BUG: should use _user
        }
        // ...
    }
}
```

## Impact

- **No exploit currently:** `_claimPoints` is only called from `harvestPool()` where `msg.sender == _user`
- **Future risk:** If a new function calls `_claimPoints(_otherUser)`, it would read the wrong user's data
- **Points system is already non-functional** (x-ray report: "zombie code" — `pancakeProfile` references commented out)

## Proof of concept

No POC needed — code review finding.

## Recommendation

Fix the parameter reference:

```diff
- sumPools = sumPools.add(_userInfo[msg.sender][i].amountPool);
+ sumPools = sumPools.add(_userInfo[_user][i].amountPool);
```

## References

- **Pashov lens:** Lead #9 (LOW) — _claimPoints uses msg.sender instead of _user parameter
- **x-ray report:** Noted as "Zombie code" — points system is non-functional
