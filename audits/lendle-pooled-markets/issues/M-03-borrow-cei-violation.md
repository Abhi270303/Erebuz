# M-03: Borrow CEI Violation — State Changes Before External Transfer

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Status** | unconfirmed |
| **Invariant broken** | INV-02 (assumed — could be violated with non-standard tokens) |
| **Contract** | `LendingPool.sol` |
| **Function** | `_executeBorrow()` |
| **Line range** | L858–L920 |
| **Source file** | `/protocol/lendingpool/LendingPool.sol` |

---

## Description

In `_executeBorrow()`, the sequence of operations violates the Checks-Effects-Interactions (CEI) pattern:

```
L865:   updateAssetPrice(vars.asset)            ← Oracle state mutation
L869:   validateBorrow(...)                      ← Validation (Checks)
L884:   reserve.updateState()                    ← State mutation (Effects)
L892:   IVariableDebtToken(...).mint(...)        ← State mutation (Effects)
L905:   IAToken(...).burn(...)                   ← State mutation (Effects)
L911:   reserve.updateInterestRates(...)          ← State mutation (Effects)
L919:   IERC20(vars.asset).safeTransfer(...)     ← External call (Interactions)
```

**The problem**: The actual transfer of borrowed underlying tokens happens **last** (L919), after multiple state changes (minting debt tokens, burning aTokens, updating interest rates). If the `safeTransfer` call reverts (e.g., because the aToken doesn't have enough liquidity), the state changes have already been committed.

With standard ERC20 tokens, the transaction reverts and all state changes roll back. However:

1. **Fee-on-transfer tokens**: If the underlying asset is a fee-on-transfer token, the `safeTransfer` sends less than `amount` to the borrower. The pool's accounting records a full `amount` borrow, but the borrower only receives `amount - fee`. This breaks the protocol's accounting.

2. **Reentrancy via token hooks**: If the transferred token has callbacks (ERC777, ERC677), the receiver's `tokensReceived()` or `onTokenTransfer()` hook fires during `safeTransfer`. At this point, state has already been updated (debt minted, aTokens burned). The hook could read the post-borrow state and act on it.

3. **TTY (transfer to yourself)**: If the `onBehalfOf` and borrower are differnt and there's a reentrancy path in the token, the post-state before transfer could be exploited.

## Impact

Medium. For standard ERC20 tokens, this is a code-quality issue rather than an exploit. The transaction revert undoes all state changes. However:

- If any supported underlying asset is a **fee-on-transfer token**, this becomes an accounting error (the protocol records lending more than was actually lent)
- If the protocol ever integrates an **ERC777/ERC677** token, this becomes a HIGH-severity reentrancy vector
- The pattern is fragile and makes future changes risky

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **invariant** | lead 8 | MEDIUM |

Only 1 hunter flagged this directly.

## Recommendation

Move the `safeTransfer` to **before** the state changes:

```solidity
// 1. Validate first
validateBorrow(...);

// 2. Transfer first (interactions before effects for token transfers)
IERC20(vars.asset).safeTransfer(vars.user, vars.amount);

// 3. Then update state
reserve.updateState();
IVariableDebtToken(...).mint(...);
IAToken(...).burn(...);
reserve.updateInterestRates(...);
```

Alternatively, keep the current ordering but add a `require` that ensures the aToken's underlying balance is sufficient before making any state changes:

```solidity
uint256 balanceBefore = IERC20(vars.asset).balanceOf(address(aToken));
require(balanceBefore >= vars.amount, "Insufficient liquidity");
// ... proceed with state changes, then transfer
```
