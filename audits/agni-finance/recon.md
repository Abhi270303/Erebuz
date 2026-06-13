# Recon — agni-finance (Phase 1)

## Source
- DefiLlama slug: agni-finance
- Category: DEX / CLMM
- Chain: Mantle (chain ID 5000)
- Deployer: 0xD8A4c759bC19cC3E90e7151f0ccfb3120175ee27

## Contracts
| address | chain | role | proxy? | deploy block |
|---------|-------|------|--------|-------------|
| 0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035 | mantle | AgniFactory | no | 35714 |
| 0xe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d03 | mantle | AgniPoolDeployer | no | |
| 0x218bf598D1453383e2F4AA7b14fFB9BfB102D637 | mantle | NonfungiblePositionManager | no | |
| 0x319B69888b0d11cEC22caA5034e25FfFBDc88421 | mantle | SwapRouter | no | |
| 0xB52b1F5e08c04a8c33F4C7363fa2DE23B9BC169f | mantle | SmartRouter | no | |
| 0x9488C05a7b75a6FefdcAE4f11a33467bcBA60177 | mantle | Quoter | no | |
| 0xc4aaDc921E1cdb66c5300Bc158a313292923C0cb | mantle | QuoterV2 | no | |
| 0xEcDbA665AA209247CD334d0D037B913528a7bf67 | mantle | TickLens | no | |
| 0x70153a35c3005385b45c47cDcfc7197c1a22477a | mantle | NFTDescriptor | no | |
| 0xcb814b767D41b4BD94dA6Abb860D25b607ad5764 | mantle | NonfungibleTokenPositionDescriptor | no | |
| 0xBE592EFcF174b3E0E4208DC8c1658822d017568f | mantle | AgniInterfaceMulticall | no | |
| 0xcdbd1c6cfc89Af8a518E23B0C71996B90a12Befc | mantle | mixedRouteQuoterV1 | no | |
| 0xb0Bcbe0d2B197b7a8Fb7e66d6a0dD6a91cB985d6 | mantle | smartRouterHelper | no | |
| 0x05f3105fc9FC531712b2570f1C6E11dD4bCf7B3c | mantle | Multicall3 | no | |
| 0x0B0BDCFB1Cc30C80A8fE507516943557766fEC0c | mantle | GasLimitMulticall | no | |

## Tokens
| address | symbol |
|---------|--------|
| 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8 | WMNT |
| 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE | USDT |
| 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 | USDC |
| 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111 | WETH |
| 0xcda86a272531e8640cd7f1a92c01839911b90bb0 | METH |
| 0xab575258d37eaa5c8956efabe71f4ee8f6397cf3 | RUSDY |
| 0x5bE26527e817998A7206475496fDE1E68957c5A6 | USDY |

## Known Pools
| Pool | Fee | Tick Spacing | Address |
|------|-----|-------------|---------|
| WMNT/WETH | 0.05% (500) | 10 | 0x54169896d28deC0ffABE3b16f90f71323774949f |
| WMNT/WETH | 1% (10000) | 200 | 0x9d5d4064a808ba865957b1d04b20a84175dcc16d |
| WMNT/WETH | 0.01% (100) | 1 | 0x928981fe5a4c005a126662d2bd84fbf139b51876 |
| WMNT/WETH | 0.3% (3000) | 60 | 0x9ec313ff05946b6f3860a99b470625abba7eb0a2 |
| USDC/WMNT | 0.05% (500) | 10 | 0x1858d52cf57c07A018171D7a1E68DC081F17144f |
| USDC/WMNT | 1% (10000) | 200 | 0x8E2C009E45420D2B36bC15315F9de8CeCa2cc724 |
| USDC/WETH | 0.3% (3000) | 60 | 0xd34292f7585ac5a518c5ceb2d674d1423ad0569f |
| USDC/WETH | 0.05% (500) | 10 | 0xee12e312878b74b2c17d80516128d7868f80365b |
| USDC/WETH | 0.01% (100) | 1 | 0x2bd0f40c241eabd326545a6467bb2da88bb46181 |
| WMNT/USDT | 0.05% (500) | 10 | 0xD08C50F7E69e9aeb2867DefF4A8053d9A855e26A |
| WMNT/USDT | 1% (10000) | 200 | 0xB1aB8372d62BF35e655477568BDb72F32b13738f |
| WMNT/USDT | 0.3% (3000) | 60 | 0x8F99892C84D4E4af62082ebAFB7d0D033938D26e |
| USDC/USDT | 0.01% (100) | 1 | 0x6488f911c6cd86c289aa319c5a826dcf8f1ca065 |
| USDT/WETH | 0.01% (100) | 1 | 0xd145db1dfc3fcd2e999b47f3a02c85bd7750ed09 |
| USDT/WETH | 0.05% (500) | 10 | 0x628f7131cf43e88ebe3921ae78c4ba0c31872bd4 |
| USDT/WETH | 0.3% (3000) | 60 | 0x425732f412f2a922156cf3c135a516c18f977cc1 |
| USDT/WETH | 1% (10000) | 200 | 0x46e15789bd1eeb975551ea12f3eb74ae9409eb99 |
| USDT/WETH | 0.01% (100) | 1 | 0xd372cd4acfcd646f9332b26c7b6bfa4777d90451 |
| USDC/WMNT | 0.01% (100) | 1 | 0x7b3a4b36b0c5c95142afcd1b883ed055aa166f85 |
| USDC/WETH | 1% (10000) | 200 | 0xe1dc93d69439a924baaeaf9e64f4ae7be0af738a |
| USDC/WMNT | 0.3% (3000) | 60 | 0x9cae9b5d0ee7e78dfd7e42fd995d4974d6907242 |
| WMNT/mETH | 1% (10000) | 200 | 0xb1846d1cae9bb86793d5a20dec2f85937a739bdb |
| WMNT/FBTC | 1% (10000) | 200 | 0xbc322fa291cf9d5015bc1698aa57ba64a5449b3a |
| RUSDY/USDT | 0.05% (500) | 10 | 0x11b2cd5f164f45d1df274c4df248fd5a7f057ea7 |
| USDT/tokenX | 1% (10000) | 200 | 0x28567b9f1a587f03051ea48055df565ccd80bb92 |
| USDT/wstETH | 0.01% (100) | 1 | 0xb0b744862c49a83fe158539f862056c7e5e00921 |

## Init Code Info
- InitCodeHash: 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a
- Standard UniV3 ICH: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54
- DIFFERS from standard Uniswap V3 — indicates pool contract modifications

## Open questions
- Does SmartRouter have its own access controls?
- Is the launchpad deployed? The UI says "Coming Soon" but SDK configs show launchpadGraphApi
- Are there any staking/gauge/ve-token contracts?
- What custom modifications exist in the pool init code hash?
