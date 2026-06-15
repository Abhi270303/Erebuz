# I-01 Outdated Solidity 0.5.16 with known compiler bugs

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** none
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** TropicalFactory, TropicalPair, TropicalERC20, TropicalMath, UQ112x112
- **Deployed address:** TBD
- **Source:** source code (verified)
- **Location:** All core contracts — `pragma solidity =0.5.16`

## Description

The core contracts (Factory, Pair, ERC20, Math, UQ112x112) use Solidity 0.5.16 which has 12 known severe issues per the Solidity bug list, including:
- `KeccakCaching` — incorrect keccak256 results under specific conditions
- `ABIDecodeTwoDimensionalArrayMemory` — memory corruption on 2D array decode
- `DirtyBytesArrayToStorage` — dirty bytes array storage corruption

While these bugs are unlikely to be exploitable in the specific patterns used by TropicalSwap, using a compiler version with known bugs is a defense-in-depth concern. The Zap contract uses 0.8.4 (much newer) while core uses 0.5.16, creating a mixed-version codebase.

## Impact

- Low — no specific exploit path identified
- Defense-in-depth concern
- Mixed compiler versions increase maintenance complexity and audit scope

## Recommendation

Consider upgrading core contracts to Solidity 0.8.x for security fixes and built-in overflow checks.

## References

- trailofbits (TB-11) — Outdated Solidity 0.5.16 with known compiler bugs (I)
