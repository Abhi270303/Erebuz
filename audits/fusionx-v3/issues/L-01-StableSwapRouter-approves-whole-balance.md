# [L] StableSwapRouter _swap Approves Entire Contract Balance to External Swap Pool Each Hop

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (spec quality)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `StableSwapRouter` (`_swap`)
- **Source:** verified (repo source)
- **Location:** `router/contracts/StableSwapRouter.sol:L48-L61`

## Description

`_swap()` approves `IERC20(input).balanceOf(address(this))` to the stable swap contract, not just the required swap amount. If residual balance exists or the same token appears in multiple hops, the swap pool could consume more tokens than intended. Combined with a 0 min-out parameter in the internal call, the external pool has full discretion over how many tokens to consume.

## Root cause

```solidity
uint256 amountIn_ = IERC20(input).balanceOf(address(this));
TransferHelper.safeApprove(input, swapContract, amountIn_);
IStableSwap(swapContract).exchange(k, j, amountIn_, 0);  // min-out = 0
```

The approval is for the full contract balance, and `exchange()` is called with `0` as min-out.

## Impact

- **Funds at risk if swap pool is malicious:** If the stable swap pool address is manipulated (via `setStableSwap` by owner), the malicious pool could drain the router's token balance
- **Multiple hops:** If the same token appears in two consecutive hops, the second hop may consume the residual from the first
- **Bound by owner control:** `setStableSwap` is `onlyOwner` — this requires a compromised owner

## Proof of concept

`POC: pending` — design issue, no exploit without compromised owner

## Recommendation

Approve only the exact amount needed:

```diff
- uint256 amountIn_ = IERC20(input).balanceOf(address(this));
- TransferHelper.safeApprove(input, swapContract, amountIn_);
+ TransferHelper.safeApprove(input, swapContract, amountIn);
+ IStableSwap(swapContract).exchange(k, j, amountIn, amountOutMin);

function _swap(address[] memory path, uint256[] memory amounts) internal {
    for (uint256 i; i < path.length - 1; i++) {
        // ... use amounts[i] instead of balanceOf(this)
    }
}
```

## References

- **Pashov lens:** Lead #7 (LOW) — _swap approves entire contract balance
