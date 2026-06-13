# M-03: NavErc20 Treats Native ETH Balance as stETH Causing NAV Inaccuracy

- **Severity:** Medium
- **Status:** unconfirmed
- **Contract:** NavErc20 (`nav`)
- **Location:** `modules/nav/NavErc20.sol:L38-L58`

## Description

`NavErc20.nav()` adds `_target.balance` (native ETH) directly to the NAV accumulator which is then treated as stETH by the final `getWstETHByStETH()` conversion:

```solidity
function nav(address _target, address[] memory _tokens) external view returns (uint _nav) {
    _nav += _target.balance;        // <-- native ETH added as if it were stETH

    uint wip;
    uint wstETHBalance;
    for (uint i; i < _tokens.length; ++i) {
        wip = IERC20(_tokens[i]).balanceOf(_target);
        if (wip > 0) {
            unchecked {
                if (_tokens[i] == address(wstETH)) {
                    wstETHBalance = wip;    // raw wstETH, no conversion
                } else if (_tokens[i] == address(wstETH.stETH())) {
                    _nav += wip;            // raw stETH
                } else {
                    _nav += (RATE_PROVIDER_REGISTRY.getRateInEth(_tokens[i]) * wip) / 1e18;
                }
            }
        }
    }

    _nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;   // <-- _nav treated as stETH
}
```

Native ETH (18 decimals) is added to `_nav` but `_nav` is then converted from stETH to wstETH via `getWstETHByStETH()`. Since ETH ≠ stETH (the Lido stETH/ETH exchange rate can deviate from 1:1 during depeg events), the NAV is incorrectly computed.

## Root cause

The function assumes `_target.balance` is denominated in stETH, but it's actually native ETH. The developer likely assumed ETH = stETH (1:1 peg), which can break during stETH depeg events.

## Impact

- If the vault (or strategy) holds native ETH, the NAV is mispriced by `target.balance * (1 - 1/stEthPerToken)` in wstETH terms.
- During stETH depeg (e.g., May 2022 where stETH traded at 0.95 ETH), the error would be proportional to the depeg.
- The NAV error flows into PnlAccounting mark-to-market, causing incorrect profit/loss detection.
- In practice, the Vault should not hold native ETH, but strategies might.

## Attack path

This is a latent accounting error:
1. The Vault or a strategy accumulates native ETH (e.g., from `selfdestruct`, ETH sent by mistake, or as dust).
2. `NavLens.vaultNav()` -> `NavErc20.nav(VAULT)` misprices the ETH.
3. `PnlAccounting.doAccounting()` computes incorrect PnL.
4. Incorrect IAU mint/burn causes value misallocation between TAsset holders.

## Recommendation

Convert native ETH to stETH using a rate provider before adding:
```diff
- _nav += _target.balance;
+ if (_target.balance > 0) {
+     _nav += (_target.balance * 1e18) / RATE_PROVIDER_REGISTRY.getRateInEth(wstETH.stETH());
+ }
```

Or skip ETH entirely since the Vault should never hold it.
