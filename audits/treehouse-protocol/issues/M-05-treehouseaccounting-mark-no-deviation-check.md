# M-05: TreehouseAccounting.mark() Has No Deviation Check — Executor Can Mint/Burn Unlimited IAU

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-6 (IAU supply cannot be inflated without corresponding NAV increase)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** TreehouseAccounting, PnlAccounting
- **Source:** verified
- **Location:**
  - `TreehouseAccounting.sol:L71-L83` — `mark()` with no deviation/sanity bounds
  - `PnlAccounting.sol:L64` — deviation check is HERE, not at the accounting target

## Description

`TreehouseAccounting.mark()` is the canonical function that mints or burns IAU to adjust the protocol's mark-to-market position. It is gated by `onlyOwnerOrExecutor` but has **zero bounds checking** on the `_amountLessFee` and `_fee` parameters:

```solidity
function mark(MarkType _type, uint _amountLessFee, uint _fee) external onlyOwnerOrExecutor {
    if (_type == MarkType.MINT) {
        IInternalAccountingUnit(IAU).mintTo(address(this), _fee);
        IERC4626(TASSET).deposit(_fee, treasury);
        IInternalAccountingUnit(IAU).mintTo(TASSET, _amountLessFee);
    } else if (_type == MarkType.BURN) {
        IInternalAccountingUnit(IAU).burnFrom(TASSET, _amountLessFee);
    }
    ...
}
```

The deviation check (0.025% documented / 2.5% actual per window) only exists in `PnlAccounting.doAccounting()`. It is a caller-side guard, not a contract-level constraint. If the caller is the executor (not `PnlAccounting`), there is zero protection:

- **Executor → `TreehouseAccounting.mark(MINT, 1_000_000_000e18, 0)`** → 1 billion IAU minted to TAsset in one transaction.
- **Executor → `TreehouseAccounting.mark(BURN, 1_000_000_000e18, 0)`** → 1 billion IAU burned in one transaction.
- No NAV comparison, no deviation check, no cooldown.

This means the deviation guard is architecturally a **speed bump** that only applies when the `PnlAccounting` helper is used. The executor (set by `onlyOwner`) can bypass it entirely.

Additionally, `PnlAccountingHelper.doAccounting()` at PnlAccountingHelper.sol:L60-L68 also calls `TreehouseAccounting.mark()` directly with only its own deviation check — but as M-04 shows, that check can be bypassed due to a wrong-variable bug.

## Root cause

Security-by-layering failure: the deviation check is implemented at the caller (`PnlAccounting`) rather than at the callee (`TreehouseAccounting.mark()`). Any alternative path to `mark()` bypasses the check.

## Impact

- **Compromised executor = unlimited IAU mint/burn.** The executor role is intended for automated keepers, but if an executor EOA is compromised, the attacker can mint unlimited IAU.
- **Direct share price manipulation:** Minting 1,000,000 IAU to TAsset inflates `totalAssets()` without backing, diluting all existing tETH holders to near-zero value.
- **Burning all IAU from TAsset** deflates share price to zero, potentially locking user funds.

## Attack path

1. Attacker compromises executor key OR executor is a malicious contract.
2. Attacker calls `TreehouseAccounting.mark(MINT, type(uint256).max / 2, 0)`.
3. Massive amount of IAU is minted directly to TAsset.
4. `TAsset.totalAssets()` skyrockets — share price increases.
5. Attacker (holding tETH from prior deposit) redeems for vastly more wstETH than deposited.
6. Vault is drained of real assets.

## Proof of concept

`POC: pending` — Foundry test showing executor calling mark() with arbitrary amounts bypassing all deviation limits.

## References

- **invariant-lead-5**: TreehouseAccounting.mark() has NO deviation check
- **solodit-003**: Unbacked IAU minting via TreehouseAccounting.mark() with manipulable NAV
- **pashov-001** (partial): Same chain, different entry point

## Recommendation

1. **Add deviation/bounds check at `TreehouseAccounting.mark()`:** Every MINT call should verify that the resulting IAU total supply does not exceed the independently-read NAV by more than a small margin. Every BURN call should verify the opposite.

2. **Option A — Add a maxMintable check:**
   ```diff
   function mark(MarkType _type, uint _amountLessFee, uint _fee) external onlyOwnerOrExecutor {
   +    if (_type == MarkType.MINT) {
   +        uint currentNav = NAV_LENS.currentProtocolNav(...); // needs NAV_LENS reference
   +        uint newIauSupply = IERC20(IAU).totalSupply() + _amountLessFee + _fee;
   +        if (newIauSupply > currentNav * MAX_DEVIATION / PRECISION) revert DeviationExceeded();
   +    }
   ```

3. **Option B — Deprecate direct executor access to `mark()`:** Remove the executor's ability to call `mark()` directly; route all mark-to-market through `PnlAccounting.doAccounting()` which has the deviation guard.
