# TropicalSwap - Reconnaissance

## Protocol Overview
- **Name:** TropicalSwap
- **Type:** DEX (AMM) - Uniswap V2 Fork
- **Chain:** Mantle Network (Chain ID: 5000)
- **TVL:** ~$6.2k (current), peak ~$64k
- **Website:** https://tropicalswap.exchange
- **Docs:** https://docs.tropicalswap.exchange
- **Twitter:** @tropical_swap
- **GitHub:** https://github.com/TropicalSwap-Organization
- **DefiLlama:** https://defillama.com/protocol/tropicalswap

## Contract Addresses (Mantle)

| Contract | Address | Notes |
|----------|---------|-------|
| TropicalFactory | `0x5B54d3610ec3f7FB1d5B42Ccf4DF0fB4e136f249` | Creates pairs |
| TropicalRouter | `0x116e699bf25dA6d80543850029257C9116692ac2` | Swap/Liquidity router |
| TropicalZapV1 | `0x7998653869Ab3c78888f954a3F62d8B7EA3bC867` | Zap in/out helper |
| BoardingPass NFT | `0x33aE5F7Eed4f5C498869bB671Bb20Ad5A2FfEd25` | NFT |
| $PAPPLE | `0x2b19015bd5B9270097d1cEc431c800d11e9f4841` | Native token |
| SEEDS | `0xFc734d145E2941d70bC5e178A8f946E58FA96186` | Escrowed PAPPLE |
| FruitNinja (Masterchef) | `0x8690Efd596D58fae7d6b1A10178ECdC3F19914E8` | Staking/farming |
| WMANTLE | `0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8` | Wrapped Mantle |

## GitHub Source Code
- **Repo:** TropicalSwap-Organization/smart-contracts
- **Path:** projects/exchange-protocol/contracts/
- **Files:**
  - TropicalFactory.sol (v0.5.16)
  - TropicalPair.sol (v0.5.16)
  - TropicalERC20.sol (v0.5.16)
  - TropicalRouter.sol (v0.5.16)
  - TropicalZapV1.sol (v0.8.4, uses OpenZeppelin)
  - libraries/: TropicalLibrary.sol, SafeMath.sol, Math.sol, UQ112x112.sol, Babylonian.sol, WMANTLE.sol
  - interfaces/: ITropicalERC20.sol, ITropicalFactory.sol, ITropicalPair.sol, ITropicalRouter01.sol, ITropicalRouter02.sol, IERC20.sol, IWETH.sol, ITropicalCallee.sol

## Key Observations
- Uniswap V2 fork with modified fee structure
- Swap fee: 0.25% (25/10000) hardcoded in TropicalPair.swap()
- Protocol fee: tropicalFee variable (default 15 = 0.15%) in Factory
- Library uses 9975/10000 fee (matches standard 0.25%)
- Init code hash in TropicalLibrary: `0x321aea434584ceee22f77514cbdc4c631d3feba4b643c492f852c922a409ed1e`
- ZapV1 contract has complex rebalancing math
- feeTo setter controls protocol fee collection
