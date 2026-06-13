# [M] MasterCheV3 decreaseLiquidity May Hardcode Slippage Parameters to Zero — MEV Sandwich Risk

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-NPM-02 — Position liquidity tracked by NPM equals actual pool liquidity
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`decreaseLiquidity`, `increaseLiquidity`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L580-L595`

## Description

When MasterChef calls `NonfungiblePositionManager.decreaseLiquidity()`, the `amount0Min` and `amount1Min` slippage parameters must be user-supplied to protect against MEV sandwich attacks. If these are hardcoded to 0 (or forwarded from user input without validation), MEV bots can manipulate pool prices before the decrease executes, extracting value from the user.

Additionally, if the `deadline` parameter is set to `block.timestamp` (or forwarded from a stale value), the slippage protection is effectively nullified.

## Root cause

To be verified by checking the exact parameters passed to `NPM.decreaseLiquidity()` inside `LBPMasterChefV3.sol`. The typical vulnerable pattern is:

```solidity
nonfungiblePositionManager.decreaseLiquidity(
    INonfungiblePositionManager.DecreaseLiquidityParams({
        tokenId: params.tokenId,
        liquidity: params.liquidity,
        amount0Min: 0,           // BUG: hardcoded to 0 — no slippage protection
        amount1Min: 0,           // BUG: hardcoded to 0
        deadline: block.timestamp // BUG: current timestamp — stale tx can still execute
    })
);
```

## Impact

- **MEV value extraction:** If `amount0Min` and `amount1Min` are 0, a sandwich attack can extract all user value:
  1. MEV bot sees pending `decreaseLiquidity` tx (user wants to remove liquidity)
  2. Bot front-runs with a large swap that moves the price against the user
  3. User's `decreaseLiquidity` executes at worse price
  4. Bot back-runs with a reverse swap, profiting from the price movement
- **User loss:** The difference between fair-market value and received tokens is captured by the MEV bot

## Attack path / preconditions

1. User calls `MasterChef.decreaseLiquidity` (or `increaseLiquidity`) with zero slippage parameters
2. MEV bot sees the pending transaction in the public mempool
3. Bot sandwiches the transaction (front-run swap → user tx → back-run swap)
4. User receives significantly fewer tokens than fair market value

## Proof of concept

`POC: pending` — requires code verification of the exact params passed:
```
// Check LBPMasterChefV3.sol lines ~580-595:
// Does the struct passed to NPM.decreaseLiquidity() use user-supplied amount0Min/amount1Min?
// Or are they hardcoded to 0?
```

## Recommendation

Forward the user-supplied slippage parameters to the NPM call:

```diff
nonfungiblePositionManager.decreaseLiquidity(
    INonfungiblePositionManager.DecreaseLiquidityParams({
        tokenId: params.tokenId,
        liquidity: params.liquidity,
-       amount0Min: 0,
-       amount1Min: 0,
+       amount0Min: params.amount0Min,
+       amount1Min: params.amount1Min,
        deadline: params.deadline
    })
);
```

## References

- **Solodit lens:** Lead SOL-008 (MEDIUM) — MC decreaseLiquidity may lack slippage protection
- **Historical:** C4-2023-12-particle-#2 (hardcoded 0), C4-2024-03-revert-lend-#460 (block.timestamp as deadline), C4-2024-06-vultisig-#103
- **Invariant:** INV-NPM-02, INV-RTR-01, INV-RTR-02
- **Priority:** Code-verify the actual slippage parameters passed before proceeding to POC
