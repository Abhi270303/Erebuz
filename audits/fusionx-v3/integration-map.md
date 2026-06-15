# Integration map — fusionx-v3 (Phase 8)

## On-Chain Dependencies

### Internal (file-to-file)
- FusionXV3Pool.swap() → FusionXV3LmPool.crossLmTick() (call — during swap, updates LM tick state)
- FusionXV3Pool.mint()/burn() → LM pool (via setLmPool, if configured)
- LBPMasterChefV3 → NonfungiblePositionManager.increaseLiquidity()/decreaseLiquidity()/collect() (call — via increaseLiquidity/descreaseLiquidity/collectTo)
- LBPMasterChefV3 → FusionXV3LmPool.updatePosition() (call — during stake/harvest)
- LBPMasterChefV3 → FusionXV3LmPool.accumulateReward() (call — during harvest/upkeep)
- LBPMasterChefV3._safeTransfer() → RFUSIONX token (call — reward distribution)
- LBPMasterChefV3.sweepToken() → arbitrary ERC20 (call — admin token recovery)
- V3SwapRouter → FusionXV3Pool.swap() (call — executes swap)
- StableSwapRouter → IStableSwap.exchange() (call — stable swap execution)
- NonfungiblePositionManager → FusionXV3Pool.mint()/burn()/collect() (call — manages LP positions)
- FusionXV3PoolDeployer.deploy() → FusionXV3Factory (CREATE2 — pool creation)
- V3Migrator → FusionXV3Pool.mint()/NonfungiblePositionManager.mint() (call — V2→V3 migration)
- LBPMasterChefV3KeeperV2 → LBPMasterChefV3ReceiverV2.upkeep() (call — automated reward injection)

### External dependencies
- **Tokens (any ERC20)**: Pool tokens — tokens with hooks/rebasing/fee-on-transfer could break invariants
- **WETH9/WMNT**: Native ETH wrapping — trusted
- **Uniswap V2 pairs**: FusionX V2 swaps — trusted fork
- **StableSwap pools**: External contract calls — assumed trusted
- **Chainlink Keepers**: Automated reward upkeep — standard integration
- **FarmBooster contract**: Boost multiplier — HIGH RISK, mutable external contract
- **Pyth Network**: Oracle price feeds — standard integration
- **FusionX V3 Factory**: Pool registry — trusted (own factory)
- **NonfungiblePositionManager**: NFT position management — trusted periphery
- **FusionX V3 Pool Deployer**: CREATE2 pool deployer — trusted

## Off-Chain Dependencies
- **Vercel**: Dapp hosting (fusionx.finance)
- **GitBook**: Documentation hosting (docs.fusionx.finance)
- **Google Tag Manager**: Analytics/tag management (GTM-M4ZNV2G)
- **Google Fonts (fonts.gstatic.com)**: Font CDN
- **assets.fusionx.finance**: Image/CDN assets
- **Medium**: Blog hosting
- **rpc.mantle.xyz**: Public RPC endpoint
- **Mantle block explorer (explorer.mantle.xyz)**: Block explorer
- **Discord, Telegram, Twitter/X**: Community channels
- **GitHub (fusionx-finance)**: Source code hosting (private frontend, public contracts)
- **PancakeSwap frontend**: Fork base — shared vulnerability inheritance 
