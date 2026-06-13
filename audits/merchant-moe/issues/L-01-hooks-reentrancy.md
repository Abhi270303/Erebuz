# Low Findings - Merchant Moe Liquidity Book

## LOW [L-01]: Hooks `after*` Callbacks Outside Reentrancy Guard

**Severity:** LOW (3.0/10)
**Impact:** Hooks contract can re-enter the LB pair after state mutations complete
**Status:** Confirmed (code analysis)

### Root Cause

`LBPair.sol:578,632,688,757` — The `afterSwap`, `afterMint`, `afterBurn`, and `afterFlashLoan` hooks are all called **after** `_nonReentrantAfter()` releases the reentrancy guard. The `before*` hooks are correctly called inside the guard (after `_nonReentrantBefore()`).

```solidity
// swap() — LBPair.sol:576-578
_nonReentrantAfter();
Hooks.afterSwap(hooksParameters, msg.sender, to, swapForY_, amountsOut);

// mint() — LBPair.sol:686-688
_nonReentrantAfter();
Hooks.afterMint(hooksParameters, msg.sender, to, liquidityConfigs, amountsReceived.sub(amountsLeft));

// burn() — LBPair.sol:755-757
_nonReentrantAfter();
Hooks.afterBurn(hooksParameters, msg.sender, from_, to, ids, amountsToBurn);
```

### Attack Scenario

A hooks contract could re-enter `swap()`, `mint()`, or `burn()` during the `after*` callback with tokens from the just-completed operation, performing nested operations not expected by the caller.

### Mitigations

- Hooks are only set by the factory (`setHooksParameters` at line 846, `onlyFactory`)
- A malicious hooks contract requires factory compromise or a permissioned setup
- The `before*` hooks are correctly protected inside the reentrancy guard

### Affected Code

- `LBPair.sol:578` — `afterSwap` outside reentrancy guard
- `LBPair.sol:632` — `afterFlashLoan` outside reentrancy guard
- `LBPair.sol:688` — `afterMint` outside reentrancy guard
- `LBPair.sol:757` — `afterBurn` outside reentrancy guard

### Recommendation

Move `after*` hook calls **before** `_nonReentrantAfter()` but after all state updates, or add a separate reentrancy lock specific to hooks callbacks.
