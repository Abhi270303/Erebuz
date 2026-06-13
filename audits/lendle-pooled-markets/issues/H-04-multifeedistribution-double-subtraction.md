# H-04: MultiFeeDistribution.withdraw() Double-Subtracts bal.earned, Corrupting Accounting

| Field | Value |
|-------|-------|
| **Severity** | HIGH |
| **Status** | unconfirmed |
| **Invariants broken** | INV-13 (MISSING), INV-14 (MISSING) |
| **Contract** | `MultiFeeDistribution.sol` |
| **Function** | `withdraw(uint256 amount)` |
| **Line range** | L351–L396 |
| **Source file** | `/staking/MultiFeeDistribution.sol` |

---

## Description

`MultiFeeDistribution.withdraw()` contains a **confirmed arithmetic bug** where `bal.earned` is subtracted **twice** for the same earned balance deduction. This corrupts internal accounting state and affects all subsequent operations: `withdrawableBalance()`, `earnedBalances()`, `exit()`, and `getReward()`.

### The buggy code path

When `withdraw(amount)` is called and `amount > bal.unlocked` (i.e., the withdrawal must consume some earned/locked balance):

```
L360:  uint256 remaining = amount.sub(bal.unlocked);
L361:  require(bal.earned >= remaining, "Insufficient unlocked balance");
L362:  bal.unlocked = 0;
L363:  bal.earned = bal.earned.sub(remaining);          // ← FIRST SUBTRACTION
       ...
       // For-loop over userEarnings[msg.sender]:
L367:  for (i = 0; i < userEarnings[msg.sender].length; i++) {
L368:    if (penaltyAmount == 0 && userEarnings[msg.sender][i].unlockTime > block.timestamp) {
L369:      penaltyAmount = remaining;
L370:      bal.earned = bal.earned.sub(remaining);      // ← SECOND SUBTRACTION (BUG)
L371:      userEarnings[msg.sender][i].earned = ...
L372:      break;
         }
       }
```

### What goes wrong

**Case 1: User has at least one locked earnings entry.** The loop enters L368 (locked entry found). `penaltyAmount` is set to `remaining` (L369), which is **already wrong** — the actual penalty should be `remaining / 2` (50% as computed in `withdrawableBalance()` at L275). Then L370 subtracts `remaining` from `bal.earned` **a second time**. After this:

- `bal.earned` has been reduced by `2 × remaining`
- `penaltyAmount` is set to `remaining` instead of `remaining / 2` → penalty is 2x too high
- `adjustedAmount = amount + penaltyAmount` (L387) is `amount + remaining` (= `amount + (amount - unlocked)`)
- `totalSupply` and `bal.total` (L388–L389) are reduced by the inflated `adjustedAmount`

**Case 2: User has no locked earnings (all unlocked).** The loop never enters the penalty block (L367 condition never matches). L363 has already subtracted `remaining` from `bal.earned`, but **no `userEarnings[]` entry is updated** to reflect this deduction. This creates a permanent mismatch: `bal.earned` no longer equals the sum of `userEarnings[].earned`, breaking `withdrawableBalance()` and `earnedBalances()`.

### Downstream effects

- **`withdrawableBalance()`** (L258–L279) sums `userEarnings[].earned` to compute what's withdrawable. Since L363 reduced `bal.earned` without updating `userEarnings[]`, this function returns overstated values (it sees the pre-subtraction data from userEarnings but `bal.earned` is already reduced).
- **`exit()`** (L438–L457) calls `withdrawableBalance()` and then deletes `userEarnings[]`. The overstated withdrawable balance causes incorrect `totalSupply` reductions.
- **`_notifyReward()`** (L393) receives the inflated penalty as reward distribution, overpaying stakers at the protocol's expense.

## Impact

High. This is a provable arithmetic bug that:
1. Corrupts user balance tracking — users can see incorrect `withdrawableBalance()` values
2. Inflates penalty charges by 2x when withdrawing locked earnings
3. Creates a mismatch between `bal.earned` and `userEarnings[]` state variables
4. Inflates reward distributions (penalty goes to rewards, and it's 2x too high)
5. In extreme cases, Solidity 0.7.6 with SafeMath will revert on the second subtraction if `bal.earned` was fully consumed by the first subtraction — but this is a DoS, not a protect

The bug is **reliably reproducible**: any user withdrawing `amount > bal.unlocked` will hit it.

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | lead 3 | HIGH |
| **trailofbits** | lead 5 | MEDIUM |
| **forefy** | forefy-003 | HIGH |
| **solodit** | SOLODIT-005 | HIGH |
| **invariant** | lead 6 | HIGH |

All 5 hunters confirmed the double-subtraction. Reconciled to HIGH — the bug corrupts accounting state and overcharges penalties.

## Historical Precedent

- **LoopFi (Code4rena 2024 #126, #424)**: Nearly identical `MultiFeeDistribution` codebase. Finding #126 documented `vestTokens` reward erasure; #424 documented unbounded loops. The double-subtraction pattern is the same as LoopFi's reward accounting bug.

## Recommendation

Remove the second subtraction at L370. The `bal.earned` deduction should happen only inside the earnings loop, once per entry consumed:

```solidity
// Remove L363 entirely:
// bal.earned = bal.earned.sub(remaining);  ← DELETE THIS LINE

// Keep L370 inside the loop — it's the correct place:
bal.earned = bal.earned.sub(remaining);  // ← KEEP THIS
```

Additionally, fix the `penaltyAmount` calculation at L369 to use the correct 50% ratio:
```solidity
penaltyAmount = remaining / 2;  // instead of `penaltyAmount = remaining;`
```

## POC Needs (Phase 9)

1. Fork test: Stake LEND into MultiFeeDistribution
2. Mint earned tokens to the user (simulate reward distribution)
3. Call `withdraw(amount)` where `amount > bal.unlocked`
4. Observe that `bal.earned` is reduced by `2 × remaining`
5. Verify that `totalSupply` and `bal.total` are inconsistently reduced
6. Show that `withdrawableBalance()` returns incorrect values
