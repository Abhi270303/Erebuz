# L-08 No emergency pause mechanism in any contract

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** I-20 — No emergency pause (MISSING)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** TropicalFactory, TropicalPair, TropicalRouter, TropicalZapV1
- **Deployed address:** All
- **Source:** source code (verified)
- **Location:** All contracts

## Description

None of the four contracts (Factory, Pair, Router, ZapV1) implement any pausable mechanism. In the event of a critical vulnerability discovery (e.g., a live exploit of H-01 or H-02), there is no way to halt operations. The protocol must continue operating until transactions can be front-run or liquidity withdrawn — which is impractical during an active attack.

## Root cause

No contract inherits from OpenZeppelin's `Pausable` or implements an `emergencyStop` function.

## Impact

- **No circuit breaker:** If a critical vulnerability is exploited, there is no way to stop it
- The team must rely on social coordination (asking validators to censor transactions) which is unreliable on Mantle

## Proof of concept

Not required.

## Recommendation

Implement a pause mechanism on core contracts (at minimum on Router and ZapV1):

```solidity
import "@openzeppelin/contracts/security/Pausable.sol";

contract TropicalRouter is Pausable {
    function addLiquidity(...) external whenNotPaused { ... }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
```

## References

- trailofbits (TB-07) — No emergency pause mechanism (L)
