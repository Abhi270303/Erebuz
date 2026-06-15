# L-07 Missing zero-address checks on Factory constructor and admin setters

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (spec quality)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalFactory`
- **Deployed address:** TBD
- **Source:** source code (verified)
- **Location:** `TropicalFactory.sol:L22, L49, L54, L69, L74`

## Description

The Factory constructor and admin setter functions lack zero-address validation:

- Constructor does not verify `_feeToSetter != address(0)`
- `createPair()` does not verify token addresses are non-zero
- `setFeeTo()` does not verify `_feeTo != address(0)`
- `setFeeToSetter()` does not verify `_feeToSetter != address(0)`

If `feeToSetter` is accidentally set to `address(0)`, all admin functions become permanently disabled. If tokens are registered with zero addresses, pairs will be created that can never hold any tokens.

## Root cause

```solidity
constructor(address _feeToSetter) public {
    feeToSetter = _feeToSetter;  // No zero-address check
}
```

## Impact

- If `feeToSetter` is set to `address(0)`, admin control is permanently lost
- If tokens are registered as `address(0)`, pairs interact with unusable token contracts

## Proof of concept

Not required.

## Recommendation

Add `require(_addr != address(0), "zero address")` to all constructor and setter parameters.

## References

- trailofbits (TB-08) — Missing zero-address checks on admin setter functions (L)
