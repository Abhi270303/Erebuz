# M-08: ERC4626 Donation Inflation via Direct IAU Transfers to TAsset

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-2 (Deposit preserves backing ratio)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TAsset, IAU (InternalAccountingUnit), TreehouseAccounting
- **Source:** verified
- **Location:**
  - `TAsset.sol:L64-L81` — `_deposit()` gated by `isMinter(caller)`
  - `TreehouseAccounting.sol:L75` — `mintTo(TASSET, _amountLessFee)` mints IAU directly to TAsset
  - `InternalAccountingUnit.sol:L84-L87` — `mintTo()` onlyMinters

## Description

TAsset is an ERC4626 vault where `asset() = IAU` and `totalAssets()` = `IAU.balanceOf(address(this))` (OpenZeppelin default). The `_deposit()` override checks `isMinter(caller)`, preventing non-minters from depositing IAU to mint tETH shares. However, the IAU minter role includes `TreehouseAccounting`, which calls `IAU.mintTo(TASSET, amount)` directly (bypassing `TAsset._deposit()`):

```solidity
// TreehouseAccounting.sol:75
IInternalAccountingUnit(IAU).mintTo(TASSET, _amountLessFee);
```

This mints IAU directly to TAsset without minting corresponding tETH shares. This inflates `totalAssets()` while keeping `totalSupply()` of tETH constant, increasing the asset:share ratio.

Additionally, `IAU.mintTo()` is gated by `onlyMinters`, and minters are controlled by `addMinter()`/`removeMinter()` which are `onlyOwner`. A compromised owner can add any address as a minter, enabling direct IAU donation inflation.

**First-depositor attack variant:** TAsset inherits OZ ERC4626Upgradeable with `_decimalsOffset() = 0` (default for 18-decimal assets). In an empty TAsset, the first depositor can donate IAU directly to inflate the share price to extreme levels, causing subsequent depositors to receive 0 shares due to rounding.

## Root cause

`TAsset._deposit()` correctly gates deposit entry, but the `mintTo` (minter) path is a completely separate, un-gated entry for inflating `totalAssets()`. The ERC4626 spec assumes `totalAssets()` only changes through `deposit()`/`withdraw()`/`mint()`/`redeem()` calls.

## Impact

- **Legitimate PnL marking:** In the intended flow, `TreehouseAccounting.mark(MINT)` mints IAU to TAsset to represent profit accrual. This is correct behavior — all tETH holders share the value proportionally.
- **Compromised minter:** If a minter key is compromised, the attacker can mint unlimited IAU to TAsset, inflating share price to infinity, then redeem their own tETH (acquired cheaply) for the inflated value.
- **First-depositor attack:** If TAsset is ever emptied and re-filled, the first depositor can donate IAU to inflate share price and capture all future deposit value. This is a known OZ issue (OZ Issue #5223).

## Attack path (compromised minter + TreehouseAccounting.mark):

1. Executor or minter adds attacker address as minter (requires owner role).
2. Attacker calls `IAU.mintTo(TASSET, 1_000_000e18)` directly.
3. `TAsset.totalAssets()` increases by 1,000,000 wstETH worth.
4. `TAsset.totalSupply()` stays the same.
5. Share price (totalAssets / totalSupply) increases proportionally.
6. Attacker (who already held tETH) redeems for more IAU than deposited.
7. Attacker converts IAU to wstETH via redemption.

## References

- **trailofbits-08**: ERC4626 inflation via direct IAU transfers to TAsset
- **solodit-001**: TAsset ERC4626 first-depositor inflation / donation attack
- **OZ Issue #5223**: ERC4626 _decimalsOffset does not protect 18-decimal assets

## Recommendation

1. **Override `totalAssets()` in TAsset** to use a virtual offset or an internal accumulator that only changes through `deposit()`/`withdraw()`, rather than `IAU.balanceOf(address(this))`.
2. **Alternative:** Override `totalAssets()` to return an administratively tracked value that is only updated through authorized accounting flows.
3. **For first-depositor protection:** Simulate an initial deposit in the constructor or initialize with a non-zero share supply.
