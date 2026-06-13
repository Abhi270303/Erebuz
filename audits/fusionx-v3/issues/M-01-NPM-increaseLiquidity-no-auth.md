# [M] NonfungiblePositionManager.increaseLiquidity Lacks Authorization — Anyone Can Desync MasterChef Liquidity Accounting

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-MC-06 — Pool totalLiquidity must equal sum of all staked positions' liquidity
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `NonfungiblePositionManager` (`increaseLiquidity`)
- **Source:** verified (repo source)
- **Location:** `v3-periphery/contracts/NonfungiblePositionManager.sol:L199-L254`

## Description

`NPM.increaseLiquidity()` has only the `checkDeadline` modifier — **no `isAuthorizedForToken` modifier**. Compare with `decreaseLiquidity` (L262), `collect` (L314), and `burn` (L378) which all require authorization. When a position is staked in MasterChef, anyone can add liquidity to it directly through NPM, causing MC's `totalLiquidity` and the LM pool's `lmLiquidity` to desync from actual pool state.

## Root cause

```solidity
// L199: increaseLiquidity — only checkDeadline, NO isAuthorizedForToken
function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external payable checkDeadline(params.deadline)
    returns (uint128 liquidity, uint256 amount0, uint256 amount1) { ... }

// L262: decreaseLiquidity — HAS isAuthorizedForToken
function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external payable checkDeadline(params.deadline) isAuthorizedForToken(params.tokenId) { ... }
```

MasterChef tracks liquidity internally at `LBPMasterChefV3.sol:L476-L515` (`updateLiquidityOperation`), which reads actual liquidity from NPM to correct values. But this only triggers on the next MC interaction — leaving a window where accounting is desynchronized.

## Impact

- **Temporal reward misaccounting:** During the desync window, `lmLiquidity` is lower than actual, so `rewardGrowthGlobalX128` grows faster (rewards per-unit-liquidity are inflated). When MC syncs, dilution occurs.
- **Griefing only:** The attacker must fund the extra liquidity (paying for token0 + token1), making this uneconomical for pure griefing.
- **Self-correcting:** The next MC interaction (`harvest`, `withdraw`, `updateLiquidity`) triggers `updateLiquidityOperation` which reads actual liquidity from NPM and corrects MC's state.

## Attack path / preconditions

1. User deposits LP NFT into MasterChef via `onERC721Received`
2. MC records `positionInfo[liquidity] = 1000`, `pool.totalLiquidity += 1000`
3. Anyone calls `NPM.increaseLiquidity(tokenId, ...)` directly (provides tokens to fund the extra liquidity)
4. NPM's `_positions[tokenId].liquidity` becomes 2000, but MC still tracks 1000
5. LM pool's `lmLiquidity` is also stale at 1000 instead of 2000
6. Rewards are accrued with `lmLiquidity = 1000` (2x inflation) until next MC interaction

## Proof of concept

`POC: pending` — fork test:
1. Stake NFT in MC, record totalLiquidity
2. Call NPM.increaseLiquidity() directly for the same tokenId
3. Verify MC.totalLiquidity != sum of staked positions' actual liquidity
4. Harvest and verify reward is abnormally high due to desync

## Recommendation

Add the `isAuthorizedForToken` modifier to `increaseLiquidity`:

```diff
function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external payable override checkDeadline(params.deadline)
+   isAuthorizedForToken(params.tokenId)
    returns (uint128 liquidity, uint256 amount0, uint256 amount1) { ... }
```

If the design intentionally allows any third party to add liquidity to any position, MC must be notified of the change via a callback or the MC should use `NPM.positions()` as the source of truth on every operation (already done in `updateLiquidityOperation` — make it universal).

## References

- **Invariant lens:** Lead #1 (MEDIUM) — NPM.increaseLiquidity lacks authorization; Lead #6 (LOW) — MC totalLiquidity desync
- **Invariant broken:** INV-MC-06 (MISSING — user can modify position liquidity via NPM directly without updating MasterChef)
- This is a known gap in the Uniswap V3 NPM design (intentional for permissionless liquidity adding) that becomes a security issue in MasterChef-integrated contexts
