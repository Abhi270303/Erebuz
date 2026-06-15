# L-06 ZapV1 _approveTokenIfNeeded uses deprecated safeApprove with hardcoded 1e24 threshold

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (spec quality)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalZapV1` (`_approveTokenIfNeeded`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalZapV1.sol:L398-L403`

## Description

`_approveTokenIfNeeded()` has two issues:

1. **Deprecated safeApprove:** Uses OpenZeppelin's `safeApprove` which is deprecated. Some tokens (e.g., USDT) revert when changing a non-zero approval to another non-zero value without resetting to zero first.

2. **Hardcoded 1e24 threshold:** The re-approval threshold `1e24` is approximately 1M units for 18-decimal tokens but astronomically large for low-decimal tokens (e.g., USDC with 6 decimals → 1e24 = 10^18 USDC), making the check practically useless for low-decimal tokens. For 18-decimal tokens, any zap > 1M units triggers a wasteful re-approval each time.

3. **MAX_INT permanent allowance:** Sets unlimited allowance to the TropicalRouter. If the Router contract is compromised or upgraded to a malicious implementation, all tokens the Zap has ever approved to the Router can be drained.

## Root cause

```solidity
if (IERC20(_token).allowance(address(this), tropicalRouterAddress) < 1e24) {
    IERC20(_token).safeApprove(tropicalRouterAddress, MAX_INT);
}
```

## Impact

- **USDT incompatibility:** Zaps involving USDT or similar tokens may revert if they require the zero-first approval pattern
- **Router compromise escalation:** If Router is upgraded to a malicious implementation, the unlimited allowance exposes all Zap-approved tokens
- Low severity: requires Router compromise which is already game-over for the protocol

## Recommendation

Replace with `safeIncreaseAllowance` or `forceApprove`:

```diff
- IERC20(_token).safeApprove(tropicalRouterAddress, MAX_INT);
+ IERC20(_token).safeIncreaseAllowance(tropicalRouterAddress, _amount);
```

## References

- pashov (pashov-012) — 1e24 threshold unsuitable for all decimal configs (L)
- solodit (SOL-010) — safeApprove deprecated, may revert on USDT (M — re-assessed to L)
- trailofbits (TB-10) — MAX_INT permanent allowance (L)
