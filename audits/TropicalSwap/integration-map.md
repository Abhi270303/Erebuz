# TropicalSwap — Integration Map

## Contract Dependency Graph

```
TropicalFactory (0x5B54d3610ec3f7FB1d5B42Ccf4DF0fB4e136f249)
├── creates TropicalPair (CREATE2) — one per (token0, token1)
│   ├── TropicalERC20 (LP token, inherited)
│   ├── Math.sol (sqrt)
│   ├── SafeMath.sol
│   └── UQ112x112.sol (price accumulator)
├── feeTo → protocol fee collector
├── tropicalFee → configurable fee (0-0.15%)
└── feeToSetter → admin

TropicalRouter (0x116e699bf25dA6d80543850029257C9116692ac2)
├── uses TropicalLibrary.pairFor() → computes pair addresses
│   └── TropicalLibrary → SafeMath, hardcoded init code hash
├── wraps WETH (WMANTLE 0x78c1b0C91...)
├── swapExactTokensForTokens() → ITropicalPair.swap()
├── addLiquidity() → ITropicalPair.mint()
└── removeLiquidity() → ITropicalPair.burn()

TropicalZapV1 (0x7998653869Ab3c78888f954a3F62d8B7EA3bC867)
├── Ownable (OpenZeppelin) → recoverWrongTokens, updateMaxZapInverseRatio
├── ReentrancyGuard
├── calls TropicalRouter for swaps + addLiquidity
├── reads ITropicalPair.getReserves() for estimation
├── Babylonian.sol (sqrt)
└── WMANTLE for ETH wrapping

External Integrations:
├── WMANTLE (0x78c1b0C91...) — Wrapped native token
├── PAPPLE (0x2b19015bd5B9270097d1cEc431c800d11e9f4841) — Protocol token
├── SEEDS (0xFc734d145E2941d70bC5e178A8f946E58FA96186) — Escrowed PAPPLE
├── FruitNinja/Masterchef (0x8690Efd596D58fae7d6b1A10178ECdC3F19914E8) — Staking
├── Any ERC-20 token — Pairs can be created for any token
└── Any ITropicalCallee — Flash swap callbacks

## Input Flows (external → internal)
User → Router.swapExactTokensForTokens() → Pair.swap() → _update()
User → Router.addLiquidity() → Pair.mint() → _update()
User → ZapV1.zapInToken() → Router.swap + Router.addLiquidity
User → ZapV1.zapOutToken() → Pair.burn() → Router.swap
FlashLoan → Pair.swap() → ITropicalCallee.tropicalCall() → _update()

## Token Flows
Swap: User → Router → Pair (in) → Pair (out) → User
AddLiquidity: User → Router → Pair (mint) → User (LP tokens)
ZapIn: User → ZapV1 → Router(swap) + Router(addLiquidity) → User(LP)
ZapOut: User(LP) → ZapV1 → Pair(burn) → ZapV1 → Router(swap) → ZapV1 → User
