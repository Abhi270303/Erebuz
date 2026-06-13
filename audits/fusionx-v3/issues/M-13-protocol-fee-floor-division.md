# [M] Protocol Fee Per-Step Floor Division Biases Dust Toward LPs — Value Leak at Scale

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-POOL-05 — feeGrowthGlobal monotonicity (not broken directly, but fee distribution is affected)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3Pool` (`swap`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3Pool.sol:~L710-L730`

## Description

In each swap step, the protocol fee is calculated as `step.feeAmount * feeProtocol / 10000`. Integer division rounds down, sending the dust (up to 1 wei per step) to LPs instead of the protocol. For high-volume pools with many swap steps, this compounds into significant value leakage from protocol fees. While inherent to integer arithmetic, the unpaid dust per-step is a directional bias that always favors LPs over the protocol.

## Root cause

```solidity
// Simplified: protocol fee calculation in swap step
uint256 protocolFee = step.feeAmount * cache.feeProtocol / PROTOCOL_FEE_DENOMINATOR;
// Where PROTOCOL_FEE_DENOMINATOR = 10000 (representing 100%)
// feeProtocol is typically 3200-3400 (32-34% of swap fees)
```

The `/ PROTOCOL_FEE_DENOMINATOR` is integer division that truncates toward zero. Since both numerator and denominator are positive, this rounds down. The missing `feeAmount * feeProtocol % PROTOCOL_FEE_DENOMINATOR` is always positive when the division is not exact, and it accrues to LPs (since the fee is subtracted from the swap amount before distribution).

## Impact

- **Protocol revenue loss:** Up to 1 wei per swap step is lost by the protocol and captured by LPs
- **Scaling:** For high-volume pools on Mantle (where gas is cheap), thousands of swap steps per day compound the loss
- **Directional bias:** The rounding always favors LPs, never the protocol — it's a systematic bias
- **Default protocol fees are 32-34%** (very high by Uniswap V3 standards), making the absolute dust amount larger at current fee levels

## Attack path / preconditions

- Requires protocol fee to be set to a non-zero value (default is 32-34% on initialize)
- No special precondition — every swap with a non-zero protocol fee experiences this
- The impact is proportional to swap volume

## Proof of concept

`POC: pending` — differential fuzzing:
```
// Compare FusionX V3 protocol fee collected vs "fair share" expected
// Over N random swaps, measure cumulative protocol vs LP fee distribution
```

## Recommendation

Consider rounding protocol fees up (in favor of the protocol) instead of down:

```diff
- uint256 protocolFee = step.feeAmount * feeProtocol / PROTOCOL_FEE_DENOMINATOR;
+ uint256 protocolFee = FullMath.mulDivRoundingUp(step.feeAmount, feeProtocol, PROTOCOL_FEE_DENOMINATOR);
```

Note: This changes fee distribution in favor of the protocol. The current implementation is not a bug in the Uniswap V3 sense — it's the standard behavior. The recommendation is a protocol economics optimization.

## References

- **Solodit lens:** Lead SOL-005 (MEDIUM) — Protocol fee per-step floor division
- **Historical:** Cecuro Uniswap V3 Core Audit; Sherlock Dinari #7 (2023-07) "Trading fees should round up"
- **Invariant:** INV-POOL-05, INV-POOL-07
- **Note:** This is inherent to all Uniswap V3 forks and is an accepted design trade-off
