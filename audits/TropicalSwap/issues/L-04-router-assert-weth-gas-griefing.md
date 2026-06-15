# L-04 Router uses assert() for WETH transfers — all gas wasted on failure

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (gas quality)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalRouter`
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalRouter.sol:L165, L289, L303, L327`

## Description

The Router uses `assert(IWETH(WETH).transfer(...))` instead of `require()` for WETH transfers in 4 locations. In Solidity, `assert()` consumes **all remaining gas** on failure, while `require()` refunds unused gas. If a WETH transfer fails (e.g., contract paused, insufficient balance), the entire transaction's gas is wasted.

This is a gas griefing vector: an attacker can trigger conditions that cause WETH transfers to fail, causing the victim to lose the full gas amount instead of just the gas used up to the revert point.

## Root cause

```solidity
// Router.sol L165:
assert(IWETH(WETH).transfer(pair, amountETH));
// Also at L289, L303, L327
```

Should be `require()` with a descriptive error message.

## Impact

- **Gas griefing:** Full transaction gas consumed on WETH transfer failure instead of partial refund
- **No fund loss** — the attacker cannot steal funds, only cause victims to waste gas

## Attack path / preconditions

- WETH contract pauses or the Router's WETH approval is revoked
- Any Router transaction that wraps/unwraps ETH reverts with full gas consumption

## Proof of concept

```
POC: pending
```

## Recommendation

Replace `assert()` with `require()`:

```diff
- assert(IWETH(WETH).transfer(pair, amountETH));
+ require(IWETH(WETH).transfer(pair, amountETH), "WETH transfer failed");
```

## References

- forefy (forefy-007) — Router assert() for WETH transfers (L)
