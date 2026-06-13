# Invariants — lendle-pooled-markets (Phase 4)

Status values: enforced (cite file:line) | assumed | MISSING (call out explicitly).

## Solvency / Health Factor

INV-01  For every user with debt, healthFactor >= 1e18 (1.0)
  enforced-by: ValidationLogic.validateBorrow(), validateWithdraw() via balanceDecreaseAllowed(), validateTransfer()
  breaks-if:   oracle price manipulation, index overflow, liquidation race conditions
  status:      MISSING — only checked in specific paths, not guaranteed globally

INV-02  totalDebtETH for a reserve must never exceed totalCollateralETH × maxLTV across all users
  enforced-by: ValidationLogic.validateBorrow() (L167-183)
  breaks-if:   LTV changed while positions are open, oracle manipulation
  status:      assumed (per-user check at borrow time)

INV-03  aToken totalSupply cannot exceed sum of scaled balances × liquidityIndex (no inflation)
  enforced-by: AToken.mint() and AToken.burn() via onlyLendingPool
  breaks-if:   index overflow, rounding error accumulation
  status:      assumed

INV-04  liquidityIndex and variableBorrowIndex must be >= 1e27 and monotonically increasing
  enforced-by: ReserveLogic._updateIndexes() (L347-367)
  breaks-if:   underflow in MathUtils interest calculations
  status:      enforced

INV-05  scaledTotalSupply × liquidityIndex must fit in uint256 (capped at uint128 for indices)
  enforced-by: ReserveLogic requires <= type(uint128).max after index update (L351-364)
  breaks-if:   extreme interest accumulation
  status:      enforced

## Oracle

INV-06  updateAssetPrice(asset) and getAssetPrice(asset) must return the same price for the same asset at the same block
  enforced-by: (none — they call different code paths)
  breaks-if:   Pyth oracle degrades; updatePrice writes lastGoodPrice but fetchPrice may differ
  status:      MISSING — AaveOracle.updateAssetPrice() calls source.updatePrice() → writes lastGoodPrice;
               AaveOracle.getAssetPrice() calls source.fetchPrice() → view-only, returns lastGoodPrice only when untrusted
               Source: contracts/misc/AaveOracle.sol L52-63; contracts/misc/PythPriceFeed.sol L95-133

INV-07  Pyth price must not deviate more than 50% from previous round (MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND)
  enforced-by: (none — constant defined but never checked)
  breaks-if:   any Pyth update with >50% deviation
  status:      MISSING — MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND = 5e17 defined at PythPriceFeed.sol L30 but never referenced in any require()

## Access Control

INV-08  Only LendingPool can mint/burn aTokens and debt tokens
  enforced-by: onlyLendingPool modifier on AToken.sol L46-48, VariableDebtToken via DebtTokenBase L31-34,
               StableDebtToken via DebtTokenBase L31-34
  breaks-if:   implementation upgrade that removes the modifier
  status:      enforced

INV-09  Only PoolAdmin can change reserve configuration (LTV, liq params, freeze, etc.)
  enforced-by: onlyPoolAdmin modifier on LendingPoolConfigurator L37-39
  breaks-if:   poolAdmin key compromised
  status:      enforced

INV-10  Only EmergencyAdmin can pause/unpause the LendingPool
  enforced-by: onlyEmergencyAdmin modifier on LendingPoolConfigurator.setPoolPause() L42-48, L456-458
  breaks-if:   emergencyAdmin key compromised
  status:      enforced

## Reentrancy

INV-11  LendingPool must not be re-entered during flashLoan execution
  enforced-by: (NONE — no nonReentrant modifier)
  breaks-if:   receiver.executeOperation() re-enters deposit/borrow/withdraw/repay
  status:      MISSING — LP_REENTRANCY_NOT_ALLOWED error defined in Errors.sol L89 but never used

INV-12  IncentivizedERC20 token transfers must not trigger reentrancy into LendingPool
  enforced-by: (NONE)
  breaks-if:   ChefIncentivesController.handleAction() → onwardIncentives.handleAction() → external contract → re-enter LendingPool
  status:      MISSING — external call at ChefIncentivesController.sol L242

## Staking

INV-13  MultiFeeDistribution: totalSupply must equal sum(balances[user].total) for all users
  enforced-by: (NONE)
  breaks-if:   withdraw() double-subtracts bal.earned (L363 + L370)
  status:      MISSING — confirmed double-subtraction bug in MultiFeeDistribution.withdraw()

INV-14  MultiFeeDistribution: bal.earned must never be subtracted twice in a single withdraw()
  enforced-by: (NONE)
  breaks-if:   L363 bal.earned = bal.earned.sub(remaining) AND L370 bal.earned = bal.earned.sub(remaining)
  status:      MISSING — MultiFeeDistribution.sol L363 and L370 both subtract from bal.earned

INV-15  MerkleDistributor: state must not be mutated before merkle proof verification
  enforced-by: (NONE — EVM revert protects atomicity but pattern is risky)
  breaks-if:   any split-second race or future code change
  status:      assumed — state written at L113-117 before verify at L121, but EVM revert rolls back

## Token

INV-16  aToken: balanceOf(user) = scaledBalanceOf(user) × liquidityIndex
  enforced-by: AToken.balanceOf() L217
  status:      enforced

INV-17  VariableDebtToken: balanceOf(user) = scaledBalanceOf(user) × variableBorrowIndex
  enforced-by: VariableDebtToken.balanceOf() L82
  status:      enforced
