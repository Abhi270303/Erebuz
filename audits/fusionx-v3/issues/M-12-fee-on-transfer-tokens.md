# [M] Fee-on-Transfer and Rebasing Tokens Break Pool Balance Accounting — No Token Whitelist

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-POOL-03 — Pool token balances must not decrease due to swaps
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3Pool` (`swap`, `mint`, `burn`, `flash`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3Pool.sol:L806-L814` (swap balance check)

## Description

The pool verifies payment by comparing `balanceOf(token)` after callback against `expectedAmount + balanceBefore`. If the pool token is fee-on-transfer (deflationary) or rebasing, the actual received amount differs from the transferred amount parameter, causing the balance check to either fail (DoS) or pass incorrectly. The factory has no token whitelist — anyone can create a pool for any ERC20 token.

## Root cause

```solidity
// FusionXV3Pool.sol ~L806-L814
uint256 balance0Before = balance0();
// ... callback transfers token0 ...
IERC20(token0).safeTransfer(recipient, amount0);
// or from callback:
IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
uint256 balance0After = balance0();
require(balance0After >= balance0Before + amount0, 'II');  // Balance check
```

If token0 has a fee-on-transfer mechanism, the actual balance increase is `amount0 * (1 - fee)` but the check requires `amount0`. This causes the transaction to revert.

For mint operations, if the token deflates during transfer, the pool receives less than expected but the LP is credited with the full amount, creating an accounting discrepancy.

## Impact

- **Pool DoS:** Creating a pool with a fee-on-transfer token makes all swaps/mints/burns on that pool revert
- **Silent accounting error:** If a token's fee changes dynamically (or after upgrades), the pool may silently accept incorrect payment
- **No factory protection:** `FusionXV3Factory.createPool()` only validates `tokenA != tokenB` and a valid fee tier — there is no token quality check

## Attack path / preconditions

1. A fee-on-transfer or rebasing token is created and added to a FusionX V3 pool
2. Any swap on this pool reverts — the pool is permanently DoSed
3. Alternatively, if the token has a dynamic fee that the attacker can toggle, they could cause unpredictable behavior

## Proof of concept

`POC: pending` — unit test with a mock fee-on-transfer token:
1. Deploy a deflationary ERC20 (transfers 1% fee)
2. Create a FusionX V3 pool with this token
3. Attempt a swap → observe revert in the balance check

## Recommendation

1. Document that FusionX V3 pools are designed for standard ERC20 tokens (no fee-on-transfer, no rebasing)
2. Consider adding a token whitelist or checking for common non-standard token patterns at pool creation
3. Add a circuit breaker: if balance checks consistently fail in a suspicious pattern, pause the pool

## References

- **Solodit lens:** Lead SOL-010 (MEDIUM) — Fee-on-transfer and rebasing tokens break balance accounting
- **Invariant:** INV-POOL-03
- **Historical:** Multiple C4 findings on fee-on-transfer tokens in Uniswap V3 pools; Uniswap V3 Core Audit (Cecuro) token integration warnings
- **Uniswap V3 stance:** Documented that pools are designed for standard ERC20 tokens only — this is an accepted risk
