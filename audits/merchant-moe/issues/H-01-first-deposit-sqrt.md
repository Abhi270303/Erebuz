# Critical Findings - Merchant Moe Liquidity Book

## HIGH [H-01]: First-Deposit `sqrt` in `getSharesAndEffectiveAmountsIn` Lacks MINIMUM_LIQUIDITY Burn

**Severity:** HIGH (7.5/10)
**Impact:** First depositor inflation attack on bin share price
**Status:** Confirmed (code analysis)

### Root Cause

`BinHelper.sol:84` — When a bin has zero total supply, shares are calculated as `sqrt(userLiquidity)`:

```solidity
function getSharesAndEffectiveAmountsIn(bytes32 binReserves, bytes32 amountsIn, uint256 price, uint256 totalSupply)
    internal pure returns (uint256 shares, bytes32 effectiveAmountsIn)
{
    ...
    if (binLiquidity == 0 || totalSupply == 0) return (userLiquidity.sqrt(), amountsIn);
    ...
}
```

There is no `MINIMUM_LIQUIDITY` burn (Uniswap V2 burns `10**3` LP tokens to the zero address to prevent this attack).

### Attack Scenario

A first depositor can deposit a minimal amount (e.g., 1 wei each of X and Y) to a new bin and receive `sqrt(userLiquidity(1,1,price))` shares. Due to the `sqrt` function scaling, the share price (reserves per share) is initially very high. When subsequent depositors add liquidity, their share calculation follows the proportional formula:

```solidity
shares = userLiquidity.mulDivRoundDown(totalSupply, binLiquidity);
```

If the first depositor or any third party directly sends tokens to the contract balance (unbalancing the ratio), `amountsReceived` on the next `mint()` includes those tokens, inflating the perceived deposit. The excess `amountsLeft` (tokens that cannot be deposited into bins due to ratio constraints) is **refunded to the minter** — meaning the donation is captured by whoever calls mint next.

### Key Limitation

The donation attack **backfires** on the first depositor: tokens donated directly to the pair's balance inflate `amountsReceived` but are refunded to the next caller of `mint()`, not the first depositor. The first depositor cannot profitably extract the donation.

### Missing `skim()` Function

Unlike Uniswap V2 (which provides a `skim(to)` function to sweep `balanceOf - reserve` excess to any address), the LBPair has no equivalent. There is no permissionless way to recover accidental token transfers to the pair contract except by calling `mint()` and receiving them as `amountsLeft` refunds.

### Affected Code

- `BinHelper.sol:84` — `return (userLiquidity.sqrt(), amountsIn)` on first deposit
- `LBPair.sol:671-675` — `amountsReceived` computed from `balanceOf - reserve`
- `LBPair.sol:684` — `amountsLeft.transfer(...)` refunds excess to minter

### Recommendations

1. Add a `MINIMUM_LIQUIDITY` burn (e.g., 10**3 shares to address(0)) on first bin deposit, matching Uniswap V2's defense
2. Add a `skim(address to)` function that lets anyone sweep `balanceOf - reserve` excess to a specified address
3. Consider whether the `sqrt` first-deposit formula is intentional — if so, document the economic assumptions
