# M-01 ZapV1 _zapOut() returns balanceOf instead of delta — donation griefing and residual token extraction

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** I-21 — ZapOut uses balanceOf after swap, manipulable
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalZapV1` (`_zapOut(address,address,uint256)`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalZapV1.sol:L692-L732` (final return at L731)

## Description

`_zapOut()` returns `IERC20(_tokenToReceive).balanceOf(address(this))` instead of computing the delta between pre-swap and post-swap balances. This has two independent exploitation vectors:

1. **Donation griefing:** A front-runner can donate `_tokenToReceive` to the Zap contract. The subsequent `zapOut` returns the inflated balance, giving the user unearned tokens. The attacker's donation is lost to the user.

2. **Residual extraction (higher impact):** Residual tokens accumulate in the Zap contract from:
   - Rebalancing zaps where the `addLiquidity` call (with 1/1 minima, see H-02) cannot deposit the full swap output at the pool's current ratio, leaving excess in the contract
   - Precision loss in rebalancing math (see M-04) leaving ~7 wei per operation
   - Any caller can trigger `zapOutToken(lpToken, residualToken, 1 wei, 0)` to drain the entire accumulated balance of that token

3. **Unsold token leakage:** If the intermediary swap does not consume all input tokens (e.g., due to fee-on-transfer mechanics or partial fill), the unused balance is also included in the output.

## Root cause

`TropicalZapV1.sol:_zapOut()`:
```solidity
tropicalRouter.swapExactTokensForTokens(swapAmountIn, _tokenAmountOutMin, path, address(this), block.timestamp);
// Return value (swapedAmounts) is DISCARDED
return IERC20(_tokenToReceive).balanceOf(address(this));
```

No pre/post balance tracking:
```solidity
// Missing:
// uint256 balanceBefore = IERC20(_tokenToReceive).balanceOf(address(this));
// swap...
// uint256 balanceAfter = IERC20(_tokenToReceive).balanceOf(address(this));
// return balanceAfter - balanceBefore;
```

## Impact

- **Direct value leak:** Residual tokens accumulated from normal protocol operation can be extracted by any user with minimal LP tokens (grows with protocol volume)
- **Donation vector:** Griefing attack where attacker loses donation but user gains (low direct protocol risk, but breaks accounting assumptions)
- **No swap output verification:** The function discards the swap's return value, making it impossible to verify the swap actually produced the expected output — the `_tokenAmountOutMin` check is bypassed in practice
- **Chain with M-04 + H-02:** Rebalancing precision losses (M-04) create residuals that 1/1 minima (H-02) cannot clean, and this finding lets any user drain them

## Attack path / preconditions

**Residual extraction (proof-of-value):**
1. Protocol operates normally — rebalancing zaps leave residual tokens in the Zap contract
2. Over time, residuals of valuable tokens accumulate
3. Attacker acquires 1 wei of any LP token whose pair includes the residual token
4. Call `zapOutToken(lpToken, residualToken, 1, 0)`
5. Zap contract burns the 1 wei LP, swaps one side, returns `balanceOf(residualToken)` — which includes all accumulated residuals
6. Attacker receives residuals far exceeding the value of 1 wei LP

**Donation griefing:**
1. Attacker observes a `zapOutToken` transaction in the mempool
2. Front-runs with a donation of `_tokenToReceive` to the Zap contract address
3. User's zapOut executes and returns the inflated balance
4. User receives more than expected (attacker loses donation, user gains)

## Proof of concept

```
POC: pending — Fork POC for residual extraction
```

**Test plan (residual extraction):**
1. Call `zapInTokenRebalancing` 10 times with imbalanced amounts on a thin pool
2. Verify residual tokens accumulate in Zap contract
3. Call `zapOutToken(lpToken, residualToken, 1 wei, 0)`
4. Verify all residual tokens transferred to caller

**Test plan (donation):**
1. Read `_zapOut()` pre-swap balance of `tokenToReceive`
2. Donate 1000 units to Zap contract
3. Execute `zapOutToken` 
4. Verify return amount includes the 1000 unit donation

## Recommendation

Replace the balanceOf return with delta tracking:

```diff
+ uint256 balanceBefore = IERC20(_tokenToReceive).balanceOf(address(this));
tropicalRouter.swapExactTokensForTokens(swapAmountIn, _tokenAmountOutMin, path, address(this), block.timestamp);
- return IERC20(_tokenToReceive).balanceOf(address(this));
+ uint256 balanceAfter = IERC20(_tokenToReceive).balanceOf(address(this));
+ require(balanceAfter >= balanceBefore, "negative output");
+ return balanceAfter - balanceBefore;
```

Also capture and validate the swap's return value:
```diff
- tropicalRouter.swapExactTokensForTokens(...);
+ uint256[] memory swapedAmounts = tropicalRouter.swapExactTokensForTokens(...);
+ require(swapedAmounts[1] >= _tokenAmountOutMin, "swap output below minimum");
```

## References

- forefy (forefy-002) — balanceOf without delta tracking — donation + unsold-token leakage (M)
- invariant (INV-001) — residual extraction via balanceOf, with 1 wei LP (H — re-assessed to M after merge)
- pashov (pashov-003) — donation attack via balanceOf (M)
- pashov (pashov-004) — swap return value ignored (M)
- solodit (SOL-004) — balanceOf instead of delta — donation manipulation (M)
- trailofbits (TB-01) — balanceOf instead of delta — donation/manipulation (H)
- Solodit ref: Venus Protocol $3.7M donation attack — same root cause (balanceOf vs delta) — https://olympixai.medium.com/venus-protocol-the-market-donation-attack-dfd8f117f92f
