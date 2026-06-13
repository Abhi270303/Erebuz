# Invariants — init-capital (audit complete)

Status values: enforced (cite file:line) | assumed | MISSING (call out explicitly) | **BROKEN** (verified via PoC).

> **Note:** INV-03 and INV-08 are marked **BROKEN** — these are the root cause of CRIT-001 (confirmed by all 4 audit agents). The `callback()` and `multicall()` functions lack `nonReentrant` guards, enabling unbounded reentrancy with deferred health checks. A Foundry PoC is at `pocs/CallbackReentrancy.t.sol`.

## Position Health & Multicall

INV-01  Position health >= 1e18 after every non-multicall state change (borrow, decollateralize, setPosMode).
  enforced-by: `InitCore.sol:71` — `ensurePositionHealth` modifier checks `_isPosHealthy` when `!isMulticallTx`.
  breaks-if:   A borrow or decollateralize succeeds when the position would be left unhealthy outside a multicall.
  status:      enforced (InitCore.sol:71)

INV-02  ALL positions that were modified during a multicall batch have their health checked before the batch completes.
  enforced-by: `InitCore.sol:402-407` — loop over `uncheckedPosIds` runs health check after `super.multicall(data)`.
  breaks-if:   An `uncheckedPosIds` entry is not cleared or the loop is skipped.
  status:      enforced (InitCore.sol:402-407)

INV-03  The `callback()` function may not be called during a context protected by `nonReentrant`.
  enforced-by: NONE — `callback()` at `InitCore.sol:512` has NO `nonReentrant` modifier.
  breaks-if:   An attacker calls `callback()` from inside `flashCallback`, `borrow`, `liquidate`, or any other nonReentrant function, manipulating state mid-execution.
  status:      **BROKEN** — CRIT-001. PoC: `pocs/CallbackReentrancy.t.sol`

INV-04  `multicall()` reverts entirely if any sub-call fails.
  enforced-by: `Multicall.sol:17` — `require(success)` immediately reverts the entire batch.
  breaks-if:   A sub-call partially modifies state before reverting (not possible with `delegatecall`).
  status:      enforced (Multicall.sol:17)

INV-05  Flash loan may not be called inside a multicall batch.
  enforced-by: `InitCore.sol:372` — `_require(!isMulticallTx, LOCKED_MULTICALL)` in `flash()`.
  breaks-if:   A flash loan is attempted with `isMulticallTx == true`.
  status:      enforced (InitCore.sol:372)

## Lending Pool Accounting

INV-06  LendingPool `totalAssets() == cash + totalDebt` always holds.
  enforced-by: `LendingPool.sol:224-226`.
  breaks-if:   `cash` or `totalDebt` is updated without updating the other consistently.
  status:      enforced by design (LendingPool.sol:224-226)

INV-07  LendingPool `cash` tracks the pool's actual underlying token balance.
  enforced-by: ∆-balance pattern in `mint()` (LendingPool.sol:103) and `burn()` (LendingPool.sol:119).
  breaks-if:   A donation directly to the LendingPool contract inflates balance without updating `cash`; OR a fee-on-transfer token causes the received amount to differ from `balanceOf(this)` delta.
  status:      assumed — breaks for fee-on-transfer tokens (documented: "rebase token is not supported")

INV-06b `multicall()` must be protected by `nonReentrant` to prevent reentrancy from callbacks.
  enforced-by: NONE — `multicall()` at `InitCore.sol:396` has NO `nonReentrant` modifier.
  breaks-if:   An attacker calls `callback()` during a multicall batch, re-enters the core, and calls nonReentrant functions (borrow, liquidate, etc.) which pass because `multicall()` never sets `_status = _ENTERED`.
  status:      **BROKEN** — CRIT-001. PoC: `pocs/CallbackReentrancy.t.sol`

INV-08  Pool total supply after mint does not exceed `supplyCap`.
  enforced-by: `InitCore.sol:106` — `_require(ILendingPool(_pool).totalAssets() <= poolConfig.supplyCap, ...)`.
  breaks-if:   `supplyCap` is bypassed or `totalAssets()` is manipulated.
  status:      enforced (InitCore.sol:106)

INV-09  Pool total debt after borrow does not exceed `borrowCap`.
  enforced-by: `InitCore.sol:140` — `_require(ILendingPool(_pool).totalDebt() + _amt <= poolConfig.borrowCap, ...)`.
  breaks-if:   `borrowCap` is bypassed.
  status:      enforced (InitCore.sol:140)

INV-10  Flash loan repayment: every pool's token balance after callback >= balance before.
  enforced-by: `InitCore.sol:390-392` — `_require(IERC20(tokens[i]).balanceOf(_pools[i]) >= balanceBefores[i], ...)`.
  breaks-if:   Balance check is bypassed or wrong token checked.
  status:      enforced (InitCore.sol:390-392)

## Debt Share Consistency

INV-11  Position debt shares per pool in PosManager == sum of debt shares for that pool across all positions.
  enforced-by: Only updated atomically in `updatePosDebtShares()` (PosManager.sol:181), called during borrow/repay/setPosMode only.
  breaks-if:   An update misses a position, or a direct external call modifies PosManager storage without going through `onlyCore`.
  status:      assumed — no on-chain cross-reference to verify the sum.

INV-12  Mode debt shares in RiskManager == sum of position debt shares across all positions in that mode (per pool).
  enforced-by: `RiskManager.updateModeDebtShares()` (RiskManager.sol:70) called in tandem with `PosManager.updatePosDebtShares()` in borrow/repay/setPosMode.
  breaks-if:   The two delta updates diverge (e.g., one succeeds, other reverts), or setPosMode fails to transfer debt shares between modes correctly.
  status:      MISSING — no atomic check ensures PosManager debt == RiskManager debt per mode+pool.

INV-13  Mode debt (in underlying terms) does not exceed the mode debt ceiling.
  enforced-by: `RiskManager.updateModeDebtShares()` (RiskManager.sol:74-75) — `_require(currentDebt <= debtCeilingInfo.ceilAmt, ...)` when `_deltaShares > 0`.
  breaks-if:   `debtShareToAmtCurrent` rounds in a way that underestimates debt, or `ceilAmt` is not set.
  status:      enforced (RiskManager.sol:74-75)

## Rounding & Share Math

INV-14  Debt share issuance (`borrow()`) always rounds UP — protocol never issues fewer shares than the exact debt amount warrants.
  enforced-by: `LendingPool.sol:129` — `_amt.mulDiv(totalDebtShares, _totalDebt, Rounding.Up)`.
  breaks-if:   Rounding direction changes to DOWN.
  status:      enforced (LendingPool.sol:129)

INV-15  Debt repayment asset amount (`repay()`) always rounds UP — protocol never accepts less underlying than shares represent.
  enforced-by: `LendingPool.sol:143` — `_shares.mulDiv(_totalDebt, _totalDebtShares, Rounding.Up)`.
  breaks-if:   Rounding direction changes to DOWN.
  status:      enforced (LendingPool.sol:143)

INV-16  Deposit shares (`_toShares`) always rounds DOWN — depositor receives at most their fair share.
  enforced-by: `LendingPool.sol:256` — `_amt.mulDiv(_totalShares + VIRTUAL_SHARES, _totalAssets + VIRTUAL_ASSETS)` (rounds down by default).
  breaks-if:   Rounding direction changes to UP.
  status:      enforced (LendingPool.sol:256)

INV-17  Withdrawal assets (`_toAmt`) always rounds DOWN — withdrawer receives at most their fair share.
  enforced-by: `LendingPool.sol:266` — `_shares.mulDiv(_totalAssets + VIRTUAL_ASSETS, _totalShares + VIRTUAL_SHARES)` (rounds down by default).
  breaks-if:   Rounding direction changes to UP.
  status:      enforced (LendingPool.sol:266)

INV-18  Virtual shares protect against first-depositor inflation attack: share price is bounded by VIRTUAL_ASSETS=1 and VIRTUAL_SHARES=1e8.
  enforced-by: `LendingPool.sol:255-267` — OZ ERC4626 inflation protection pattern.
  breaks-if:   Virtual constants are changed or the formula is altered.
  status:      assumed (LendingPool.sol:255-267)

## Access Control

INV-19  Only InitCore may call `onlyCore`-protected functions in LendingPool, PosManager, and RiskManager.
  enforced-by: Each contract stores `core` as immutable and checks `_require(msg.sender == core, NOT_INIT_CORE)`.
  breaks-if:   `core` address is wrong (constructor parameter) or the modifier is missing on any function.
  status:      enforced (LendingPool.sol:52, PosManager.sol:49, RiskManager.sol:34)

INV-20  Only the position owner or approved addresses may modify a position (borrow, repay, collateralize, decollateralize, setPosMode).
  enforced-by: `InitCore.sol:62-64` — `onlyAuthorized` modifier checks `PosManager.isAuthorized(msg.sender, _posId)`.
  breaks-if:   A function that modifies position state is callable without the modifier.
  status:      enforced (InitCore.sol:62-64)

INV-21  `liquidate()` and `liquidateWLp()` have no access control — any caller may liquidate any unhealthy position.
  enforced-by: `InitCore.sol:288` — no `onlyAuthorized` modifier on `liquidate()`.
  breaks-if:   N/A — this is a deliberate permissionless design.
  status:      assumed

## Position Constraints

INV-22  A position's collateral count (ERC20 + wLp) must not exceed `maxCollCount`.
  enforced-by: `PosManager.sol:222` (addCollateral) and `PosManager.sol:239` (addCollateralWLp).
  breaks-if:   A code path adds collateral without checking the count.
  status:      enforced (PosManager.sol:222, 239)

INV-23  A position's wLp count must not exceed the mode's `maxCollWLpCount`.
  enforced-by: `InitCore.sol:265` — `_validateModeMaxWLpCount()` called after `collateralizeWLp`.
  breaks-if:   `collateralizeWLp` is called without validation.
  status:      enforced (InitCore.sol:265)

INV-24  Post-liquidation health must not exceed `maxHealthAfterLiq_e18` for the position's mode (unless set to `type(uint64).max`).
  enforced-by: `InitCore.sol:570-578` (both `liquidate` and `liquidateWLp`).
  breaks-if:   `maxHealthAfterLiq_e18` is not checked when health is 0 (bad debt case exempted by design).
  status:      enforced (InitCore.sol:570-578), with bad-debt exemption

INV-25  Position mode != 0 (zero mode is reserved/invalid).
  enforced-by: `Config.sol:106` — `_require(_mode != 0, INVALID_MODE)` in setCollFactors.
  breaks-if:   A position is created with mode 0.
  status:      enforced (Config.sol:106, PosManager.sol:293)
