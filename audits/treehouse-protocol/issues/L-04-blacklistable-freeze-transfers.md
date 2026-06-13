# L-04: BlacklistableUpgradeable Allows Blacklister to Freeze All tETH Transfers

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (centralization risk)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TAsset, BlacklistableUpgradeable
- **Source:** verified
- **Location:** `libs/BlacklistableUpgradeable.sol`, `TAsset.sol:L86-L92`

## Description

TAsset's `_update()` override checks `notBlacklisted(from) && notBlacklisted(to) && notBlacklisted(msg.sender)`:

```solidity
// TAsset.sol:86-92
function _update(address from, address to, uint256 value) internal virtual override {
    if (from != address(0)) _notBlacklisted(from);
    if (to != address(0)) _notBlacklisted(to);
    if (msg.sender != address(0)) _notBlacklisted(msg.sender);
    super._update(from, to, value);
}
```

The blacklister (set by `onlyOwner`) can blacklist any address, preventing that address from sending or receiving tETH. This includes preventing:
- Deposits (sending IAU to TAsset)
- Redemptions (receiving IAU from TAsset)
- Transfers between users

The owner can also set the blacklister address. If the blacklister role is assigned and the blacklister key is compromised, all user funds in TAsset can be frozen.

This is a standard pattern inherited from Circle's USDC contract (BlacklistableUpgradeable), and it's intentionally powerful. The risk depends on who holds the blacklister key.

## Impact

- A compromised blacklister can freeze all tETH transfers, effectively locking all user funds in the vault.
- Users cannot deposit, withdraw, or transfer tETH.
- This does not directly steal funds but holds them hostage.

## References

- **solodit-009**: BlacklistableUpgradeable can freeze all tETH transfers

## Recommendation

1. Verify whether the blacklister address is set in the deployed TAsset implementation. If not set, consider leaving it unset.
2. If blacklisting is needed, use a multi-sig or timelock for both setting the blacklister and performing blacklist operations.
3. Document the blacklister capability for users so they understand the centralization risk.
