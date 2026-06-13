# L-05: TreehouseRedemption V1 Fee Creates Systematic IAU:wstETH Surplus

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** INV-1 (1 IAU ≈ 1 wstETH NAV unit)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TreehouseRedemption (V1)
- **Source:** verified
- **Location:** `TreehouseRedemption.sol:L118-L125`

## Description

In `TreehouseRedemption.finalizeRedeem()` (V1), the redemption fee is deducted from the user's `_returnAmount` in wstETH but the full `_returnAmount` in IAU is burned:

```solidity
// TreehouseRedemption.sol:118-125 (conceptual)
uint _fee = (_returnAmount * redemptionFee) / PRECISION;
_returnAmount -= _fee;  // user gets less wstETH

// Burn the FULL _returnAmount in IAU (not returnAmount - fee)
IInternalAccountingUnit(IAU).burn(_originalReturnAmount);

// Transfer only the reduced wstETH to user
IERC20(_underlying).safeTransferFrom(address(VAULT), msg.sender, _returnAmount);
```

This creates a systematic surplus: IAU total supply decreases by `_returnAmount` but Vault wstETH decreases by only `_returnAmount - _fee`. The `_fee` amount of wstETH stays in the Vault while `_fee` amount of IAU is burned from circulation.

Over time, this makes 1 IAU worth MORE than 1 wstETH on paper (the IAU:wstETH ratio shifts in favor of remaining holders). While this is solvency-safe (the protocol is overcollateralized), it represents a value extraction from users — the fee is double-counted: the user pays the fee in both IAU (burned) and wstETH (retained by protocol).

**Note:** TreehouseRedemptionV2 may handle this differently — the V2 code should be checked to confirm whether it has the same issue.

## Impact

- Every V1 redemption with fee > 0 shifts the IAU:wstETH ratio permanently.
- This is not a loss to individual users beyond the fee itself, but it creates an opaque economic surplus that is not tracked.
- The protocol may appear to have more IAU backing than it should.

## References

- **invariant-lead-7**: TreehouseRedemption V1 fee deduction creates systematic surplus

## Recommendation

Ensure the IAU burn amount matches the wstETH transferred to the user (not the pre-fee amount):
```diff
- IInternalAccountingUnit(IAU).burn(_originalReturnAmount);
+ IInternalAccountingUnit(IAU).burn(_returnAmount); // post-fee amount
```

If the fee IAU is intended to be burned, the fee wstETH should also be separately accounted for (e.g., sent to treasury rather than retained in Vault).
