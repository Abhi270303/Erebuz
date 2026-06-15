# M-05 Fee-on-transfer token handling missing in Pair and Zap — permanent fund loss

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** I-18 — Fee-on-transfer: pair has no special handling (MISSING)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalPair`, `TropicalZapV1`
- **Deployed address:** TBD
- **Source:** source code (verified)
- **Location:** `TropicalPair.sol:L112-L133` (mint), `TropicalZapV1.sol:_zapIn()` ~L257

## Description

The protocol has **no handling for fee-on-transfer (FoT) tokens** — tokens that deduct a fee on every transfer. Three separate issues exist:

1. **Pair.mint() uses balanceOf delta:** The mint function computes `amount0 = balance0.sub(_reserve0)`. For an FoT token, the amount transferred (gross) exceeds the amount received (net), but the user pays the gross amount. The Pair credits the user for the **net** amount only — the fee is permanently lost.

2. **Pair.swap() uses balanceOf delta:** Same issue — swap amounts are computed from balance changes. The K-invariant check may fail because the expected balance (gross transfer) doesn't match the actual balance (net after fee deduction).

3. **Zap uses non-FoT swap function:** `_zapIn()` and `_zapInRebalancing()` call `swapExactTokensForTokens()` instead of `swapExactTokensForTokensSupportingFeeOnTransferTokens()`. If the token has a transfer fee, the pair receives fewer tokens than expected, causing the K invariant to fail (revert) or producing incorrect amounts.

## Root cause

`TropicalPair.sol:L114-L116`:
```solidity
uint balance0 = IERC20(token0).balanceOf(address(this));
uint amount0 = balance0.sub(_reserve0);  // No adjustment for transfer tax
```

`TropicalZapV1.sol:_zapIn()`:
```solidity
tropicalRouter.swapExactTokensForTokens(...)  // Standard function, not FoT-supporting variant
```

The Router has FoT-supporting functions (`swapExactTokensForTokensSupportingFeeOnTransferTokens`) but the Zap never uses them.

## Impact

- **Permanent fund loss:** When adding liquidity with an FoT token, the user pays the gross transfer amount (including fee) but receives LP tokens based on the net amount. The fee is permanently lost during the transfer.
- **Transaction revert:** If the K-invariant check fails due to the fee, the entire zap/swap reverts — user pays gas for nothing.
- **Accounting corruption:** Reserve tracking in the Pair becomes imprecise for FoT tokens over time.

## Attack path / preconditions

1. A TropicalSwap pair exists with a fee-on-transfer token (e.g., a token with 1% transfer tax)
2. User calls `addLiquidity()` or `zapInToken()` to deposit the FoT token
3. Pair receives net amount (minus fee), but user is charged gross
4. LP tokens minted based on net amount — fee amount is permanently lost
5. Alternatively, the K-check fails and the transaction reverts (user loses gas)

## Proof of concept

```
POC: pending — Deploy mock FoT token
```

**Test plan:**
1. Deploy a mock FoT token with 1% transfer fee
2. Create a pair with this token
3. Call `addLiquidity()` with 1000 FoT tokens
4. Measure Pair token balance before and after
5. Check LP tokens received — should be based on 990 (net after 1% fee), not 1000 (gross paid)

## Recommendation

1. **Document FoT incompatibility** clearly in the protocol docs — state that fee-on-transfer tokens are not supported
2. **Or add FoT detection** and use `swapExactTokensForTokensSupportingFeeOnTransferTokens` in Zap
3. **Or add a fee-on-transfer deduction check** in Pair's mint function to reject deposits where transfer fee > 0:

```solidity
// In Pair.mint():
uint balance0Before = IERC20(token0).balanceOf(address(this));
// ... transfer happens ...
uint balance0After = IERC20(token0).balanceOf(address(this));
uint amount0 = balance0After - balance0Before;
// Compare amount0 with the expected transfer amount
require(amount0 == /* expected */, "fee-on-transfer token not supported");
```

## References

- invariant (INV-006) — FoT tokens cause permanent fund loss in Pair mint/swap (M)
- trailofbits (TB-05) — FoT handling missing in Pair — reserve tracking corruption (M)
- solodit (SOL-005) — ZapV1 calls non-FoT swap function — incompatible with FoT tokens (M)
- Solodit ref: Common Uniswap V2 audit finding — https://dapp.org.uk/reports/uniswapv2.html (Router incompatible with fee-on-transfer tokens)
