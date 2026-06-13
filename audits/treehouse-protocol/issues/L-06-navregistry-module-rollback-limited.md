# L-06: NavRegistry Module Rollback Limited to One Level — Recovery Risk

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** INV-4 (NAV calculation is manipulation-resistant)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** NavRegistry
- **Source:** verified
- **Location:** `NavRegistry.sol:L126-L155`

## Description

`NavRegistry` stores module addresses (like NavErc20 instances) that compute NAV for strategies. It maintains a one-level rollback capability via `revertModule` that restores the previous module address from `previousModuleAddresses`. However:

1. If a module address is updated from A → B (with A stored in `previousModuleAddresses`), and then updated again from B → C (B stored in `previousModuleAddresses`, overwriting A), only B can be rolled back to. A is permanently lost.
2. If module B is faulty (returns 0 or incorrect data), and the owner updates to C (also faulty), `revertModule` goes back to B (still faulty). There is no way to recover module A.

This is a single-point-of-failure risk: if module updates are not carefully sequenced, the NAV system can lose access to a correct module version. Since `onlyOwner` controls updates, this requires a privileged role to make a mistake, but the inability to recover from a two-update mistake is a design limitation.

## Impact

- Owner misconfiguration with two module updates can permanently lose access to a correct NAV module.
- Strategy NAV reads 0 or stale data → protocol under-reports NAV → incorrect PnL marking → value misallocation.

## References

- **invariant-lead-10**: NavRegistry module rollback limitation

## Recommendation

1. Maintain a history of all previous module addresses (not just the last one), allowing arbitrary rollback.
2. Add a timelock to module updates so errors can be caught before the old address is overwritten.
3. Add a function to explicitly restore any historical module address by owner action.
