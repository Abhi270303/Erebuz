# L-03: MerkleDistributor State-Before-Proof Checks-Effects-Interactions Violation

| Field | Value |
|-------|-------|
| **Severity** | LOW |
| **Status** | unconfirmed |
| **Invariant** | INV-15 (assumed — EVM revert protects atomicity) |
| **Contract** | `MerkleDistributor.sol` |
| **Function** | `claim()` |
| **Line range** | L100–L128 |
| **Source file** | `/staking/MerkleDistributor.sol` |

---

## Description

In `MerkleDistributor.claim()`, state mutations happen **before** the merkle proof is verified:

```
L113:  c.claimed = true;                          ← State mutation (before verification)
L115:  reservedTokens = reservedTokens.sub(token);  ← State mutation
L117:  mintedTokens[token] = mintedTokens[token].add(token);  ← State mutation
...
L121:  require(MerkleProof.verify(...));           ← Proof verification (checks)
```

The state at L113–L117 is modified before the merkle proof is validated at L121. If the proof is invalid, the transaction reverts and all state changes are rolled back. **EVM atomicity ensures this is safe in a single transaction.**

### Why it's still a finding

While not exploitable in the current code (EVM revert protects all state changes atomically), this violates the Checks-Effects-Interactions pattern and is a **code quality issue**. If any future code change splits these operations (e.g., an upgrade splits claim into separate pre-claim and verify steps, or introduces a callback between the state changes and the verification), the protection would be lost.

### Impact

None in the current implementation. LOW severity — code quality / anti-pattern only.

### Recommendation

Reorder to perform the merkle proof verification before any state changes:

```solidity
// Verify first (Checks)
require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid proof");

// Then mutate state (Effects)
c.claimed = true;
reservedTokens = reservedTokens.sub(token);
mintedTokens[token] = mintedTokens[token].add(token);
```

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | L3 (in report) | LOW |
| **x-ray** | Tier 2 #7 | Code quality |

Only the pashov lens and x-ray flagged this as a notable anti-pattern.
