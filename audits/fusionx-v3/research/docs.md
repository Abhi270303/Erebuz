# Docs — fusionx-v3 (Phase 2)

## Mechanism (plain English)
FusionX V3 is a concentrated liquidity AMM (Uniswap V3 fork) on Mantle Network. Users provide liquidity within custom price ranges and earn swap fees. LPs receive NFT representations of their positions. Stakers can deposit LP NFTs into MasterChef for RFUSIONX rewards.

- Zero-fee trading (0.00% maker/taker) on all pairs
- 33.4% of swap fees are protocol-controlled revenue
- 75% of swap fees distributed to LPs
- FSX token planned but not yet deployed
- IFO launchpad for new token offerings
- Pyth Network price oracle integration

## Stated invariants / assumptions (-> invariants.md)
- All in invariants.md (30+ invariants documented)

## Roles & permissions
- Factory Owner: single EOA, controls all pool-level settings, protocol fee collection
- MasterChef Owner: single EOA, controls reward distribution, can pause
- MasterChef Operator: automated keeper for reward accumulation
- MasterChef Receiver: injects RFUSIONX rewards via upkeep
- FarmBooster: external mutable contract for boost multipliers
- LM Pool Deployer: deploys per-pool liquidity mining contracts
- IFO Factory Owner: controls IFO creation and recovery

## External dependencies
- Pyth Network (oracle)
- Chainlink Keepers (automation)
- FusionX V2 (swap routing, migration)
- StableSwap pools (external)
- WETH9/WMNT (native wrapping)
- FarmBooster contract (boost multiplier)
