# TropicalSwap - Invariants

## Core AMM Invariants
1. **K Invariant (Uniswap V2):** After each swap, `balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 10000^2`
   - Where `balanceXAdjusted = balanceX * 10000 - amountXIn * 25` (0.25% fee)
2. **Constant Product:** `reserve0 * reserve1 = k` between swaps (ignoring fees)
3. **Mint/Burn Ratio:** Liquidity minted/burned must be proportional to reserve changes

## Factory Invariants
4. **Unique Pairs:** No duplicate pair for the same (token0, token1) order
5. **Fee Limit:** `tropicalFee <= MAX_TROPICAL_FEE (15)` → max 0.15% protocol fee
6. **feeToSetter Control:** Only feeToSetter can change feeTo/feeToSetter/tropicalFee
7. **CREATE2 Determinism:** Pair address deterministically computed from (factory, token0, token1)

## Pair Invariants
8. **No Self-Transfer:** swap `to` cannot be either token0 or token1
9. **Minimum Liquidity:** First MINIMUM_LIQUIDITY (1000) LP tokens permanently burned to address(0)
10. **Reserve Overflow Protection:** Balances must fit in uint112
11. **Reentrancy Lock:** `unlocked` mutex prevents reentrancy during swaps/mint/burn/skim/sync
12. **Sync:** `skim()` and `sync()` can only correct balance/reserve mismatches, not steal

## Router Invariants
13. **Deadline Check:** All router operations have deadline protection via `ensure(deadline)` modifier
14. **Output Limits:** `amountOutMin` / `amountInMax` slippage protection enforced

## ZapV1 Invariants
15. **Max Zap Ratio:** `reserve / swapAmount >= maxZapReverseRatio` prevents excessive price impact
16. **Token Check:** Zap input tokens must be one of the LP's two tokens
17. **Reserve Threshold:** Both reserves must be >= MINIMUM_AMOUNT (1000)

## MISSING / UNENFORCED Invariants
18. **Fee-on-transfer tokens:** No special handling for tokens that take transfer fees (router has some supporting functions but pair does not)
    - Status: `MISSING` — Pair contract has no fee-on-transfer handling
19. **Flash swap callback safety:** `ITropicalCallee` callback can re-enter other contracts
    - Status: `MISSING` — `Pair.swap()` line 161 calls `ITropicalCallee(to).tropicalCall()` inside the lock but before `_update()`
20. **No emergency pause mechanism** in any contract
    - Status: `MISSING` — Factory, Pair, Router, ZapV1 have no pause mechanism
21. **ZapOut uses balanceOf after swap** — could be manipulated
    - Status: `MISSING` — `_zapOut()` returns `IERC20(_tokenToReceive).balanceOf(address(this))` without delta check
22. **Init code hash consistency:** `TropicalLibrary.pairFor()` hardcoded hash must equal `Factory.INIT_CODE_PAIR_HASH`
    - Status: `MISSING` — No on-chain assertion links the two. If compiler changes bytecode, pairFor computes wrong addresses
    - Code: `TropicalLibrary.sol` hardcodes `0x321aea434584ceee22f77514cbdc4c631d3feba4b643c492f852c922a409ed1e`; Factory derives via `keccak256(type(TropicalPair).creationCode)`
23. **ZapV1 deadline protection is ineffective:** All Zap functions pass `block.timestamp` as the Router deadline, making `ensure(deadline)` always pass
    - Status: `MISSING` — `_zapIn()` line 277, `_zapInRebalancing()` lines 320/328, `_zapOut()` line 369 all use `block.timestamp`
24. **Zap rebalancing achieves 50/50 split:** Post-swap ratio of reserves should equal the LP token ratio
    - Status: `MISSING` — No post-condition validation; `_calculateAmountToSwapForRebalancing()` math may be lossy at extreme ratios
25. **Swap fee consistency:** Pair (25/10000) ↔ Library (9975/10000) must match
    - Status: `assumed` — 10000 - 25 = 9975, confirmed by code inspection
    - Code: `Pair.sol`:166 uses `amountIn.mul(25)`, `TropicalLibrary.sol` uses `amountIn.mul(9975)`
26. **Protocol fee minting does not underflow:** `_mintFee()` numerator < denominator check
    - Status: `assumed` — Guard `if (rootK > rootKLast)` at Pair:89; liquidity > 0 check at Pair:94
