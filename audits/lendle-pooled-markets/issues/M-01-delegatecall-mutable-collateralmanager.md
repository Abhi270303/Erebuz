# M-01: DELEGATECALL to Mutable CollateralManager Enables Storage Corruption

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Status** | unconfirmed |
| **Invariant broken** | INV-08 (assumed — access control bypass via storage corruption) |
| **Contracts** | `LendingPool.sol`, `LendingPoolCollateralManager.sol` |
| **Functions** | `LendingPool.liquidationCall()` |
| **Line ranges** | LendingPool L428–L455, LendingPoolCollateralManager L32–L36 |
| **Source files** | `/protocol/lendingpool/LendingPool.sol`, `/protocol/lendingpool/LendingPoolCollateralManager.sol` |

---

## Description

`LendingPool.liquidationCall()` uses `delegatecall` to execute liquidation logic in the `LendingPoolCollateralManager` contract. The target address is fetched at runtime from `_addressesProvider.getLendingPoolCollateralManager()`.

### The vulnerability

Because `delegatecall` executes in the **caller's storage context** (the LendingPool proxy), the `CollateralManager` contract can read and write **any** storage variable in the LendingPool proxy. The `CollateralManager` contract explicitly inherits `LendingPoolStorage` (LendingPoolCollateralManager.sol L35) to have matching storage layout — this is by design in Aave V2.

```solidity
// LendingPool.sol L435-L448
address collateralManager = _addressesProvider.getLendingPoolCollateralManager();
(bool success, bytes memory result) = collateralManager.delegatecall(
    abi.encodeWithSignature(
        "liquidationCall(address,address,address,uint256,bool)",
        collateralAsset, debtAsset, user, debtToCover, receiveAToken
    )
);
```

The `_addressesProvider` is `Ownable` — its owner can change `LendingPoolCollateralManager` to any contract address at any time. If the owner key is compromised or acts maliciously:

1. The owner sets the `CollateralManager` address to a malicious contract
2. Any user calls `liquidationCall()` — which triggers `delegatecall` to the malicious contract
3. The malicious contract, running in LendingPool's storage context, can:
   - Drain all `_reserves` mappings (erase user balances)
   - Change `_usersConfig` (disable user collateral)
   - Modify interest rate strategies
   - Change the `_addressesProvider` pointer
   - Set `_paused` to prevent further operations
   - Transfer all held tokens to any address

## Impact

While this is a governance/centralization risk rather than an autonomous exploit, the impact is **total loss of all protocol funds** if the AddressesProvider owner is compromised. The owner doesn't even need to be malicious — if the owner key is stolen, the attacker can drain the entire pool in a single transaction via a malicious CollateralManager.

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **trailofbits** | lead 6 | MEDIUM |
| **forefy** | forefy-005 | MEDIUM |
| **solodit** | SOLODIT-006 | MEDIUM |
| **invariant** | lead 9 | INFORMATIONAL |

4 of 5 hunters flagged this. Reconciled to MEDIUM.

## Mitigation

1. **Use a static delegatecall target**: Instead of looking up the CollateralManager at runtime, hard-code it or set it once in the constructor/initializer
2. **Add a timelock**: Any change to the `CollateralManager` address should be subject to a delay (e.g., 48-hour timelock) and emit an event
3. **Multisig**: Ensure the `AddressesProvider` owner is a multisig wallet with reasonable quorum (3-of-5 minimum)
4. **Document as a risk**: If the mutable delegatecall pattern is kept (inherited from Aave V2), clearly document it as a `CRITICAL` centralization risk in operational documentation

## References

- This is the same pattern used in Aave V2. Multiple security sources document storage collision risks when the implementation contract has a different storage layout.
- The `CollateralManager` contract confirming it inherits `LendingPoolStorage`: LendingPoolCollateralManager.sol L35
