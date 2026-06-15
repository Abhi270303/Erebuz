# I-03 Router _swapSupportingFeeOnTransferTokens uses balance-based input computation

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** none
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalRouter` (`_swapSupportingFeeOnTransferTokens`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalRouter.sol:L322-L338`

## Description

The FoT-supporting swap variant `_swapSupportingFeeOnTransferTokens` computes `amountInput` as `IERC20(input).balanceOf(address(pair)).sub(reserveInput)` rather than using the explicit transfer amount. If reserves are stale (and `sync()` was not called), this could compute incorrect swap amounts.

In practice, the Pair's `lock` ensures reserves are updated after each operation, so this is a theoretical concern. The standard Uniswap V2 Router uses the same pattern.

## Root cause

Standard Uniswap V2 pattern — balance-delta input computation.

## Impact

- Informational — theoretical edge case only
- Would require reserve desync which is prevented by the Pair's lock mechanism

## Reference

- trailofbits (TB-12) — Router FoT swap balance-based input (L — re-assessed to I)
