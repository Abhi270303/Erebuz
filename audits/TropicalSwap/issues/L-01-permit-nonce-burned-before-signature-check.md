# L-01 Permit nonce incremented before ecrecover — failed signatures burn nonces

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (spec quality)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalERC20` (`permit`)
- **Deployed address:** TBD (inherited by TropicalPair LP tokens)
- **Source:** source code (GitHub)
- **Location:** `TropicalERC20.sol:L97-L105`

## Description

In `TropicalERC20.permit()`, the expression `nonces[owner]++` is evaluated **inside** the `abi.encode` argument for the digest computation — **before** `ecrecover` validates the signature. If `ecrecover` returns `address(0)` or the wrong address, the `require` at L104-L105 reverts, but the nonce has already been incremented (due to in-place `++`).

This permanently burns the used nonce value. The owner must re-sign with a new nonce, making the original signed message unusable.

An attacker can front-run any valid permit with an invalid signature (wrong `v/r/s`), causing the victim's nonce to be burned. The victim must generate a new signature.

## Root cause

`TropicalERC20.sol:L97`:
```solidity
keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
//                                                    ^^^^^^^^^^^^^^^^ nonce incremented here, before ecrecover at L103
```

The correct pattern is to read the nonce into a local variable first, increment it, then use the non-incremented value in the digest:

```solidity
uint256 nonce = nonces[owner]++;
// Use `nonce` (not the incremented value) in the digest
```

## Impact

- **Griefing:** Attacker can burn any observed permit signature's nonce by front-running with an invalid signature
- **User inconvenience:** LPer must re-sign and re-submit permit-based transactions
- **Not a fund loss** — the owner can always sign with a new nonce

## Attack path / preconditions

1. Alice signs a permit for LP token approval
2. Alice submits the permit transaction to mempool
3. Attacker front-runs with the same signature values but invalid `v`
4. `nonces[owner]++` executes (incrementing nonce from N to N+1)
5. `ecrecover` returns `address(0)` → `require` fails → transaction reverts
6. But nonce is now N+1, so Alice's signed message (with nonce N) is permanently invalid
7. Alice must sign again with nonce N+1

## Proof of concept

```
POC: pending — Simple verification
```

**Test plan:**
1. Sign a valid permit for a LP token
2. Call `permit()` with the valid signature but change `v` to an invalid value
3. Observe the transaction reverts
4. Check `nonces[owner]` — it has incremented despite the revert

## Recommendation

Move the nonce increment after the signature verification:

```diff
- keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
+ uint256 nonce = nonces[owner];
+ nonces[owner] = nonce + 1;
+ keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
```

## References

- forefy (forefy-005) — Permit nonce incremented before ecrecover (M — re-assessed to L)
