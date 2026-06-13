# M-02: TreehouseRedemption `_getReturnAmount` Always Rounds Down — Accumulates Dust Over Time

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-04 (Redemption should return fair value to the user)
- **Contract:** TreehouseRedemption, TreehouseRedemptionV2
- **Location:** `TreehouseRedemption.sol:L229-L242`, `TreehouseRedemptionV2.sol:L220-L233`

## Description

The `_getReturnAmount` function performs integer division which rounds DOWN in all cases:

```solidity
return (_minC * (_b0 > _bn ? _bn : _b0)) / _maxC;
```

Since `_minC <= _maxC`, the result is always truncated down. Additionally, the subsequent fee calculation `(_returnAmount * redemptionFee) / PRECISION` also rounds down due to integer division. This means:
1. The user's return is rounded down twice (once in `_getReturnAmount`, once in fee computation)
2. The rounding error per redemption is at most a few wei, but it compounds over time

## Root cause

Solidity integer division truncates (rounds toward zero). The `_getReturnAmount` formula divides `_minC * amount` by `_maxC`, which always rounds down. The fee computation also rounds down, giving a small bonus to the protocol.

## Impact

- Each redemption loses 1-2 wei to rounding, which accumulates in the remaining TAsset/IAU pool.
- Over thousands of redemptions, this could accumulate to a meaningful amount.
- The rounding always favors the protocol, never the user — this is an asymmetry.

## Attack path / precondition

No special precondition — this happens on every redemption:
1. User calls `redeem(1000 shares)` -> `_assets = 1000 IAU` -> stored
2. User calls `finalizeRedeem(index)` 7 days later
3. `_getReturnAmount(1000, c0, 1000, cn)` where c0 < cn
4. Example: `_returnAmount = (1.2e18 * 1000e18) / 1.200000000000000001e18 = 999,999,999,999,999,999` (1 wei lost)
5. Fee: `(999999999999999999 * fee) / 10000` — another 1 wei rounding loss possible
6. The lost wei remains in TAsset as extra value for remaining holders

## Proof of concept

```
c0 = 1200000000000000000 (1.2e18)
cn = 1200000000000000001 (1.2e18 + 1)
b0 = bn = 1000000000000000000 (1e18)
return = (1200000000000000000 * 1000000000000000000) / 1200000000000000001
       = 999,999,999,999,999,999 (1 wei lost)
```

## Recommendation

Round in favor of the user by adding `_maxC - 1` before dividing:
```diff
- return (_minC * (_b0 > _bn ? _bn : _b0)) / _maxC;
+ // Round up in favor of the user
+ uint numerator = _minC * (_b0 > _bn ? _bn : _b0);
+ return (numerator + _maxC - 1) / _maxC;
```
