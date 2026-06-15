# H-02 ZapV1 hardcodes 1/1 minimum amounts on addLiquidity enabling full MEV sandwich extraction

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** I-14 — Output limits (amountOutMin) should enforce slippage protection
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalZapV1` (`_zapIn`, `_zapInRebalancing`, `_zapOut`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalZapV1.sol:L297-L302` (and `L664-L665`, `L677-L678`)

## Description

All internal Zap flows call `tropicalRouter.addLiquidity()` with hardcoded `amountAMin=1` and `amountBMin=1`. Combined with the `block.timestamp` deadline (see M-02) and the stale reserve snapshot taken at the start of `_zapIn()`, this provides **zero slippage protection** on the LP addition step. An MEV searcher can:

1. Front-run the zap to manipulate the pool ratio
2. The intermediary swap executes at the manipulated ratio
3. The addLiquidity accepts **any positive amount** of tokens — depositing at the attacker's favored ratio
4. Back-run to extract value, leaving the user with negligible LP tokens

Excess tokens that cannot be deposited at the manipulated ratio remain permanently stuck in the Zap contract (recoverable only by the owner).

## Root cause

`TropicalZapV1.sol:_zapIn()`:
```solidity
(, , lpTokenReceived) = tropicalRouter.addLiquidity(
    path[0], path[1],
    _tokenAmountIn - swapedAmounts[0],
    swapedAmounts[1],
    1,  // amountAMin — hardcoded minimum
    1,  // amountBMin — hardcoded minimum
    address(msg.sender),
    block.timestamp
);
```

The Router's `_addLiquidity()` uses these minima to compute the acceptable deposit ratio. Any ratio that results in at least 1 wei of each token is accepted. The stale reserve snapshot (read at `_zapIn()` L248, before swaps execute) compounds the issue — the swap computation is based on pre-manipulation reserves.

## Impact

- **Complete value extraction:** In a sandwich attack, the user can receive near-zero LP tokens while losing both input tokens
- **Permanent stuck funds:** Tokens that cannot be deposited at the final ratio remain in ZapV1 (owner-recoverable only)
- **Amplified by block.timestamp deadline (M-02):** Validators can delay execution indefinitely, making the sandwich trivial
- **Compounded by stale reserve snapshot:** The zap computes swap amounts based on outdated reserves, making the sandwich even more profitable

## Attack path / preconditions

1. User submits `zapInToken(tokenA, amount, lpToken, minOut)` to public mempool
2. MEV searcher front-runs:
   a. Flash loan to manipulate pool ratio (large swap before user's zap)
   b. User's zap executes — swapAmountIn computed from stale pre-manipulation reserves
   c. Intermediary swap executes at manipulated ratio
   d. `addLiquidity` accepts unfavorable ratio (1/1 minima) — user deposits at bad rate
   e. Back-run: extract value by reversing the pool manipulation
3. User receives far fewer LP tokens than fair value

## Proof of concept

```
POC: pending — Fork POC required
```

**Test plan:**
1. Create pool with 100 ETH / 100,000 USDC
2. Submit `zapInToken(USDC, 10_000e18, LP, 0)`
3. Front-run: swap 50 ETH → USDC to imbalance pool
4. Execute zap — measure LP tokens received
5. Back-run: swap USDC back to ETH
6. Compare LP received vs. fair LP at pre-manipulation ratio

## Recommendation

Accept user-specified `amountAmin`/`amountBMin` parameters in all external Zap entry points and forward them to the Router's `addLiquidity` call. Also read reserves immediately before the swap, not at entry.

```diff
- function zapInToken(address tokenToZap, uint256 amount, address lpToken, uint256 minOut) ... {
+ function zapInToken(address tokenToZap, uint256 amount, address lpToken, uint256 minOut, uint256 amountAMin, uint256 amountBMin) ... {
    ...
-   tropicalRouter.addLiquidity(..., 1, 1, ...);
+   tropicalRouter.addLiquidity(..., amountAMin, amountBMin, ...);
}
```

## References

- pashov (pashov-001) — Zap addLiquidity hardcodes 1/1 enabling sandwich (H)
- forefy (forefy-003) — Hardcoded 1/1 minimums in addLiquidity (M)
- invariant (INV-003) — 1/1 minimums + block.timestamp = no slippage protection (M)
- solodit (SOL-001) — Fixed 1/1 minimums allow sandwich attack (H)
- pashov (pashov-009) — Stale reserve snapshot for swap calculation (merged into this finding)
- Solodit ref: Common Uniswap V2 fork finding — multiple audits flag hardcoded 1/1 slippage as high severity
