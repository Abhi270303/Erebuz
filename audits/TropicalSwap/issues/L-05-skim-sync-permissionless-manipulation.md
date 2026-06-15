# L-05 skim() and sync() permissionless — potential MEV manipulation surface

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** I-12 — skim/sync only correct balance<>reserve
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalPair` (`skim`, `sync`)
- **Deployed address:** Per-pair CREATE2 address
- **Source:** source code (verified)
- **Location:** `TropicalPair.sol:L192-L202`

## Description

`skim()` and `sync()` are permissionless functions (only the `lock` reentrancy guard). `skim()` sends excess token balance to any specified address, and `sync()` forces reserves to match current balances.

This follows the standard Uniswap V2 pattern but creates a manipulation surface:
- `skim()` can be used in sandwich attacks to drain small excess balances
- `sync()` can manipulate the pool's effective price in low-liquidity pools by adjusting reserves to current balances (which may differ from expected reserves due to donations)

## Root cause

Standard Uniswap V2 behavior — documented but permissionless.

## Impact

- Low — standard Uniswap V2 behavior, well-documented
- In thin pools, `sync()` can momentarily change the effective swap price

## Proof of concept

Not required — standard Uniswap V2 behavior.

## Recommendation

Document the risk. No code change required.

## References

- trailofbits (TB-13) — skim/sync permissionless — manipulation surface (L)
