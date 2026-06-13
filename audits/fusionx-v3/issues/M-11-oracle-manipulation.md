# [M] Spot Price from slot0 Is Manipulable — TWAP Not Enforced for Oracle-Dependent Integrations

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-POOL-01 — sqrtPriceX96 bounds (spot price is within range, not manipulation-resistant)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3Pool` (`slot0`, `observe`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3Pool.sol:L281-L310` (initialize), `L90-L105` (slot0)

## Description

`pool.slot0()` returns the current spot price which is trivially manipulable via flash loan or large swap. Any external protocol or integration reading FusionX V3 pool prices from `slot0` instead of TWAP (`observe()`) can have its pricing manipulated. Additionally, the default observation cardinality (typically 1 observation) is too small for reliable TWAP, making the oracle observation array equivalent to spot price until expanded.

## Root cause

**Problem 1 — Slot0 is spot price:**
```solidity
// FusionXV3Pool.sol: slot0 returns the current tick/price
struct Slot0 {
    uint160 sqrtPriceX96;  // Current spot price — manipulable
    int24 tick;
    // ...
}
```

**Problem 2 — Default observation cardinality = 1:**
```solidity
// Observations.initialize() typically sets cardinality = 1
// After a single swap, the oldest observation is overwritten
// TWAP with cardinality 1 = spot price
```

**Problem 3 — MixedRouteQuoterV1 uses spot quotes** (from x-ray analysis)

## Impact

- **Integration risk:** Any DeFi protocol (lending, liquidation, yield aggregator) that reads FusionX V3 pool prices from `slot0` can be manipulated
- **TWAP unreliability:** Unless `increaseObservationCardinalityNext()` is called explicitly, the TWAP window defaults to 1 observation (spot price equivalent)
- **Historical reference:** LML Protocol lost $950K via spot price manipulation in staking rewards; PancakeSwap V3 pools had a $183K manipulation incident (Feb 2025)

## Attack path / preconditions

1. External protocol uses `pool.slot0()` as a price oracle (not in this codebase, but an integration risk)
2. Attacker takes a flash loan, performs a large swap on the FusionX V3 pool
3. Spot price moves significantly
4. Attacker exploits the external protocol at the manipulated price
5. Attacker reverses the swap, repays flash loan

## Proof of concept

`POC: pending` — no on-chain exploit in the audit scope. Documenting integration risk.

## Recommendation

1. Document clearly that FusionX V3 pools are NOT safe as price oracles via `slot0()` — integrations must use TWAP
2. Ensure `initialize()` sets a minimum observation cardinality (e.g., 10-20) for out-of-the-box TWAP safety
3. Consider automatically increasing observation cardinality during pool initialization
4. The `MixedRouteQuoterV1` should warn users that quotes are spot prices and can be manipulated

## References

- **Solodit lens:** Lead SOL-006 (MEDIUM) — Spot price from slot0 is manipulable
- **Solodit lens:** Lead SOL-007 (MEDIUM) — Observation array default cardinality too small for TWAP
- **Historical:** LML Protocol $950K exploit; C4 Asymmetry #986; Beefy CLM audit (Cyfrin) TWAP check bypass
- **Invariant:** INV-POOL-01
