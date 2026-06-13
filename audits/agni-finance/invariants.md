# Invariants — agni-finance

Status values: enforced (cite file:line) | assumed | MISSING

## Core AMM Invariants

### INV-01 Pool reserves always balance: Σ token0_in = Σ token0_out + fees
- enforced-by: AgniPool.swap() balance check (line 793, 799)
- breaks-if: fee calculation overflow, callback manipulation, reentrancy
- status: ENFORCED (balance checks)

### INV-02 Liquidity token accounting: position.liquidity == sum of all LP positions in a tick range
- enforced-by: Tick.update() cross-referencing + Mint/Burn external exposure
- breaks-if: TickMath overflow in tick range calculation
- status: ASSUMED (same as UniV3)

### INV-03 No free liquidity: mint must transfer tokens, burn must return tokens
- enforced-by: AgniPool.mint() balance check (line 490-491), AgniPool.burn() adds to tokensOwed
- breaks-if: flash loan attack, reentrancy in callback
- status: ENFORCED

### INV-04 Fee growth inside tick range is monotonically non-decreasing
- enforced-by: feeGrowthGlobal0X128/feeGrowthGlobal1X128 only increases in swap() and flash()
- breaks-if: integer underflow in fee computation
- status: ASSUMED

### INV-05 Protocol fee ≤ total swap fee
- enforced-by: AgniPool.swap() line 691: `delta = (step.feeAmount * feeProtocol) / 10000`
- breaks-if: feeProtocol > 10000 (currently set to 3200-3400, max checked is 4000 in setFeeProtocol)
- status: ENFORCED (with max 4000 cap on protocol fee)

### INV-06 Twap oracle ordering: observations are appended in chronological order
- enforced-by: Oracle.sol (standard UniV3)
- breaks-if: block.timestamp manipulation
- status: ASSUMED

## Agni-Specific Invariants

### INV-07 Pool address is deterministic and verifiable
- enforced-by: PoolAddress.computeAddress() using CREATE2
- breaks-if: deployer address changes, init code hash changes
- status: ENFORCED

### INV-08 LM Pool reward accumulation only during swaps
- enforced-by: lmPool.accumulateReward() called inside swap() only (line 633)
- breaks-if: LM pool has external accessor, reentrancy in LM pool
- status: DEPENDS ON LM POOL IMPLEMENTATION

### INV-09 Fee tiers cannot be disabled after being enabled
- enforced-by: enableFeeAmount creates, setFeeAmountExtraInfo can disable via `enabled: false`
- breaks-if: owner can disable fee tiers via setFeeAmountExtraInfo
- status: MISSING — Owner can disable fee tiers after pools exist!

### INV-10 Only whitelisted users create pools in whitelisted fee tiers
- enforced-by: AgniFactory.createPool() whitelist check (line 72)
- breaks-if: owner manages whitelist, tiers can be made whitelist-requested after creation
- status: MISSING — Owner can retroactively enable whitelist requirement on fee tiers

## Economic Invariants

### INV-11 No sandwich attack surface beyond standard AMM protection
- enforced-by: Slippage protection at router level (amountOutMinimum, amountInMaximum)
- breaks-if: high default protocol fees (32-34%) reduce effective LP returns, incentivizing different behavior
- status: ASSUMED (standard AMM protections)

### INV-12 Protocol fee is withdrawn only by factory owner
- enforced-by: onlyFactoryOrFactoryOwner modifier on collectProtocol()
- breaks-if: modifier allows factory AND owner (not just owner)
- status: ENFORCED (but note: both factory and owner can collect)
