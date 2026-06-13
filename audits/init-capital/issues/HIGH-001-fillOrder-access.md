# HIGH-001: `MarginTradingHook.fillOrder()` — No Access Control, No Reentrancy Guard

**Severity:** HIGH
**Bug Class:** Access Control / Reentrancy
**Confidence:** HIGH (3 agents: Pashov, Trail of Bits, Forefy)

## Affected Contract

`hook/MarginTradingHook.sol:373–401` (`fillOrder()`)

## Description

`fillOrder()` has **no access control** (any wallet can fill any active order) and **no `nonReentrant` modifier**. The function:

1. Validates the trigger price (`_validateTriggerPrice`, line 386)
2. Computes fill amounts (`_calculateFillOrderInfo`, line 388)
3. Updates order status to `Filled` (line 390)
4. Transfers repayment tokens from `msg.sender` via `safeTransferFrom` (line 392)
5. Calls `CORE.repay()` and `CORE.decollateralize()` (lines 395–397)
6. Sends collateral to `msg.sender`

The collateral transfer goes to `msg.sender` — any wallet that calls `fillOrder()` receives the liquidated collateral. This means MEV searchers can:
- Monitor for stop-loss/take-profit orders
- Front-run order fills by calling `fillOrder()` themselves at an unfavorable price for the order owner
- Extract value through oracle price manipulation between trigger validation and execution

## Impact

- **MEV extraction:** Searchers can front-run order fills and extract the difference between trigger price and execution price
- **Reentrancy:** No `nonReentrant` means an attacker can re-enter `fillOrder()` for a different order during `safeTransferFrom` if the token has hooks (ERC777)
- **Unauthorized fills:** Any wallet can fill any order at any time, bypassing the order owner's intended fill conditions

## Mitigation

Add `nonReentrant` modifier and restrict order filling to the order owner or a whitelisted keeper role.
