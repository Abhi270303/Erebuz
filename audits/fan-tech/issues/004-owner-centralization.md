# Issue 004: Owner EOA controls all protocol functions

**Severity**: High (Governance)  
**Type**: Centralization Risk  
**File**: FanTech.sol, Gift.sol  
**Status**: By design, but critical risk

## Description

Both FanTech and Gift contracts use TransparentUpgradeableProxy behind a proxy admin EOA (`0x601853...d0c`). The OWNER EOA (`0xA6B6...8E3`) holds DEFAULT_ADMIN_ROLE, giving complete control over:

| Function | Impact |
|----------|--------|
| `upgradeTo()` (via proxy admin) | Replace implementation with arbitrary code |
| `grantRole(OPERATOR_ROLE, any)` | Give pool-creation rights to any address |
| `setProtocolFeeDestination()` | Redirect all future protocol fees |
| `setProtocolFeePercent()` | Set protocol fee up to 10% |
| `setSubjectFeePercent()` | Set subject fee up to 10% |
| `setReferrerFeePercent()` | Set referrer fee up to 10% |
| `setPoolFeePercent()` | Set pool fee up to 10% |

## Impact

The owner can:
1. Upgrade both contracts to drain all MNT (~94K MNT / $75K)
2. Redirect protocol fees to any address
3. Create unlimited pools via OPERATOR_ROLE grants
4. Single point of failure (key compromise = total loss)

## Remediation

- Transfer proxy admin to a multisig (e.g., 3/5 Gnosis Safe)
- Transfer DEFAULT_ADMIN_ROLE to a timelock contract
- Use a DAO or on-chain governance for parameter changes
