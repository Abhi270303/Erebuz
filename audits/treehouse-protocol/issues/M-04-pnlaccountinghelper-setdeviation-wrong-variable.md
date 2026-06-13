# M-04: PnlAccountingHelper.setDeviation Checks Old Value Instead of Proposed New Value

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-4 (NAV calculation is manipulation-resistant)
- **Chain / network:** ethereum (chainId 1)
- **Contract:** PnlAccountingHelper
- **Source:** verified
- **Location:** `periphery/PnlAccountingHelper.sol:L128-L132`

## Description

`PnlAccountingHelper.setDeviation()` at line 128-132 contains a wrong-variable bug:

```solidity
function setDeviation(uint16 _newDeviation) external onlyOwner {
    if (deviation > PRECISION) revert DeviationExceeded();  // BUG: checks state variable, not parameter
    emit DeviationUpdated(_newDeviation, deviation);
    deviation = _newDeviation;
}
```

Line 129 checks `deviation` (the current/old state variable) instead of `_newDeviation` (the proposed new value). Since `deviation` initializes to `0` and `PRECISION = 1e4`, the check `0 > 10000` is **always false**. This means:
- The first call with any value (including > 10,000) succeeds
- Subsequent calls also always succeed (because `deviation` is now the value previously set, which could also be > 10,000)

In contrast, the main `PnlAccounting.setDeviation()` at PnlAccounting.sol:L131 correctly checks `if (_newDeviation > PRECISION) revert DeviationExceeded()`.

## Root cause

Copy-paste error: the developer used `deviation` (state variable) instead of `_newDeviation` (function parameter).

## Impact

- The deviation cap (intended max 100% i.e. `PRECISION = 10000`) is completely ineffective in `PnlAccountingHelper`.
- Owner can set deviation to any value including `type(uint16).max = 65535`, allowing the helper's `doAccounting()` to recognize a 655% NAV swing in a single window.
- This bypasses the PnL limiting mechanism for strategy PnL recognition.

## Attack path

This requires the owner role. If the owner is a single EOA or a compromised key:
1. Owner calls `PnlAccountingHelper.setDeviation(65535)` — succeeds despite cap being 10000.
2. `PnlAccountingHelper.maxPnl()` now returns `65535 * lastNav / 10000 = 655%` of lastNav.
3. Any subsequent `PnlAccountingHelper.doAccounting()` call can recognize up to 655% NAV change per window, allowing massive unconstrained IAU minting.

## Proof of concept

```solidity
// Foundry test
PnlAccountingHelper helper = PnlAccountingHelper(deployedHelper);
vm.prank(owner);
helper.setDeviation(65535);
uint maxPnl = helper.maxPnl(); // returns 65535 * lastNav / 10000 — 655% cap
assert(maxPnl > helper.PRECISION()); // cap exceeds 100%
```

## References

- **pashov-004**: PnlAccountingHelper.setDeviation checks wrong variable

## Recommendation

```diff
function setDeviation(uint16 _newDeviation) external onlyOwner {
-   if (deviation > PRECISION) revert DeviationExceeded();
+   if (_newDeviation > PRECISION) revert DeviationExceeded();
    emit DeviationUpdated(_newDeviation, deviation);
    deviation = _newDeviation;
}
```
