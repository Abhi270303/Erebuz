# Medium Findings - Merchant Moe Liquidity Book

## MEDIUM [M-01]: `VeMoe._getVeMoe` Cap Uses `oldBalance` Instead of `newBalance`

**Severity:** MEDIUM (5.0/10)
**Impact:** Users who stake incrementally receive permanently less veMoe than entitled
**Status:** Confirmed (code analysis)

### Root Cause

`VeMoe.sol:646` — When a user increases their staked MOE balance (`newBalance >= oldBalance`), the maximum veMoe cap is computed from `oldBalance` instead of `newBalance`:

```solidity
function _getVeMoe(User storage user, uint256 oldBalance, uint256 newBalance, uint256 userVested)
    private view returns (uint256 newVeMoe, int256 deltaVeMoe)
{
    uint256 oldVeMoe = user.veMoe;

    if (newBalance >= oldBalance) {
        newVeMoe = oldVeMoe + userVested;

        uint256 maxVeMoe = oldBalance * _maxVeMoePerMoe / Constants.PRECISION;
        //                  ^^^^^^^^^^ BUG: should be newBalance

        newVeMoe = newVeMoe > maxVeMoe ? maxVeMoe : newVeMoe;
    }
    ...
}
```

### Impact

| Step | Action | MOE Staked | veMoe Cap (actual) | veMoe Cap (expected) |
|------|--------|-----------|-------------------|---------------------|
| 1 | First stake | 100 | `0 * M` = 0 | — |
| 2 | Time passes, accrual | 100 | `100 * M` = cap | `100 * M` ✓ |
| 3 | Stake 900 more | 1000 | `100 * M` = cap (WRONG) | `1000 * M` |
| 4 | Call vote() (no balance change) | 1000 | `1000 * M` = cap (CAUGHT UP) | `1000 * M` ✓ |

Users who stake in multiple transactions lose the veMoe they would have accrued between steps 2 and 3. The cap self-corrects on the next `vote()` or `onModify()` call (where `oldBalance == newBalance`, so `maxVeMoe = newBalance * M`).

**Cannot be exploited to inflate veMoe** — the bug is strictly lossy for the user.

### Affected Code

- `VeMoe.sol:646` — `oldBalance` used instead of `newBalance` for max veMoe cap

### Recommendation

Change `oldBalance` to `newBalance` on line 646:
```solidity
uint256 maxVeMoe = newBalance * _maxVeMoePerMoe / Constants.PRECISION;
```
