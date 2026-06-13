# M-03: Default Protocol Fees Set at 32-34% — Extreme Centralization and LP Disincentive

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-05 (Protocol fee ≤ total swap fee — mathematically preserved, but the economic assumption is violated by the extreme defaults)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPool (`initialize`)
- **Deployed address:** N/A (implementation contract)
- **Source:** verified
- **Location:** source/core/AgniPool.sol:L279-L291, L853-L861

## Description

`AgniPool.initialize()` sets default protocol fees to 32-34% of swap fees depending on the fee tier, encoded as `feeProtocol` values in `slot0`:

| Fee Tier | Default Protocol Fee (each for token0 and token1) | LP Share |
|----------|---------------------------------------------------|----------|
| 0.01% (100) | 33% (3300 bps) | 67% |
| 0.05% (500) | 34% (3400 bps) | 66% |
| 0.25% (2500) | 32% (3200 bps) | 68% |
| 1.00% (10000) | 32% (3200 bps) | 68% |

These values are encoded as packed `uint32` values using the formula `feeProtocol0 + (feeProtocol1 << 16)`, stored in `slot0.feeProtocol`.

Standard Uniswap V3 defaults to 0% protocol fee (the owner can optionally enable it). The `setFeeProtocol()` function allows the factory owner to set fees up to 40% (4000 bps) each.

The encoding scheme uses `PROTOCOL_FEE_SP = 65536`. The extraction in `swap()` uses modulo for token0 and right-shift for token1 — these work correctly as long as fee values stay below 65536 (which they do, capped at 4000).

## Root cause

```solidity
// AgniPool.sol:L279-L291
if (fee == 100) {
    slot0.feeProtocol = 216272100;  // 3300 + (3300 << 16) = 3300:3300
} else if (fee == 500) {
    slot0.feeProtocol = 222825800;  // 3400 + (3400 << 16) = 3400:3400
} else if (fee == 2500) {
    slot0.feeProtocol = 209718400;  // 3200 + (3200 << 16) = 3200:3200
} else if (fee == 10000) {
    slot0.feeProtocol = 209718400;  // 3200:3200
}
```

The protocol take of 32-34% is 3-4x higher than typical Uniswap V3 deployments (which usually set 10-25% maximum). The `setFeeProtocol` bounds (line 854-856) enforce a minimum of 10% (1000) and maximum of 40% (4000), meaning protocol fees cannot be set below 10% or above 40% of swap fees.

## Impact

- **LP disincentive**: On a 0.05% pool with 34% protocol fee, LPs earn only 0.033% per swap (0.05% × 66%). On a 0.25% pool with 32% protocol fee, LPs earn 0.17%
- **Competitive disadvantage**: Competing DEXs on Mantle with lower protocol takes will attract more liquidity
- **Centralization risk**: The factory owner can set protocol fees from 10% to 40% on any pool at any time via `setFeeProtocol()` (line 853-861), with no timelock
- **Economic extraction**: At 1% fee tier with 32% protocol, the protocol earns 0.32% per swap while the LP earns only 0.68%

### Practical calculation
For a pool with $1M liquidity and 0.05% fee:
- Daily volume of $10M → total fees of $5,000
- Protocol takes 34% → $1,700/day
- LPs split $3,300/day → ~0.12% daily yield (decent but significantly reduced)

For comparison, the same pool with UniV3 default 0% protocol: LPs earn $5,000/day → ~0.18% daily yield — 50% more.

## Attack path / preconditions

No exploit path per se — this is an economic centralization risk:

1. LPs provide liquidity to pools with high default protocol fees
2. The factory owner can further increase protocol fees up to 40% at any time
3. No timelock or community oversight mechanism exists
4. If the owner key is compromised, protocol fees can be raised to 40% instantly

## Proof of concept

`POC: pending` — Economic analysis: compare LP returns with 32-34% protocol take vs UniV3's 0-25% max.

**Needs:**
- Document that the existing code is not buggy — this is a design choice with economic consequences
- Verify on-chain that deployed pools have these default protocol fee values

## Recommendation

### Option A: Reduce default protocol fees
```diff
- slot0.feeProtocol = 222825800;  // 3400:3400 for 0.05% pool
+ // 0 protocol fee by default (standard Uniswap V3)
+ slot0.feeProtocol = 0;
```

### Option B: Document and timelock
If high protocol fees are intentional:
1. Clearly document the default fee structure in user-facing materials
2. Add a timelock (e.g., 7 days) for protocol fee changes
3. Implement a cap on cumulative protocol fee changes (e.g., max 25% increase per quarter)

### Option C: Allow setFeeProtocol to reduce below 10%
```diff
- require(_feeProtocol0 == 0 || (_feeProtocol0 >= 1000 && _feeProtocol0 <= 4000));
+ require(_feeProtocol0 <= 4000);  // Allow 0% protocol fee
```

## References

- **trailofbits** — "Default protocol fees of 32-34% are extreme — may trap LP value" (medium)
- **forefy FORE-007** — "Default protocol fees set at 32-34% — extreme relative to standard UniV3" (I)
- **solodit solodit-009** — "Non-standard default protocol fees (32-34%) represent extreme centralization risk and economic extraction" (M)
- **solodit solodit-010** — "Hardcoded fee protocol values in initialize() may cause overflow/underflow in fee encoding" (L) — confirmed encoding is safe for values ≤ 4000
- **invariant INV-05 lead** — "Default protocol fees set to 32-34% of swap fees — significantly higher than standard" (low)
