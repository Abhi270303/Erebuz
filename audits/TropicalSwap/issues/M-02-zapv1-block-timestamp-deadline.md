# M-02 All Zap functions pass block.timestamp as Router deadline — no expiry protection

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** I-23 — ZapV1 deadline protection is ineffective
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalZapV1` (`_zapIn`, `_zapInRebalancing`, `_zapOut`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalZapV1.sol:L543, L562, L652, L667, L728` (all Router calls)

## Description

Every Router call from ZapV1 passes `block.timestamp` as the `deadline` parameter. The Router's `ensure(deadline)` modifier checks `require(deadline >= block.timestamp, 'TropicalRouter: EXPIRED')`. Since `deadline` is always set to the current `block.timestamp`, this require statement always passes — **deadline protection is entirely absent** for all zap operations.

This means:
- A validator/sequencer can hold a zap transaction for any number of blocks
- The transaction will execute at whatever future pool state exists
- Combined with H-02 (1/1 minima), the delay makes sandwich attacks trivial: a validator can wait for an unfavorable ratio, then execute

## Root cause

`TropicalZapV1.sol:_zapIn()`:
```solidity
tropicalRouter.swapExactTokensForTokens(
    swapAmountIn, _tokenAmountOutMin, path,
    address(this),
    block.timestamp  // ← always the current time, never expires
);
tropicalRouter.addLiquidity(
    path[0], path[1], ..., 1, 1,
    address(msg.sender),
    block.timestamp  // ← same issue
);
```

Router's `ensure` modifier:
```solidity
modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'TropicalRouter: EXPIRED');
    _;
}
```

## Impact

- **No transaction expiry:** Any Zap can execute at any future block at arbitrary pool conditions
- **MEV amplification:** Enables validators/MEV searchers to delay execution until pool conditions are maximally unfavorable for the user
- **Worsens H-02:** The 1/1 minima sandwich becomes fully unbounded in time — the attacker can wait for any pool ratio
- **Value leak:** Users cannot protect themselves even if they understand slippage, because the deadline parameter is ignored

## Attack path / preconditions

1. User submits `zapInToken(token, amount, lp, minOut)` with reasonable expected slippage
2. Validator/MEV builder sees the transaction and withholds it from a block
3. After several blocks, the pool ratio shifts (natural trading or manipulated)
4. Validator includes the transaction at the new, unfavorable ratio
5. Due to 1/1 minima (H-02), the addLiquidity accepts the worse ratio
6. User receives fewer LP tokens than expected

## Proof of concept

```
POC: pending — Simple verification
```

**Test plan:**
1. Call Router directly with `block.timestamp` as deadline
2. Confirm the `ensure(deadline)` modifier never reverts
3. Advance chain by 100 blocks
4. Call the same Router function with the original `block.timestamp` value (now past)
5. Confirm it reverts — proving the Zap pattern bypasses all deadline protection

## Recommendation

Accept a user-supplied `deadline` parameter in all external Zap entry points and forward it to Router calls. At minimum, accept a `deadline` in minutes from the current time:

```diff
- function zapInToken(address tokenToZap, uint256 amount, address lpToken, uint256 minOut) ... {
+ function zapInToken(address tokenToZap, uint256 amount, address lpToken, uint256 minOut, uint256 deadline) ... {
    ...
-   tropicalRouter.swapExactTokensForTokens(..., block.timestamp);
+   tropicalRouter.swapExactTokensForTokens(..., deadline);
-   tropicalRouter.addLiquidity(..., block.timestamp);
+   tropicalRouter.addLiquidity(..., deadline);
}
```

## References

- forefy (forefy-004) — ZapV1 passes block.timestamp as Router deadline (M)
- invariant (INV-002) — All Zap entry points pass block.timestamp (M)
- pashov (pashov-002) — All Zap functions pass block.timestamp (M)
- solodit (SOL-003) — ZapV1 uses block.timestamp as deadline (M)
- trailofbits (TB-03) — ZapV1 passes block.timestamp as deadline (H — re-assessed to M)
- Solodit ref: [Devoured by bots — missing deadline parameter enabled 100% MEV leakage](https://coinsbench.com/devoured-by-bots-how-a-missing-parameter-enabled-100-mev-leakage-in-a-defi-zap-contract-e5f9e835dad2)
