# H-01: Owner Instantly Bypasses VaultRescuer 5-Day Timelock via Rescuable.updateRescuer

## Severity
**High** — Direct loss of all Vault funds. Requires owner cooperation (centralization risk).

## Files
- `libs/Rescuable.sol:37-42` — `rescueERC20()` gated by `onlyRescuer`
- `libs/Rescuable.sol:44-49` — `rescueETH()` gated by `onlyRescuer`
- `libs/Rescuable.sol:51-55` — `updateRescuer()` gated by `onlyOwner`
- `periphery/VaultRescuer.sol:23-33` — `rescueERC20()` intended to be the only rescue path
- `Vault.sol:76-80` — Vault inherits Rescuable

## Description

The Vault contract inherits from `Rescuable`, an abstract contract that provides:
- `rescueERC20(token, to, amount)` — transfer any ERC20 from this contract
- `rescueETH(to)` — transfer all native ETH from this contract

Both are gated by `onlyRescuer`.

The `updateRescuer(newRescuer)` function is `onlyOwner` — the owner can set the rescuer to any address.

The `VaultRescuer` contract was deployed to add a 5-day timelock before rescued funds can be withdrawn. However, it provides no actual security because:

1. Owner calls `Vault.updateRescuer(owner)` — changes rescuer to themselves
2. Owner calls `Vault.rescueERC20(wstETH, attackerEOA, type(uint).max)` — instantly drains all wstETH
3. No timelock, no delay, no multi-sig bypass needed

The `VaultRescuer` contract and its 5-day `WAIT_TIME` are architecturally irrelevant — they provide a false sense of security.

## TOB-TETH-2
Trail of Bits identified this issue and the Treehouse team chose not to fix it (stated as "accepted centralization risk").

## Proof of Concept
```solidity
// Owner bypasses VaultRescuer timelock
Vault vault = Vault(0x551d155760ae96050439AD24Ae98A96c765d761B);
address wstETH = vault.getUnderlying();

// Owner sets rescuer to themselves
vault.updateRescuer(owner);

// Owner instantly drains all wstETH — NO timelock
vault.rescueERC20(IERC20(wstETH), attacker, IERC20(wstETH).balanceOf(address(vault)));
```
