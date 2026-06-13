# INIT Capital - Recon

## Overview

INIT Capital is a "Liquidity Hook Money Market" — a lending protocol where users can lend, borrow, and access yield strategies through composable liquidity hooks.

- **Chains**: Mantle (primary), Blast
- **Category**: Lending
- **Website**: https://app.init.capital
- **Dev Docs**: https://dev.init.capital
- **GitHub**: https://github.com/init-capital
- **Twitter**: @InitCapital_
- **Oracle**: API3
- **Auditors**: Trust Security, PeckShield, Code4rena

## Core Contracts (Mantle)

| Contract | Proxy Address | Implementation |
|----------|-------------|----------------|
| InitCore | 0x972BcB0284cca0152527c4f70f8F689852bCAFc5 | 0xf8B8552D52986F06Ffaf14Bc88bfCF6DCBDbA05D |
| PosManager | 0x0e7401707CD08c03CDb53DAEF3295DDFb68BBa92 | 0x995b3D3CF83d5A0040b56b0201d3d2Db6E369DBF |
| Config | 0x007F91636E0f986068Ef27c950FA18734BA553Ac | 0x1dBD1e94373b3163F4376d6ae1A39DB9fdA334cB |
| LendingPool | 0x423bB7577BCf594df986D9646B44D3144b3329FD | (implementation directly) |
| RiskManager | 0x0c03cd3e8b669680Bf306Fc72F1dc2cAC592f951 | 0xf3416748553EA93643aa8B5A7879F2C40018002b |
| InitOracle | 0x4E195A32b2f6eBa9c4565bA49bef34F23c2C0350 | 0x7928419135cE5427858F0F5c0cbA3151b9b14f81 |
| LiqIncentiveCalculator | 0x66BDbf2Eefc84f83b476dB238574ca5Cb00550aD | 0xDDC99aeef7D5F87118A3A2636F7D0FB6c60daCF3 |
| AccessControlManager | 0xCE3292cA5AbbdFA1Db02142A67CFFc708530675a | (implementation directly) |
| InitLens | 0x7d2b278b8ef87bEb83AeC01243ff2Fed57456042 | (implementation directly) |
| MoneyMarketHook | 0xf82CBcAB75C1138a8F1F20179613e7C0C8337346 | 0x06cAb8cbD9bb02dB40eBa963A8C38d4C5924dA84 |

## Lending Pools (Mantle)

| Pool | Address |
|------|---------|
| POOL_WETH | 0x51AB74f8B03F0305d8dcE936B473AB587911AEC4 |
| POOL_WBTC | 0x9c9F28672C4A8Ad5fb2c9Aca6d8D68B02EAfd552 |
| POOL_WMNT | 0x44949636f778fAD2b139E665aee11a2dc84A2976 |
| POOL_USDC | 0x00A55649E597d463fD212fBE48a3B40f0E227d06 |
| POOL_USDT | 0xadA66a8722B5cdfe3bC504007A5d793e7100ad09 |
| POOL_METH | 0x5071c003bB45e49110a905c1915EbdD2383A89dF |

## Looping Hooks (Mantle)

| Hook | Address |
|------|---------|
| MerchantMoe LoopHook | 0xEfB43E833058Cd3464497e57428eFb00dB000763 |
| Agni LoopHook | 0x9567940746fdA24aa98160Ae3dACdbD51dae7D33 |
| FusionX LoopHook | 0xe4Fe22F64F37bA62BDDFeD3B05DaBcc1F01Ad1Ad |

## IRMs (Mantle)
- IRM_WETH: 0xEe619435DE204914c71df9AC7Bbb4BeCD3c9eaF0
- IRM_WBTC: 0x196D4E073687e8a61810725C1A299584494367E9
- IRM_WMNT: 0xF25E438eFad5a865A72f9FE39Ffd9aeC1F18398e
- IRM_USDC: 0x0959a65AB35cbF335AbAdC7793e2E8CAC81aE7e4
- IRM_USDT: 0x00fA41248F6c3A26863ec56634Fe78Ad4E4748EC
- IRM_METH: 0x32f533EAbD0B128e7EbE391DcC3F012701618B62

## Proxy Admin
- Proxy Admin (Mantle): 0xa55A591f91103D84106ba79EdA446eBDbfe26F7A
