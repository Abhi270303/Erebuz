# MED-001: `InitOracle` Single-Source Fallback Bypasses Deviation Check

**Severity:** MEDIUM
**Bug Class:** Oracle Manipulation
**Confidence:** HIGH (3 agents: Pashov, Forefy, Trail of Bits)

## Affected Contract

`oracle/InitOracle.sol:41–83` (`getPrice_e36()`)

## Description

When fetching an asset price, `InitOracle.getPrice_e36()` queries both a primary and secondary oracle source via `try/catch`. The price deviation check (`maxPriceDeviations_e18`) only runs when BOTH sources return valid prices. If one source reverts (network issue, stale data), the other source's price is used **without any deviation or staleness check**.

This means if the primary source is compromised and the secondary happens to be unavailable (or vice versa), a single manipulated source determines the protocol's asset price.

## Impact

- **Oracle manipulation:** A compromised or stale single source can set arbitrary asset prices
- **Liquidation attacks:** Incorrect prices can trigger unfair liquidations or prevent legitimate ones
- **Borrowing attacks:** Assets can be borrowed at manipulated prices

## Mitigation

Add a staleness check (compare against a max-age threshold like Pyth's `maxStaleTime`) and a min/max sanity bound on the fallback path. Never use a single source's price without validation.
