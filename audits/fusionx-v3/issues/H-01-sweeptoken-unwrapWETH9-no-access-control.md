# [H] sweepToken and unwrapWETH9 on LBPMasterChefV3 Missing Access Control — Anyone Can Drain Non-RFUSIONX Tokens and ETH

- **Severity:** High
- **Status:** confirmed (POC passes)
- **Invariant broken:** INV-MC-02 (indirect — fusionXAmountBelongToMC tracking is irrelevant for non-RFUSIONX tokens)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`sweepToken`, `unwrapWETH9`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L659-L667` (unwrapWETH9), `L674-L694` (sweepToken)

## Description

`sweepToken()` and `unwrapWETH9()` in `LBPMasterChefV3` lack the `onlyOwner` modifier. Any wallet can call these functions to drain all non-RFUSIONX ERC20 tokens and all WETH/ETH held by the MasterChef contract.

## Root cause

Both functions are declared `external nonReentrant` with **no `onlyOwner` access control**. Compare with every other admin function in the same contract (`setReceiver` at L252, `setLMPoolDeployer` at L259) which all have `onlyOwner`. The `nonReentrant` guard prevents reentrancy but does not restrict who can call the functions.

```solidity
// L659 — NO onlyOwner modifier
function unwrapWETH9(uint256 amountMinimum, address recipient) external nonReentrant {
    uint256 balanceWETH9 = IERC20(WETH).balanceOf(address(this));
    require(balanceWETH9 >= amountMinimum, 'Insufficient WETH9');
    if (balanceWETH9 > 0) {
        IWETH(WETH).withdraw(balanceWETH9);
        TransferHelper.safeTransferETH(recipient, balanceWETH9);
    }
}

// L674 — NO onlyOwner modifier
function sweepToken(address token, uint256 amountMinimum, address recipient) external nonReentrant {
    // ... only RFUSIONX is protected by fusionXAmountBelongToMC tracking
    // All other tokens: transfers entire balance to recipient
}
```

## Impact

- **Direct fund drain:** Any wallet can call `sweepToken(USDC, 0, attacker)` to drain all USDC held by MasterChef
- **ETH drain:** Any wallet can call `unwrapWETH9(0, attacker)` to unwrap and drain all WETH as ETH
- Tokens accumulate in MasterChef via `collectTo()` operations, user refunds, and accidental sends
- **No preconditions:** No special role, no particular state, no capital required

## Attack path / preconditions

1. MasterChef accumulates non-RFUSIONX tokens (USDC, WETH, etc.) through normal operation (`collectTo`, user deposits, fee accumulation)
2. Attacker calls `sweepToken(USDC, 0, attacker)` — drains all USDC
3. Attacker calls `unwrapWETH9(0, attacker)` — drains all WETH as ETH
4. Invariant INV-MC-02 is irrelevant here because the functions treat fusionXAmountBelongToMC as an RFUSIONX-only protection; non-RFUSIONX tokens have no tracking at all

## Proof of concept

**POC: CONFIRMED** — Foundry fork test passes against live Mantle mainnet.

File: `pocs/ExploitPOC.sol` — test `test_H01_sweepToken_anyoneCanCall()` and `test_H01_unwrapWETH9_anyoneCanCall()`.

```
forge test --fork-url https://rpc.mantle.xyz --match-contract ExploitPOC -vvv

Result: 6/6 tests pass, including:
- [PASS] test_H01_sweepToken_anyoneCanCall
- [PASS] test_H01_unwrapWETH9_anyoneCanCall
- [PASS] test_H02_accountingInflation_schematic
- [PASS] test_H02_liveStateAnalysis
- [PASS] test_fullExploitChain
- [PASS] test_M01_NPMincreaseLiquidityNoAuth
```

Live on-chain confirmation:
- MasterChef holds 3,277,909,863,530,384,561,440,850 RFSX
- No `onlyOwner` modifier on either function
- Any wallet can drain all non-RFUSIONX tokens

## Recommendation

Add `onlyOwner` modifier to both functions:

```diff
- function sweepToken(address token, uint256 amountMinimum, address recipient) external nonReentrant {
+ function sweepToken(address token, uint256 amountMinimum, address recipient) external onlyOwner nonReentrant {

- function unwrapWETH9(uint256 amountMinimum, address recipient) external nonReentrant {
+ function unwrapWETH9(uint256 amountMinimum, address recipient) external onlyOwner nonReentrant {
```

Alternatively, add role-based access control if a multi-sig or automation system needs access.

## References

- **Pashov lens:** Lead #1 (HIGH) — sweepToken + unwrapWETH9 no access control
- **Trail of Bits lens:** Lead #1 (HIGH) — sweepToken missing access control; Lead #2 (HIGH) — unwrapWETH9 missing access control
- **Forefy lens:** Lead F-03 (MEDIUM) — sweepToken/transferToken clipping logic
- **Historical:** This is a known anti-pattern in PancakeSwap V3 MasterChef forks — the reference implementation has these gated by onlyOwner
