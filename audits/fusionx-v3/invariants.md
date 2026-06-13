# Invariants — fusionx-v3 (Phase 4)

Status values: enforced (cite file:line) | assumed | MISSING (call out explicitly).

<!-- ===== POOL INVARIANTS (FusionXV3Pool) ===== -->

INV-POOL-01  sqrtPriceX96 must stay within [TickMath.MIN_SQRT_RATIO, TickMath.MAX_SQRT_RATIO]
  enforced-by: FusionXV3Pool.swap() lines 628-634 (price limit checks); TickMath library
  breaks-if:   A swap or initialization sets sqrtPriceX96 outside bounds
  status:      enforced

INV-POOL-02  liquidity must equal sum of net in-range liquidity from all initialized ticks
  enforced-by: LiquidityMath.addDelta in _modifyPosition / swap; Tick.cross updates net
  breaks-if:   Tick bitmap or liquidity delta calculation is incorrect
  status:      enforced

INV-POOL-03  Pool token balances must not decrease due to swaps (net flow: user pays in, receives out)
  enforced-by: Balance check after swap callback, FusionXV3Pool lines 806-814
  breaks-if:   Balance check can be bypassed; callback underpays
  status:      enforced

INV-POOL-04  No tick's liquidityGross may exceed maxLiquidityPerTick
  enforced-by: Tick.update() library — validates maxLiquidityPerTick
  breaks-if:   Tick update validation is incorrect
  status:      enforced

INV-POOL-05  feeGrowthGlobal0X128 and feeGrowthGlobal1X128 are monotonically non-decreasing
  enforced-by: Only += operations in swap() and flash()
  breaks-if:   Overflow wraps around (unlikely at Q128 scale) or subtraction path exists
  status:      enforced

INV-POOL-06  slot0.unlocked reentrancy guard: no two mutating calls may execute simultaneously
  enforced-by: lock modifier on mint/burn/collect/flash; manual unlocked toggle in swap
  breaks-if:   A code path calls out without acquiring the lock
  status:      enforced

INV-POOL-07  Protocol fee rates are bounded: feeProtocol0/1 ∈ {0} ∪ [1000, 4000] (10%-40%)
  enforced-by: FusionXV3Pool.setFeeProtocol() lines 869-871
  breaks-if:   Validation is incorrect or bypassed
  status:      enforced

INV-POOL-08  Flash loans must be fully repaid with fee within the same transaction
  enforced-by: Balance checks after callback, FusionXV3Pool lines 844-845
  breaks-if:   Loan recipient can manipulate token balanceOf()
  status:      enforced

INV-POOL-09  Position tokensOwed are always ≤ actual pool balance of that token at collection time
  enforced-by: Transfer happens after decrementing tokensOwed; pool balance is source of truth
  breaks-if:   Another withdrawal races ahead (prevented by lock)
  status:      assumed

INV-POOL-10  initialize() can only be called once per pool
  enforced-by: require(slot0.sqrtPriceX96 == 0) at line 282
  breaks-if:   State is wiped or reset
  status:      enforced

INV-POOL-11  Only the factory or its owner may set protocol fees, collect protocol fees, or set LM pool
  enforced-by: onlyFactoryOrFactoryOwner modifier (lines 122-124)
  breaks-if:   Modifier logic is incorrect
  status:      enforced

<!-- ===== FACTORY INVARIANTS (FusionXV3Factory) ===== -->

INV-FAC-01  getPool[token0][token1][fee] bidirectional mapping is consistent
  enforced-by: FusionXV3Factory.createPool() lines 76-78 (both directions set)
  breaks-if:   Only one direction is set
  status:      enforced

INV-FAC-02  A fee amount can never be removed once enabled (though it can be disabled via extraInfo)
  enforced-by: No removal function exists; enableFeeAmount() requires 0 pre-existing
  breaks-if:   N/A
  status:      enforced

INV-FAC-03  Only whitelisted addresses may create pools for whitelist-requested fee tiers
  enforced-by: FusionXV3Factory.createPool() lines 71-73
  breaks-if:   Whitelist check is bypassed
  status:      enforced

INV-FAC-04  Only the owner can change fee tier config, whitelist, LM pool deployer, or collect protocol fees
  enforced-by: onlyOwner modifier on admin functions
  breaks-if:   Owner key is compromised
  status:      assumed

<!-- ===== POSITION MANAGER INVARIANTS (NonfungiblePositionManager) ===== -->

INV-NPM-01  Each tokenId maps to exactly one Position with non-zero poolId
  enforced-by: _positions mapping; positions() requires poolId != 0 at line 101
  breaks-if:   Token ID is minted without storing position
  status:      enforced

INV-NPM-02  Position liquidity tracked by NPM equals actual pool liquidity for that position's tick range
  enforced-by: Tracked via pool.burn() returns; updated consistently
  breaks-if:   Pool and NPM state diverge (e.g., direct pool.mint() bypassing NPM)
  status:      assumed

INV-NPM-03  tokensOwed accumulation matches feeGrowthInside difference × position liquidity / Q128
  enforced-by: FullMath.mulDiv calculations in collect(), decreaseLiquidity(), increaseLiquidity()
  breaks-if:   Rounding errors compound or overflow occurs
  status:      enforced

INV-NPM-04  burn() only succeeds when liquidity == 0 AND tokensOwed0 == 0 AND tokensOwed1 == 0
  enforced-by: NonfungiblePositionManager.burn() line 380
  breaks-if:   State check is incorrect
  status:      enforced

INV-NPM-05  Only token owner or approved operator can decrease liquidity, collect, or burn
  enforced-by: isAuthorizedForToken modifier (line 185-188)
  breaks-if:   Modifier logic is incorrect
  status:      enforced

<!-- ===== MASTERCHEF / STAKING INVARIANTS (LBPMasterChefV3) ===== -->

INV-MC-01  totalAllocPoint must equal the sum of all poolInfo[pid].allocPoint
  enforced-by: add() line 275, set() line 315
  breaks-if:   math error in allocPoint update
  status:      enforced

INV-MC-02  fusionXAmountBelongToMC must always be ≤ actual RFUSIONX.balanceOf(this)
  enforced-by: _safeTransfer() and sweepToken() try to preserve this; unchecked blocks used
  breaks-if:   balance < fusionXAmountBelongToMC edge case in _safeTransfer or sweepToken
  status:      MISSING — edge cases in accounting (write a test that pushes balance below tracked amount)

INV-MC-03  Each tokenId can be staked at most once (unique mapping)
  enforced-by: userPositionInfos mapping (1-to-1); pid assigned on deposit
  breaks-if:   Same tokenId can be deposited twice
  status:      enforced

INV-MC-04  rewardGrowthInside is monotonically non-decreasing for each position
  enforced-by: Only assigned from LMPool.getRewardGrowthInside() which grows monotonically
  breaks-if:   LMPool rewardGrowthGlobalX128 decreases
  status:      assumed

INV-MC-05  User can only withdraw/harvest their own positions
  enforced-by: require(positionInfo.user == msg.sender)
  breaks-if:   Ownership check is incorrect
  status:      enforced

INV-MC-06  Pool totalLiquidity equals sum of all staked positions' liquidity
  enforced-by: Updated in updateLiquidityOperation() line 486
  breaks-if:   Position liquidity changes without updateLiquidity() being called
  status:      MISSING — user can modify position liquidity via NPM directly without updating MasterChef

INV-MC-07  Boost multiplier is bounded: [BOOST_PRECISION, MAX_BOOST_PRECISION]
  enforced-by: LBPMasterChefV3.updateLiquidityOperation() lines 498-502
  breaks-if:   FarmBooster returns a value outside bounds and clamping is bypassed
  status:      MISSING — if FARM_BOOSTER returns extreme values, clamping should still hold

INV-MC-08  onERC721Received only accepts NFTs from the known NonfungiblePositionManager
  enforced-by: require(msg.sender == address(nonfungiblePositionManager)) line 336
  breaks-if:   Address check is incorrect
  status:      enforced

<!-- ===== LM POOL INVARIANTS (FusionXV3LmPool) ===== -->

INV-LM-01  lmLiquidity equals sum of net LM liquidity at the current tick
  enforced-by: updatePosition() lines 120-121; crossLmTick() line 91
  breaks-if:   Tick crossing logic is incorrect
  status:      enforced

INV-LM-02  rewardGrowthGlobalX128 is monotonically non-decreasing
  enforced-by: Only += in accumulateReward()
  breaks-if:   Overflow or incorrect duration calculation
  status:      enforced

INV-LM-03  Only the pool can call crossLmTick()
  enforced-by: onlyPool modifier
  breaks-if:   Modifier is bypassed
  status:      enforced

INV-LM-04  Only MasterChef can call updatePosition()
  enforced-by: onlyMasterChef modifier
  breaks-if:   Modifier is bypassed
  status:      enforced

<!-- ===== IFO INVARIANTS (IFOInitializableV3) ===== -->

INV-IFO-01  Pool's totalAmountPool = Σ userInfo[user][pid].amountPool
  enforced-by: depositPool() line 193
  breaks-if:   Race condition allows double-counting
  status:      enforced

INV-IFO-02  User can harvest each pool exactly once
  enforced-by: claimedPool boolean flag
  breaks-if:   Flag is reset
  status:      enforced

INV-IFO-03  totalTokensOffered = Σ poolInfo[pid].offeringAmountPool
  enforced-by: setPool() lines 309-315
  breaks-if:   Pool offering amounts change without updating totalTokensOffered
  status:      enforced

<!-- ===== ROUTER / SLIPPAGE INVARIANTS ===== -->

INV-RTR-01  exactInput swaps must return at least amountOutMinimum
  enforced-by: require() after swap in V3SwapRouter, SwapRouter
  breaks-if:   Slippage check is bypassed
  status:      enforced

INV-RTR-02  exactOutput swaps must not require more than amountInMaximum
  enforced-by: require() after swap in V3SwapRouter, SwapRouter
  breaks-if:   Slippage check is bypassed
  status:      enforced

INV-RTR-03  StableSwapRouter.exactInputStableSwap provides no min-out to the underlying exchange
  enforced-by: IStableSwap(swapContract).exchange(k, j, amountIn_, 0) — hardcoded 0
  breaks-if:   N/A — design choice; outer function enforces amountOutMin
  status:      assumed
