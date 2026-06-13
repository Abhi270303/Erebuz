# L-03: Swap Balance Check Uses ≤ Instead of == — Permits Donation-Based TWAP Oracle Manipulation

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** INV-01 (Pool reserves always balance — technically preserved, but donors can influence oracle)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPool (`swap`)
- **Deployed address:** N/A (implementation contract)
- **Source:** verified
- **Location:** source/core/AgniPool.sol:L793, L799

## Description

The balance check in `AgniPool.swap()` uses `<=` instead of `==` to verify that the pool received the correct token amounts from the caller:

```solidity
require(balance0Before.add(uint256(amount0)) <= balance0(), 'IIA');
require(balance1Before.add(uint256(amount1)) <= balance1(), 'IIA');
```

This allows callers to send more tokens than required by the swap. While the excess is effectively a donation to LPs (it gets added to fee growth via `_updatePosition`), it can be exploited in combination with flash loans to manipulate the TWAP oracle by creating artificial swap events at extreme prices.

This behavior is inherited from standard Uniswap V3 and is not a bug in the original — it is a known design trade-off.

## Root cause

Use of `<=` instead of `==` in the swap balance check allows token overpayment. The overflow is captured as fee accumulation rather than being returned to the caller.

## Impact

- **Low**: Theoretical TWAP oracle manipulation via donation
- Requires flash loans and significant capital
- Standard UniV3 has the same behavior — no reports of practical exploitation

## Attack path / preconditions

1. Attacker takes a flash loan of token0 and token1
2. Attacker calls `swap()` with an extreme `sqrtPriceLimitX96` value
3. Attacker sends more tokens than required by the swap (overpaying)
4. The excess tokens inflate fee growth, which affects the TWAP oracle observation
5. Attacker uses the manipulated oracle price in a downstream protocol (lending, perps, etc.)
6. Attacker profits from the price discrepancy before the oracle corrects

## Proof of concept

`POC: pending`

**Needs:**
- Fork POC: demonstrate that overpaying on a swap inflates fee growth and affects the TWAP oracle
- Assess whether the economic cost (donation amount) exceeds any potential oracle profit

## Recommendation

Consider using strict equality if donation-based oracle manipulation is a concern:

```diff
- require(balance0Before.add(uint256(amount0)) <= balance0(), 'IIA');
+ require(balance0Before.add(uint256(amount0)) == balance0(), 'IIA');
```

Note: This would break some legitimate use cases where token deflation or rebasing might cause minor balance discrepancies. If strict equality is enforced, a tolerance or donation-back mechanism should be added.

## References

- **trailofbits** — "Swap balance check uses <= instead of == — allows donation to manipulate TWAP oracle" (low)
