# M-06: TreehouseRedemptionV2.finalizeRedeem Violates CEI Pattern — Read-Only Reentrancy Risk

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-3 (Redemption cannot extract more than deposited)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TreehouseRedemptionV2, TAsset
- **Source:** verified
- **Location:**
  - `TreehouseRedemptionV2.sol:L107-L140` — `finalizeRedeem()` CEI order
  - `TreehouseRedemptionV2.sol:L207-L210` — swap-and-pop entry deletion (last)

## Description

`finalizeRedeem()` performs external calls BEFORE state updates, violating the Checks-Effects-Interactions (CEI) pattern:

```solidity
function finalizeRedeem(uint _redeemIndex) external nonReentrant whenNotPaused ... {
    ...
    // INTERACTION: External call to TAsset.redeem() — burns tShares, transfers IAU
    uint _assets = IERC4626(TASSET).redeem(_redeem.shares, address(this), address(this));  // LINE 113

    // EFFECTS: State updates AFTER external call
    redeeming[msg.sender] -= _redeem.shares;                                             // LINE 114
    totalRedeeming -= _redeem.shares;                                                    // LINE 115
    ...
    // INTERACTION: IAU burn
    IInternalAccountingUnit(IAU).burn(_returnAmount);                                     // LINE 127

    // INTERACTION: Balance check + potential IAU transfer back to TAsset
    _assets = IERC20(IAU).balanceOf(address(this));                                      // LINE 130
    if (_assets > 0) {
        IERC20(IAU).safeTransfer(TASSET, _assets);                                       // LINE 133
    }

    // EFFECT: Entry deletion LAST
    _deleteRedeemEntry(_redeemIndex);                                                     // LINE 139
}
```

While `nonReentrant` protects against direct reentrancy, **read-only reentrancy** is possible: the `TAsset.redeem()` call at line 113 could, in a callback (if TAsset is upgraded to a malicious implementation via its UUPS upgradeability), query:
- `getRedeemLength()` — returns stale length (entry not deleted yet)
- `getRedeemInfo(index)` — returns stale redemption data
- `redeeming[user]` — still the pre-update value
- `totalRedeeming` — still the pre-update value

The swap-and-pop pattern in `_deleteRedeemEntry` (line 207-210) further compounds this: after deletion, remaining entries are reordered. A user who tracks redemptions by index could accidentally finalize a different redemption than intended after a prior deletion.

## Root cause

External call (`TAsset.redeem()`) before state mutations. The contract relies on `nonReentrant` which does not protect against read-only reentrancy or cross-contract view manipulation.

## Impact

- **Read-only reentrancy:** A malicious TAsset implementation (TAsset is UUPS upgradeable, `_authorizeUpgrade` is `onlyOwner`) could reenter during `redeem()` and read stale state, potentially manipulating downstream decisions in other contracts that read `TreehouseRedemptionV2` state.
- **Swap-and-pop confusion:** Users with multiple pending redemptions can accidentally finalize the wrong entry after a prior deletion, leading to unexpected return amounts.

## Attack path

1. User has ≥2 pending redemptions at different rates.
2. User finalizes index 0 → swap-and-pop moves entry 1 to slot 0, pops slot 1.
3. User calls `getRedeemLength()` → shows 1 entry.
4. User calls `finalizeRedeem(0)` intending to finalize their remaining entry — this works correctly.
5. But: if another user's view of the system reads stale `redeeming` or `totalRedeeming` values during the external call window, it could make incorrect decisions based on outdated liquidity information.

Primary concern: TAsset upgrade to a malicious implementation (requires owner) reentering during `TAsset.redeem()` to read stale `totalRedeeming` from TreehouseRedemptionV2 and feed it to TreehouseFastlane for incorrect liquidity calculations.

## References

- **solodit-006**: finalizeRedeem CEI violation (read-only reentrancy)
- **pashov-006**: Swap-and-pop reordering (V2)
- **solodit-007**: Multiple redeem entries allow race condition

## Recommendation

1. **Reorder `finalizeRedeem` to CEI pattern:**
   ```diff
   function finalizeRedeem(uint _redeemIndex) ... {
       ...
       // EFFECTS first
   +    redeeming[msg.sender] -= _redeem.shares;
   +    totalRedeeming -= _redeem.shares;
   +    _deleteRedeemEntry(_redeemIndex);
       
       // Then INTERACTIONS
   +    uint _assets = IERC4626(TASSET).redeem(_redeem.shares, address(this), address(this));
       ...
   }
   ```

2. **Replace swap-and-pop with ordered deletion** to avoid index reordering, or document the behavior clearly and return the new index for the remaining entries.

3. **Consider a timelock on TAsset upgrade** — TAsset being UUPS means `_authorizeUpgrade` is `onlyOwner` with no delay. Adding a timelock to upgrades would prevent the reentrancy scenario.
