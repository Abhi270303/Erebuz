# H-02: NAV Inflation via Forced ETH → Unbacked IAU Minting → Vault Drain

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** INV-4 (NAV calculation is manipulation-resistant), INV-6 (IAU supply integrity)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** NavErc20, NavErc20WithDebt, PnlAccounting, TreehouseAccounting, Vault, TreehouseFastlane
- **Source:** verified
- **Location:**
  - `modules/nav/NavErc20.sol:L38` — native ETH balance read
  - `modules/nav/NavErc20.sol:L58` — ETH→stETH→wstETH conversion path
  - `periphery/PnlAccounting.sol:L17` — `PRECISION = 1e4` (not 1e6 as documented)
  - `periphery/PnlAccounting.sol:L33` — `deviation = 250 // 1e6 base. 250 == 0.025%` (comment contradicts code)
  - `periphery/PnlAccounting.sol:L80-L82` — `maxPnl = (250 * lastNav) / 10000 = 2.5%` (not 0.025%)
  - `TreehouseAccounting.sol:L71-L83` — `mark()` with no deviation check
  - `Vault.sol:L42` — inherits `Rescuable`, no `receive()/fallback()` — accepts forced ETH
  - `Strategy.sol:L30-L32` — `receive() external payable` — strategies accept ETH
  - `TreehouseFastlane.sol` — instant redemption for inflated tETH

## Description

A multi-step exploit chain allows converting artificially inflated NAV into real wstETH drained from the Vault. The chain combines four independent issues:

**Issue A — Forced ETH inflates NAV (3 agents: pashov, trailofbits, invariant):**
`NavErc20.nav()` at line 38 reads `_target.balance` (native ETH) and adds it directly to the NAV accumulator, treating it as stETH-equivalent. At line 58, the total is converted to wstETH via `getWstETHByStETH(_nav)`. Since the Vault contract has no `receive()`/`fallback()`, it cannot reject native ETH sent via `selfdestruct(VAULT)`. This ETH is counted as if it were stETH, inflating `vaultNav()` → `currentProtocolNav()`.

`NavErc20WithDebt.nav()` has the same `_target.balance` read at line 49 for strategy NAV computation. Strategy contracts have `receive() external payable`, so they also accept forced ETH.

**Issue B — Deviation guard is 100× larger than documented (2 agents: pashov, invariant):**
`PnlAccounting` documents: `deviation = 250; // 1e6 base. 250 == 0.025%`. However, `PRECISION = 1e4`, not 1e6. The actual computation is:
```solidity
maxPnl = (250 * lastNav) / 10000 = 2.5% of lastNav
```
This is **2.5% per window**, not the documented 0.025%. At the default 1-hour cooldown, up to ~80% NAV inflation can be recognized by `doAccounting()` in 24 hours (compounding: 1.025^24 ≈ 1.809). If the cooldown is set to the minimum 60 seconds, 2.5% can be minted every 60 seconds.

**Issue C — `TreehouseAccounting.mark()` has zero deviation check (3 agents: invariant, solodit, pashov):**
The deviation check (Issue B) only exists in `PnlAccounting.doAccounting()`. `TreehouseAccounting.mark()` at line 71 is gated only by `onlyOwnerOrExecutor` and accepts arbitrary `_amountLessFee` and `_fee` parameters with no bounds whatsoever. The executor can bypass the deviation limit entirely by calling `mark()` directly.

**Issue D — Inflated tETH can be redeemed for real assets (all agents):**
Excess IAU is minted to TAsset, inflating the tETH exchange rate (since `IAU.balanceOf(TASSET)` = `TAsset.totalAssets()` increases). Any tETH holder (including the attacker, who acquires tETH beforehand) can redeem inflated tETH for real wstETH from the Vault via `TreehouseFastlane.redeemAndFinalize()` (instant) or `TreehouseRedemptionV2.finalizeRedeem()` (7-day wait).

## Root cause

Three root causes combine:
1. **`_target.balance`** in NAV calculation is an uncontrolled input — anyone can force ETH to any address via `selfdestruct`.
2. **Precision mismatch**: `PRECISION = 1e4` vs documented `1e6` base makes deviation guard 100× looser than stated.
3. **No deviation guard at `mark()` level**: the protection is at the wrong architectural layer.

## Impact

- **Path A (keeper-driven):** Attacker force-sends ETH to Vault (~0.001 ETH gas cost). If an automated keeper calls `doAccounting()` hourly, up to ~2.5% of `lastNav` in excess IAU is minted per hour. Over 24 hours: ~80% NAV inflation. The attacker converts tETH to wstETH via Fastlane, draining real assets from the Vault.
- **Path B (executor/owner-driven):** Executor calls `TreehouseAccounting.mark(MINT, arbitraryAmount, 0)` directly — no deviation check. Unlimited IAU minted in one transaction. All tETH instantly redeemable for all Vault wstETH.
- **Real-world impact:** The attacker's profit = `(inflatedSharePrice - originalSharePrice) * attackerTHolding - selfdestructCost`. With sufficient leverage, this is a positive-sum extraction game.

## Attack path

### Path A (via keeper doAccounting):
1. Attacker deploys a selfdestruct contract with some ETH and sets Vault as the beneficiary.
2. Attacker calls `selfdestruct(VAULT)` — gas cost ~0.001 ETH.
3. Vault now has `n` wei of native ETH that was not deposited through the Router.
4. Attacker acquires tETH via `TreehouseRouter.deposit()` (legitimate deposit) or already holds tETH.
5. Automated keeper calls `PnlAccounting.doAccounting()` — `currentNav > lastNav` due to the phantom ETH.
6. `deviation` check passes (2.5% × lastNav ≥ `currentNav - lastNav` if the forced ETH ≤ 2.5%).
7. `TreehouseAccounting.mark(MINT, netPnl, fee)` is called — IAU is minted to TAsset.
8. `TAsset.totalAssets()` increases → tETH share price increases.
9. Attacker calls `TreehouseFastlane.redeemAndFinalize(shares)` — gets more wstETH than legitimate.
10. Steps 5-9 repeat every hour until Vault wstETH is drained or deviation budget is exhausted.

### Path B (via direct executor mark):
1. Attacker colludes with executor OR executor key is compromised.
2. Executor calls `TreehouseAccounting.mark(MINT, type(uint256).max / 2, 0)` directly.
3. Unlimited IAU minted to TAsset in one transaction.
4. Attacker immediately redeems all tETH for all Vault wstETH via Fastlane.
5. Protocol is drained in one block.

## Proof of concept

`POC: pending` — Foundry fork test required to demonstrate:
1. Deploy selfdestruct contract → send ETH to Vault
2. Call `NavLens.currentProtocolNav()` and verify increase
3. Call `PnlAccounting.doAccounting()` with keeper role
4. Verify `IAU.totalSupply()` increased without real backing
5. Redeem tETH for wstETH via Fastlane
6. Verify Vault wstETH balance decreased more than the attacker's legitimate deposit

## References

- **pashov-001**: Forced-ETH + deviation precision mismatch
- **pashov-002**: NavErc20WithDebt same forced-ETH inflation
- **trailofbits-02**: NAV inflation via forced ETH
- **invariant-lead-2**: NavErc20.nav() _target.balance manipulation
- **invariant-lead-5**: TreehouseAccounting.mark() has NO deviation check
- **invariant-lead-6**: Deviation comment/code mismatch
- **solodit-002**: NAV manipulation via donation
- **solodit-003**: Unbacked IAU minting via mark()

## Recommendation

1. **Remove native ETH from NAV calculation** — `NavErc20.nav()` should skip `_target.balance`. The Vault should never hold native ETH.
2. **Fix `PRECISION` to match documentation**: Change `PRECISION` to `1e6` or update `deviation` to `2500` (2.5% in 1e4 base) and fix the comment.
3. **Add deviation check at `TreehouseAccounting.mark()` level**: Every `mark()` call should verify the IAU supply movement is reasonable relative to an independent NAV reading.
4. **Add sanity check for vault native ETH before doAccounting**: Revert if `address(vault).balance > 0`.
