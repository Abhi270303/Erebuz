# L-02: MultiFeeDistribution.setMinters() One-Time Immutable Configuration

| Field | Value |
|-------|-------|
| **Severity** | LOW |
| **Status** | unconfirmed |
| **Contract** | `MultiFeeDistribution.sol` |
| **Function** | `setMinters(address[] memory _minters)` |
| **Line range** | L104–L110 |
| **Source file** | `/staking/MultiFeeDistribution.sol` |

---

## Description

`setMinters()` sets the addresses authorized to mint LEND reward tokens. The function has a one-time guard (`mintersAreSet`):

```solidity
function setMinters(address[] memory _minters) external onlyOwner {
    require(!mintersAreSet);
    for (uint256 i = 0; i < _minters.length; i++) {
        _setMinter(_minters[i], true);
    }
    mintersAreSet = true;
}
```

Once `mintersAreSet` is `true`, it cannot be changed. This means:

- If a minter address is compromised, there is **no way to revoke** their minting power
- If a minter needs to be rotated (employee leaves, key rotation), the entire contract would need to be redeployed
- All approved minters can mint an unlimited amount of LEND tokens via `mint()` (L317–L346), which inflates the LEND supply

### Impact

This is a centralization risk and operational inflexibility. Minters control LEND token supply inflation. If any minter key is compromised, unlimited LEND can be minted.

### Mitigation

Allow the owner to revoke specific minter addresses at any time, rather than locking the configuration:
```solidity
function setMinters(address[] memory _minters, bool[] memory _status) external onlyOwner {
    for (uint256 i = 0; i < _minters.length; i++) {
        _setMinter(_minters[i], _status[i]);
    }
}
```

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | lead 10 | LOW |

Only 1 hunter flagged this.
