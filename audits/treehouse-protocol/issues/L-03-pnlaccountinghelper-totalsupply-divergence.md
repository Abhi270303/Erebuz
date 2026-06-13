# L-03: PnlAccountingHelper Uses IAU.totalSupply() Instead of IAU.balanceOf(T_ASSET) Causing PnL Divergence

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** INV-1 (1 IAU ≈ 1 wstETH NAV unit)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** PnlAccountingHelper, NavLens, TreehouseAccounting
- **Source:** verified
- **Location:**
  - `periphery/PnlAccountingHelper.sol:L86` — uses `NAV_HELPER.getProtocolIau()` = `IAU.totalSupply()`
  - `periphery/NavLens.sol:L76` — returns `IAU.balanceOf(T_ASSET)` = IAU held in TAsset

## Description

The two PnL entry points use different measures of "IAU supply" for `_lastNav`:

| Contract | Source | Value |
|----------|--------|-------|
| `PnlAccounting` | `NavLens.lastRecordedProtocolNav()` | `IAU.balanceOf(T_ASSET)` |
| `PnlAccountingHelper` | `NAV_HELPER.getProtocolIau()` | `IAU.totalSupply()` |

These values diverge when IAU is transiently held outside TAsset:

1. **Fee processing:** `TreehouseAccounting.mark(MINT)` first mints `_fee` IAU to `address(this)` (TreehouseAccounting), then deposits it to TAsset. During the mint → deposit window (single transaction, but visible between blocks), `totalSupply() > balanceOf(T_ASSET)`.
2. **Pending burns:** Redemption contracts hold IAU temporarily before burning. `totalSupply()` includes this IAU, but `balanceOf(T_ASSET)` does not.
3. **Router intermediate state:** `TreehouseRouter._mintAndStake()` mints IAU to itself, then deposits to TAsset.

When `totalSupply() > balanceOf(T_ASSET)`, PnlAccountingHelper sees an inflated `_lastNav`, potentially:
- Suppressing legitimate profit marking (if `_currentNav > _lastNav` is true but the helper sees a higher `_lastNav`)
- Or creating false loss

## Impact

- Small, temporary divergence between the two accounting paths.
- If the helper is used for strategy PnL, the divergence could cause incorrect fee calculations.
- Not directly exploitable but creates accounting inconsistency.

## References

- **trailofbits-05**: PnlAccountingHelper uses totalSupply() not balanceOf(T_ASSET)

## Recommendation

Align both accounting paths to use the same source of truth for `_lastNav`. Since the on-chain NAV (IAU in TAsset) is the canonical measure, use `IAU.balanceOf(T_ASSET)` everywhere:
```diff
// PnlAccountingHelper.sol:86
- uint _lastNav = NAV_HELPER.getProtocolIau();
+ uint _lastNav = IERC20(IAU).balanceOf(TASSET); // or NAV_HELPER.lastRecordedProtocolNav()
```
