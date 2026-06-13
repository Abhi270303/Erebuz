# H-03: Strategy Executor Can Call TreehouseAccounting.mark() Directly, Bypassing All PnL Guards

## Severity
**High** — Unlimited IAU minting leads to complete protocol drain.

## Files
- `TreehouseAccounting.sol:33-48` — `mark()` has `onlyOwnerOrExecutor` but NO deviation check
- `strategy/StrategyExecutor.sol:52-81` — executor can call `callExecute()` on strategies
- `periphery/PnlAccounting.sol:42-72` — `doAccounting()` has deviation check, but it's not the only path

## Description

`PnlAccounting.doAccounting()` applies a deviation check (max 2.5% per window) before calling `TreehouseAccounting.mark()`. However, the `TreehouseAccounting.mark()` function itself has NO deviation check — it only checks `onlyOwnerOrExecutor`.

The `TreehouseAccounting.executor` and `PnlAccounting.executor` are separate state variables in different contracts. The TreehouseAccounting executor can call `mark()` directly with any parameters.

This means:
1. The TreehouseAccounting executor can mint ANY amount of IAU in a single call
2. This inflates `IAU.balanceOf(TAsset)` arbitrarily
3. The tETH exchange rate (`totalAssets() / totalSupply()`) skyrockets
4. tETH holders (including the attacker) can redeem their shares for massive value
5. The Vault's wstETH is drained to pay for the inflated redemptions

The deviation guard in `PnlAccounting` is completely bypassed if `TreehouseAccounting.mark()` is called directly.
