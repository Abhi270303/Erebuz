- **Severity:** Informational
- **Status:** confirmed
- **Invariant broken:** none (off-chain)
- **Chain / network:** Mantle, Ethereum, testnets
- **Contract:** fusionx.finance (dapp — swap page JS bundle)
- **Deployed address:** https://fusionx.finance/swap
- **Source:** Client-side JS bundle
- **Location:** /_next/static/chunks/pages/swap-*.js

## Description
The public JS chunk for the swap page contains hardcoded addresses for USDC, USDT, DAI across multiple chains (Mantle, Ethereum, testnets), along with protocol contract addresses and router configuration. While this is standard practice for DEX frontends, it exposes every integration point to attackers.

Hardcoded addresses found:
- USDC (Mantle): 0xeA911b76c5681Fd2A46Cf951B320C7e39186f3F0
- USDT (Mantle): 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE
- USDC (Ethereum): 0xeA911b76c5681Fd2A46Cf951B320C7e39186f3F0
- mmLinkedPool reference detected (third-party liquidity mining pool integration)
- SmartRouter and SwapRouter addresses

## Root cause
Contract addresses are compiled into the frontend bundle at build time rather than fetched from a dynamic registry.

## Impact
Standard for DeFi dapps. No direct exploit path. mmLinkedPool reference suggests a third-party integration that may not be documented.

## Recommendation
Consider using a dynamic on-chain registry or environment variables with server-side injection to reduce hardcoded addresses in client bundles. Verify that all integrated contracts (including mmLinkedPool) are documented and scoped for audit.

## References
None
