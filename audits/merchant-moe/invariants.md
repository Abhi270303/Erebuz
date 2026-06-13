# Merchant Moe Liquidity Book - Invariants

## Core Invariants

### Token Accounting
1. `_reserves` must always equal sum of `_bins[id]` values minus `_protocolFees`
2. `totalSupply(id)` = sum of all `balanceOf(account, id)` for each bin id
3. Protocol fees must never exceed total fees collected
4. `_reserves` must never exceed actual ERC20 balances of the contract

### Swap Invariants
1. `amountsOut = swap(swapForY, to)` must always be <= `_reserves.decode(!swapForY)` (cannot swap more than available)
2. Total fee (base + variable) must be <= 10% (MAX_TOTAL_FEE)
3. Variable fee must be >= base fee (surge pricing)
4. Volatility accumulator must be monotonically increasing within a swap
5. Active bin must always contain the price where `swapForY` direction's reserve is non-empty
6. `amountsOut` transferred must always leave `_reserves` in a consistent state

### Mint/Burn Invariants
1. Shares must be minted proportionally to deposited liquidity relative to total liquidity per bin
2. `burn()` must return proportionally equal value to `shares/totalSupply` of each bin
3. Composition fee must be charged when adding to active bin with skewed composition ratio — **DEAD BRANCH (always zero)**
4. Adding to non-active bins must only accept one token type (X for higher bins, Y for lower bins)
5. `supply == 0` → bin added to tree; `supply == amountToBurn` → bin removed from tree

### Fee Invariants
1. Total fee = base fee + variable fee
2. Base fee = baseFactor * binStep * 1e10
3. Variable fee = (volAcc * binStep)^2 * variableFeeControl / 100
4. Protocol share = max 25% of total fees (BASIS_POINT_MAX = 10_000)
5. Flash loan fee = max 10%
6. Composition fee = imbalance * totalFee * (totalFee + PRECISION) / PRECISION^2 — **always zero due to unreachable path**

### Security Invariants (MUST always hold)
1. NO check on who calls swap beyond reentrancy guard — any address can initiate a swap
2. NO check on who calls mint — any address can mint liquidity (assuming tokens are transferred)
3. NO access control on burn (beyond approval check)
4. Flash loan only checks final balance >= initial reserves + expected fee
5. The `amountsLeft` refund in mint goes to `refundTo` parameter (user-controlled)
6. The `to` parameter in swap is user-controlled (can be any address)

## Missing / Unenforced Invariants (Attack Vectors)

| # | Invariant | Issue | Severity |
|---|-----------|-------|----------|
| 1 | `sqrt` first-deposit should burn MINIMUM_LIQUIDITY | First depositor can inflate share price | HIGH |
| 2 | `veMoe.maxVeMoe` should use `newBalance`, not `oldBalance` | Users lose veMoe on incremental stakes | MEDIUM |
| 3 | `vote()` should reject duplicate PIDs | Flash vote+unvote for bribes | MEDIUM |
| 4 | `amountsReceived` should exclude unaccounted balance | Donations captured by next minter | MEDIUM |
| 5 | `after*` hooks should be inside reentrancy guard | Hooks can re-enter pair | LOW |
| 6 | `vote()` needs reentrancy guard against `setBribes` | Malicious bribe reentrancy | LOW |
| 7 | No min/max swap amount check | Partial fills with rounding dust | INFO |
| 8 | No balance snapshot before swap | Relies entirely on balanceOf() difference | INFO |
| 9 | Composition fee rounding DOWN | Path unreachable — no impact | DEFERRED |
| 10 | Protocol fee rounding DOWN (`scalarMulDivBasisPointRoundDown`) | Small dust left in protocol fees | INFO |
| 11 | `ones` dust in `collectProtocolFees` | 1 wei per token always left | INFO |
