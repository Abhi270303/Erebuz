# [L] V3SwapRouter amountInCached Uses Storage Instead of Transient — Potential Stale Read Without nonReentrant

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** None (spec quality / defense-in-depth)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `V3SwapRouter` (`exactOutput`)
- **Source:** verified (repo source)
- **Location:** `router/contracts/V3SwapRouter.sol:L25-L28`, `L220-L231`

## Description

`amountInCached` is a regular storage variable (not transient per EIP-1153) used to pass data from the pool callback back to `exactOutput()`. Protected by `nonReentrant` in V3SwapRouter. However, the base `SwapRouter` (v3-periphery) has the same pattern without `nonReentrant`, relying on the pool's `lock`. If the guard is ever bypassed or missing, stale values could be read.

## Root cause

```solidity
// V3SwapRouter.sol:L25-L28
uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;
// Regular storage variable — not transient
```

## Impact

- **Low risk:** `nonReentrant` on V3SwapRouter prevents cross-call contamination
- **Defense-in-depth:** If `nonReentrant` were ever removed or a path bypassed, reentrancy could read stale cached values
- **Base SwapRouter (v3-periphery) is more exposed:** The base router has the same pattern without `nonReentrant`

## Proof of concept

No POC needed — acknowledged design pattern.

## Recommendation

Consider using transient storage (EIP-1153) when Mantle's Solidity version supports it. For now, maintain the `nonReentrant` guard and document that it must never be removed.

## References

- **Pashov lens:** Lead #8 (LOW) — amountInCached is storage not transient
- **Invariant lens:** Lead #4 (LOW) — same finding
