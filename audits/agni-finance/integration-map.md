# Integration map — agni-finance

## Internal (file-to-file)

### Core
- `AgniFactory.createPool()` → `AgniPoolDeployer.deploy()` deploys `AgniPool`
- `AgniFactory.setFeeProtocol()` → `AgniPool.setFeeProtocol()` (onlyFactoryOrFactoryOwner)
- `AgniFactory.collectProtocol()` → `AgniPool.collectProtocol()` (onlyFactoryOrFactoryOwner)
- `AgniFactory.setLmPool()` → `AgniPool.setLmPool()` (onlyFactoryOrFactoryOwner)
- `AgniPoolDeployer.setFactoryAddress()` sets `factoryAddress` (once)
- `AgniPool` reads params from `IAgniPoolDeployer(msg.sender).parameters()` in constructor

### Periphery → Core
- `SwapRouter.exactInputSingle()` → `AgniPool.swap()` via callback
- `SwapRouter.exactInput()` → `AgniPool.swap()` via callback (multi-hop)
- `SwapRouter.exactOutputSingle()` → `AgniPool.swap()` via callback
- `SwapRouter.exactOutput()` → `AgniPool.swap()` via callback (multi-hop)
- `NonfungiblePositionManager.mint()` → `AgniPool.mint()` via `LiquidityManagement.addLiquidity()`
- `NonfungiblePositionManager.increaseLiquidity()` → `AgniPool.mint()`
- `NonfungiblePositionManager.decreaseLiquidity()` → `AgniPool.burn()`
- `NonfungiblePositionManager.collect()` → `AgniPool.burn(0)` + `AgniPool.collect()`

### SmartRouter → Periphery
- `SmartRouter` inherits `AgniRouterV3`, `AgniRouterV2`, `Multicall`, `SelfPermit`
- `AgniRouterV3.agniSwapCallback()` uses `SmartRouterHelper.verifyCallback()` (different from `CallbackValidation.verifyCallback()` used by `SwapRouter`)

## External dependencies
- **Tokens**: WMNT, WETH, USDC, USDT, METH, RUSDY, USDY — Standard ERC20
- **LM Pool (IAgniLmPool)**: Unknown contract, set by factory owner per-pool
- **V2 Factory**: Unknown address (referenced in SmartRouterHelper with different init code hash `0x9f06...`)
- **Graph APIs**: exchange-v3, exchange-v2, launchpad, blocks, project-party-reward subgraphs

## Trust edges
- `factory.owner()` can: setOwner, enableFeeAmount, setWhiteListAddress, setFeeAmountExtraInfo, setLmPoolDeployer, collectProtocol from any pool, setFeeProtocol on any pool, setLmPool on any pool
- `lmPoolDeployer` can: setLmPool on any pool (limited to onlyOwnerOrLmPoolDeployer)
- Pool level protections: `onlyFactoryOrFactoryOwner` modifier (NOT just owner)

## Key Deviations from Standard Uniswap V3

### DEV-01: Default Protocol Fees (CRITICAL)
- `AgniPool.initialize()` sets `feeProtocol` to 3200-3400 (32-34%) depending on fee tier
- Standard UniV3: protocol fee defaults to 0
- Impact: LPs receive 66-68% of expected fees, 32-34% siphoned to protocol

### DEV-02: No `noDelegateCall`
- AgniPool omits the `noDelegateCall` modifier present in standard UniV3Pool
- Could allow delegatecall-based manipulation if pool is called via delegatecall

### DEV-03: Custom Init Code Hash
- `0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a`
- Standard UniV3: `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`
- Indicates pool contract source code has been modified

### DEV-04: Whitelist Fee Tiers
- `feeAmountTickSpacingExtraInfo` mapping with `whitelistRequested` flag
- Only whitelisted users can create pools in certain fee tiers

### DEV-05: LM Pool Integration
- `IAgniLmPool lmPool` state in each pool
- During swap: `lmPool.accumulateReward()` and `lmPool.crossLmTick()` called
- Factory owner can set/change lmPool per pool

### DEV-06: V2 Router Coexistence
- `AgniRouterV2` and V2 init code hash suggest V2-style AMM pools
- `SmartRouter` composites both V2 and V3 routes

### DEV-07: Protocol Fee Collection via Pool
- No `feeTo`/`feeToSetter` in factory (standard UniV3 feature)
- Instead: per-pool `setFeeProtocol()` and `collectProtocol()` via owner
- Owner calls individual pools directly

## Pool Address Computation
- deployer: `0xe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d03`
- initCodeHash: `0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a`
- Formula: `address(uint160(uint256(keccak256(abi.encodePacked(hex'ff', deployer, keccak256(abi.encode(token0, token1, fee)), initCodeHash)))))`
