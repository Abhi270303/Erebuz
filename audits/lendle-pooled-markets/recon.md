# Recon — lendle-pooled-markets (Phase 1)

## On-Chain Contract Map (Mantle, chainId 5000)

### Core Protocol (Aave V2 fork)
| Role | Address | Notes |
|------|---------|-------|
| LendingPoolConfigurator proxy | `0x30D990834539E1CE8Be816631b73a534e5044856` | Label: "Lendle: Configurator" |
| LendingPoolConfigurator impl | `0xfe91d9901dfaaf939a3bb8b444f5e141bb7dd0c1` | |
| LendingPoolAddressesProvider | `0xab94bedd21ae3411eb2698945dfcab1d5c19c3d4` | |
| LendingPool proxy | `0xcfa5ae7c2ce8fadc6426c1ff872ca45378fb7cf3` | |
| LendingPool impl | `0x13e9761c037f382472ce765556c3da2af29d9ec7` | |
| LendingPoolCollateralManager | `0x7D350354Dd9D1E48Ab1810f1F1b139309e9394Cc` | Not a proxy |
| LendingRateOracle | `0xc7F65C6b94A8A1C0977add58b6799ad456D72392` | |
| PoolAdmin | `0xB6eEdA94Bbb926881489F32489092C28e1a92484` | |

### Oracle
| Role | Address | Notes |
|------|---------|-------|
| AaveOracle | `0x870c9692Ab04944C86ec6FEeF63F261226506EfC` | Not a proxy |

### Price Feeds (PythPriceFeed instances, same bytecode)
| Asset | Price Feed |
|-------|-----------|
| USDC `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9` | `0x244f112a831412d1F6F6B13a8A2bDbAB69035de0` |
| USDT `0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE` | `0x8Ba59d9cB6E1Fd4d301cFE832c60142C2eefE909` |
| WBTC `0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2` | `0xf73c33B6775430F1F31e6D728D1DeAEA26721f2a` |
| WETH `0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111` | `0x2e014fA8C0bfE34F525287Cc25b74df37a9d20Ee` |
| WMNT `0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8` | `0x9830866B44cE08E3d0AA928330Dd65EE3A84Ff06` |
| mETH `0xcDA86A272531e8640cD7F1a92c01839911B90bb0` | `0x39D9ecD395231856E4C63747377Fb1665b80b131` |
| USDe `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` | `0x5259279F3530244efAE245cCccC0cF2b6E31Dd1c` |
| FBTC `0xC96dE26018A54D51c097160568752c4E3BD6C364` | `0x14d48A6d54B612Fe7EE847E80a87C7d20E831C73` |
| cmETH `0xE6829d9a7eE3040e1276Fa75293Bde931859e8fA` | `0xad22B2b6A43a8CE065272a51eE6d77136685756b` |
| AUSD `0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a` | `0xDcc5F2C27975807D7C4679AA8BB182e98c692A09` |
| sUSDe `0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2` | `0x790292b041d53B132fA7b4e17c8842DfEEaEC5b3` |

### Staking / Token
| Role | Address | Notes |
|------|---------|-------|
| MultiFeeDistribution proxy | `0x5C75A733656c3E42E44AFFf1aCa1913611F49230` | Label: "Lendle: Multi Fee Distribution" |
| MultiFeeDistribution impl | `0xfa12aaa98bb6f301b5a95383e4f43d5873de522b` | |
| LEND token | `0x25356aeca4210eF7553140edb9b8026089E49396` | |
| ChefIncentivesController | (not yet queried) | |

## Source
- GitHub: `lendle-xyz/lendle-contracts`
- DefiLlama adapter: AaveV2 export using LPConfigurator, deployed block 56556
- Audit: SourceHat (Sep 2023, 0 findings), Halborn (pending review)

## Open questions
- No reentrancy guard on LendingPool
- updateAssetPrice/getAssetPrice dichotomy (state mutation in borrow path)
- Pyth _getCurrentResponse() uses getPriceUnsafe, fallback to lastGoodPrice
