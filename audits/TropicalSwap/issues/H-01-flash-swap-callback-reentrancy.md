# H-01 Flash swap callback enables cross-contract price manipulation via stale reserves

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** I-19 — Flash swap callback can re-enter other contracts
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalPair` (`swap(uint256,uint256,address,bytes)`)
- **Deployed address:** Per-pair CREATE2 address
- **Source:** source code (verified)
- **Location:** `TropicalPair.sol:L159-L176`

## Description

`Pair.swap()` calls `ITropicalCallee(to).tropicalCall()` **before** calling `_update()` and the K-constant invariant check. The `lock` modifier prevents re-entering the *same* pair, but does **not** prevent:

1. Re-entering the **Router** to swap through a **different pair** at stale prices
2. Re-entering **ZapV1** which reads `getReserves()` — getting pre-swap (stale) reserve values
3. Interacting with any external protocol that relies on TropicalSwap's spot price

This breaks invariant I-19: the flash loan callback is not sandboxed and can manipulate the state of other contracts before the borrowing pair's reserves are updated.

## Root cause

`TropicalPair.sol:L159-L163`:
```solidity
if (data.length > 0) ITropicalCallee(to).tropicalCall(msg.sender, amount0Out, amount1Out, data);
// ...
balance0 = IERC20(_token0).balanceOf(address(this));
balance1 = IERC20(_token1).balanceOf(address(this));
// ...
_update(balance0, balance1, _reserve0, _reserve1);  // _update happens AFTER callback
```

The callback is invoked inside the `lock` mutex but before new reserves are recorded. The per-contract nature of `unlocked` means only the same pair's `swap`/`mint`/`burn`/`skim`/`sync` is protected — cross-contract calls via Router are not.

## Impact

- **Cross-pair price manipulation:** Flash-borrow from pair A, use tokens to swap through pair B at current (pre-update) prices, exploit the stale price before pair A's reserves update
- **ZapV1 state manipulation:** The callback can call `ZapV1.zapInToken()` which reads `getReserves()` — Zap operates on stale reserves, enabling favorable pricing for the attacker
- **Oracle manipulation:** Any protocol using TropicalSwap spot price as an oracle can be manipulated
- Historical precedent: Uniswap V2 ERC777 reentrancy attack (Lendf.Me, ~$1,278 ETH loss)

## Attack path / preconditions

1. Attacker deploys a contract conforming to `ITropicalCallee`
2. Flash borrow from `Pair A` via `swap(amountOut, 0, maliciousContract, data)`
3. Inside `tropicalCall()`:
   a. Router's `getReserves()` on Pair A returns **pre-swap** reserves (stale)
   b. Swap through `Pair B` using borrowed tokens at Pair A's old price
   c. Alternatively: call `ZapV1.zapInToken()` which reads stale `getReserves()`
4. Return to Pair A with borrowed tokens
5. Pair A's `_update()` records the new (manipulated) state
6. Invariant I-19 violated: callback enabled cross-contract manipulation

## Proof of concept

```
POC: pending — Fork POC required
```

**Test plan:**
1. Deploy `MaliciousCallee` contract
2. Create pairs A and B with different reserves
3. Call `PairA.swap()` with `data` pointing to MaliciousCallee
4. In `tropicalCall()`: swap borrowed tokens through Pair B via Router
5. Verify Pair B's price was manipulated using Pair A's stale reserves
6. Measure deviation from expected post-swap price

## Recommendation

Move `_update()` before the callback, or eliminate the callback entirely and provide a separate flash loan function. At minimum, document that `ITropicalCallee` receivers MUST NOT re-enter the TropicalSwap protocol.

```diff
+ _update(balance0, balance1, _reserve0, _reserve1);
if (data.length > 0) ITropicalCallee(to).tropicalCall(msg.sender, amount0Out, amount1Out, data);
- balance0 = IERC20(_token0).balanceOf(address(this));
- balance1 = IERC20(_token1).balanceOf(address(this));
- _update(balance0, balance1, _reserve0, _reserve1);
```

Or implement a global reentrancy guard that covers the entire TropicalSwap protocol (all pairs + Router + Zap).

## References

- pashov (pashov-008) — Flash swap callback reentrancy
- trailofbits (TB-02) — Flash swap callback before K-check enables cross-pair reentrancy
- forefy (forefy-001) — Flash swap callback re-enters Zap with stale reserves
- invariant (INV-004) — Flash swap callback re-enters different pairs
- solodit (SOL-007) — Flash swap callback enables cross-pair manipulation
- Solodit ref: Peckshield — [Uniswap Lendf.Me reentrancy](https://peckshield.medium.com/uniswap-lendf-me-hacks-root-cause-and-loss-analysis-50f3263dcc09) ($1,278 ETH loss from same callback attack surface)
