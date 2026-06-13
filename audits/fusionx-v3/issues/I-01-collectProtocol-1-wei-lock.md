# [I] collectProtocol Permanently Locks 1 Wei Per Token in Protocol Fees (Gas Optimization)

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** INV-POOL-07 — Protocol fees are bounded (enforced, 1 wei locked is intentional)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3Pool` (`collectProtocol`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3Pool.sol:L888-L891`

## Description

The Uniswap V3 gas optimization pattern `if (amount0 == protocolFees.token0) amount0--` ensures the storage slot is never fully cleared (avoids zero-to-nonzero SSTORE cost on the next collection). This permanently locks 1 wei per token in `protocolFees`. If `protocolFees.token0 = 1` and someone tries to collect, `amount0` becomes 0, `protocolFees.token0 -= 0` leaves 1, and nothing transfers. The 1 wei accumulates across collection cycles.

## Root cause

```solidity
// FusionXV3Pool.sol:L888-L891
if (amount0 == protocolFees.token0) amount0--; // Gas savings: never zero the slot
protocolFees.token0 -= amount0;
```

## Impact

- **1 wei permanently locked per token per collection type**
- **Intentional design** from Uniswap V3 — inherited unchanged
- **Accumulation:** If protocol fees are collected in many small increments, each collection cycle leaves 1 wei. Over millions of collections, this could become a meaningful amount
- **Not exploitable** — the locked amount can never be recovered but also cannot be stolen

## Proof of concept

No POC needed — acknowledged Uniswap V3 behavior.

## Recommendation

No fix needed for the gas optimization. If exact full collection is desired, allow an alternative path without the `amount0--` optimization (at higher gas cost).

## References

- **Trail of Bits lens:** Lead #5 (INFO) — collectProtocol 1 wei permanently locked
- **Invariant lens:** Lead #5 (INFO) — same finding
- **Solodit lens:** Lead SOL-009 (LOW) — collectProtocol subtracts 1 wei
- **Historical:** C4-2024-02-uniswap-foundation-#99 and #45
