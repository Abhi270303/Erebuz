# I-02 removeLiquidityETHSupportingFeeOnTransferTokens forwards balanceOf without actual amount

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** I-18 (related: FoT handling gap)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalRouter` (`removeLiquidityETHSupportingFeeOnTransferTokens`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalRouter.sol:L200`

## Description

`removeLiquidityETHSupportingFeeOnTransferTokens` forwards `IERC20(token).balanceOf(address(this))` to the user without returning or logging the actual token amount after fee-on-transfer deduction. The function returns only `amountETH`, not `amountToken`. The caller cannot distinguish between a high-fee token and a faulty swap.

## Root cause

```solidity
// Returns only amountETH
TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
```

## Impact

- Low — caller cannot verify the actual amount of tokens received from the withdrawal
- The FoT fee is not surfaced to the caller

## Recommendation

Return `amountToken` (the actual forwarded amount) as a second return value.

## References

- pashov (pashov-013) — FoT removeLiquidity forwards balanceOf without logging actual amount (L — re-assessed to I)
