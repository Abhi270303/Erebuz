# M-01: Main PnlAccounting Uses NavErc20 Which Misses wstETH Staking Value

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-02 (Protocol NAV must correctly measure total asset value to compute PnL)
- **Chain / network:** ethereum (chainId 1)
- **Contract:** PnlAccounting (`doAccounting`), NavLens (`vaultNav`), NavErc20 (`nav`)
- **Source:** verified
- **Location:** 
  - `periphery/PnlAccounting.sol:L51-L73`
  - `periphery/NavLens.sol:L54-L59`
  - `modules/nav/NavErc20.sol:L37-L59`

## Description

The main `PnlAccounting.doAccounting()` computes protocol NAV using `NavLens.vaultNav()` which delegates to `NavErc20.nav()`. This function computes wstETH-denominated NAV by taking the **raw wstETH balance** of the vault without converting to stETH first. Since wstETH is a non-rebasing token, its raw balance never reflects accrued Lido staking rewards.

In contrast, `PnlAccountingHelper.doAccounting()` (which handles strategy PnL) correctly uses `NavHelper.getTokensNav()` which converts wstETH to stETH via `getStETHByWstETH()`, capturing the full staking yield.

## Root cause

`NavErc20.nav()` at line 58:
```solidity
_nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;
```

Here `wstETHBalance` is the raw ERC-20 balance of wstETH — a value that never changes as staking rewards accrue. The function only applies `getWstETHByStETH()` to non-wstETH tokens, not to wstETH itself.

Compare with `NavHelper._priceInSteth()` which correctly handles wstETH:
```solidity
if (_asset == unStETH.WSTETH()) {
    return IwstETH(payable(unStETH.WSTETH())).getStETHByWstETH(_amount);
}
```

## Impact

- If the main PnlAccounting is used (instead of the helper), staking rewards from vault wstETH are invisible to the mark-to-market system.
- The protocol cannot mint profit IAU or burn loss IAU correctly.
- The discrepancy grows with the vault's wstETH balance and the duration since the last mark.
- With ~3% APR on staked ETH, the error is ~0.008% per day of the staked amount.

## Attack path / precondition

Not an exploitable attack, but a systemic accounting flaw:
- If the owner/executor calls `PnlAccounting.doAccounting()` instead of `PnlAccountingHelper.doAccounting()`, staking rewards are silently ignored.
- The IAU supply becomes permanently misaligned with the true protocol value.

## Proof of concept

`POC: pending`

## Recommendation

Fix `NavErc20.nav()` to convert wstETH to stETH before aggregating, matching the approach in `NavHelper._priceInSteth()`:

```diff
function nav(address _target, address[] memory _tokens) external view returns (uint _nav) {
    _nav += _target.balance;

    uint wip;
-   uint wstETHBalance;
    for (uint i; i < _tokens.length; ++i) {
        wip = IERC20(_tokens[i]).balanceOf(_target);
        if (wip > 0) {
            unchecked {
                if (_tokens[i] == address(wstETH)) {
-                   wstETHBalance = wip;
+                   _nav += wstETH.getStETHByWstETH(wip);  // convert wstETH -> stETH
                } else if (_tokens[i] == address(wstETH.stETH())) {
                    _nav += wip;
                } else {
                    _nav += (RATE_PROVIDER_REGISTRY.getRateInEth(_tokens[i]) * wip) / 1e18;
                }
            }
        }
    }

-   _nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;
+   _nav = wstETH.getWstETHByStETH(_nav);  // convert total stETH -> wstETH
}
```

Alternatively, ensure that only `PnlAccountingHelper.doAccounting()` is used and deprecate the main `PnlAccounting.doAccounting()` path.
