# [L] V3SwapRouter exactInputSingle/exactOutputSingle Lack Deadline Checks

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** INV-RTR-01 (indirect — slippage checks exist but deadline doesn't)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `V3SwapRouter` (`exactInputSingle`, `exactOutputSingle`)
- **Source:** verified (repo source)
- **Location:** `router/contracts/V3SwapRouter.sol:L97-L121`

## Description

`V3SwapRouter.exactInputSingle()` and `exactOutputSingle()` do not check a user-specified `deadline` parameter. While the multi-hop paths (`exactInput`/`exactOutput`) pass `deadline` via `MulticallExtended`, the single-hop variants lack this protection. Transactions pending in the mempool for extended periods could execute at unfavorable prices.

## Root cause

```solidity
// V3SwapRouter.sol:L97-L121 — no deadline check
function exactInputSingle(ExactInputSingleParams calldata params)
    external payable override nonReentrant
    returns (uint256 amountOut)
{
    // No checkDeadline modifier, no deadline parameter in params struct
    // Compare with MulticallExtended path which validates deadline
}
```

## Impact

- **Mempool timing risk:** A single-hop swap submitted when gas is low could wait in the mempool for blocks while market conditions change
- **Reduced protection:** Users relying on single-hop swaps (common for simple trades) lose deadline-based protection
- **Bound by slippage check:** The `amountOutMinimum` check still applies — deadline is an additional protection against timing-based MEV

## Proof of concept

No POC needed — code review finding.

## Recommendation

Add deadline validation to single-hop functions:

```diff
struct ExactInputSingleParams {
    // ... existing fields ...
+   uint256 deadline;
}

function exactInputSingle(ExactInputSingleParams calldata params)
    external payable override nonReentrant
+   checkDeadline(params.deadline)
    returns (uint256 amountOut)
{
    // ...
}
```

## References

- **Forefy lens:** Lead F-10 (LOW) — exactInputSingle lacks deadline
- **Historical:** Uniswap V3's own SwapRouter has the same issue — acknowledged design gap
