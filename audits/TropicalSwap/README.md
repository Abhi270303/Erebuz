# TropicalSwap — Security Audit

- **What it is:** Uniswap V2 fork DEX on Mantle Network with custom fee structure and Zap helper
- **What it custodies:** ~$6.2k TVL in LP pools (Mantle chain)
- **Who can move the money:** Permissionless — any user can swap, add/remove liquidity; factory owner controls protocol fee
- **Status:** **Audit Complete** — 19 findings (2 High, 5 Medium, 9 Low, 3 Info)

## Key Links
- **DefiLlama:** https://defillama.com/protocol/tropicalswap
- **Website:** https://tropicalswap.exchange
- **Docs:** https://docs.tropicalswap.exchange
- **GitHub:** https://github.com/TropicalSwap-Organization/smart-contracts
- **Factory:** `0x5B54d3610ec3f7FB1d5B42Ccf4DF0fB4e136f249`
- **Router:** `0x116e699bf25dA6d80543850029257C9116692ac2`
- **ZapV1:** `0x7998653869Ab3c78888f954a3F62d8B7EA3bC867`

## Findings
- **H-01:** Flash swap callback enables cross-contract reentrancy
- **H-02:** ZapV1 hardcoded 1/1 minima enables MEV sandwich extraction
- **M-01:** ZapV1 balanceOf instead of delta enables residual drain + donation griefing
- **M-02:** ZapV1 uses block.timestamp as deadline — no expiry protection
- **M-03:** Init code hash hardcoded — mismatch would break Router
- **M-04:** Rebalancing math precision loss creates ~7 wei residuals per op
- **M-05:** No fee-on-transfer token handling

## Critical Exploit Chain (PROVEN via POC)
M-04 (residuals) → H-02 (can't clean) → M-01 (drain all) = **persistent value leak**

## POC Tests
```bash
cd pocs && forge test --match-test "testResidualMathFlaw|testBalanceOfDrainsAllResiduals|testFullExploitChain|testFlashSwapCallbackTiming" -vv
```
4/4 tests passing — math proofs and code-path proofs confirmed.
