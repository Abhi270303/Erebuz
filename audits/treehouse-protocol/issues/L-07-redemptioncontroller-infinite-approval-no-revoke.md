# L-07: RedemptionController Infinite Approval Has No Separate Revocation Path

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (access-control hardening)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** Vault, RedemptionController
- **Source:** verified
- **Location:**
  - `Vault.sol:L86-L97` — `setRedemption()` grants `type(uint).max` approval
  - `RedemptionController.sol:L48-L55` — `redeem()` uses `safeTransferFrom` from Vault

## Description

`Vault.setRedemption()` at line 94 grants `type(uint).max` approval for the underlying token (wstETH) to the RedemptionController:

```solidity
// Vault.sol:86-97
function setRedemption(address _newRedemption) external onlyOwner {
    ...
    if (redemption != address(0)) {
        IERC20(getUnderlying()).approve(redemption, 0);  // revoke old
    }
    IERC20(getUnderlying()).approve(_newRedemption, type(uint).max);  // infinite approval
    redemption = _newRedemption;
}
```

The only way to revoke the infinite approval is to call `setRedemption()` again with a new address (which revokes the old one while granting infinite approval to the new one). There is no standalone `revokeApproval()` or `decreaseAllowance()` path.

If the RedemptionController contract has a logic flaw (e.g., a read-only reentrancy, incorrect access control, or future upgrade to a malicious implementation), all wstETH in the Vault can be drained because there is no way to restrict the approval without replacing the entire redemption system.

The same `type(uint).max` approval pattern is used for TAsset in `TreehouseAccounting` (line 57): `IERC20(IAU).approve(address(TASSET), type(uint).max)`.

## Impact

- If RedemptionController is compromised or upgraded to a malicious implementation, unlimited wstETH can be pulled from Vault.
- No emergency "revoke all" function exists.
- The only defense is replacing the redemption address (which immediately grants infinite approval to the new address — a risky operation).

## References

- **trailofbits-06**: RedemptionController infinite approval — no revocation path

## Recommendation

1. Add a standalone `removeRedemption()` function that revokes the approval without setting a new one:
   ```solidity
   function removeRedemption() external onlyOwner {
       IERC20(getUnderlying()).approve(redemption, 0);
       emit RedemptionRemoved(redemption);
       redemption = address(0);
   }
   ```
2. Consider using finite approvals (e.g., the amount currently held by the controller) instead of `type(uint).max`.
3. Add an `emergencyRevokeAll()` function that revokes all approvals in one transaction.
