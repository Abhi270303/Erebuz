# [SEVERITY] Title — impact-first and specific

<!--
Copy this file into audits/PROJECT/issues/ as SEVERITY-NN-slug.md
e.g. H-01-reentrancy-drains-vault-on-deposit.md
Severity prefixes: H high, M medium, L low, I informational, G gas.
One finding per file. See references/05-finding-documentation.md.
-->

- **Severity:** High | Medium | Low | Informational | Gas
- **Status:** unconfirmed | confirmed
- **Invariant broken:** INV-XX (from invariants.md) — or "none / spec quality"
- **Chain / network:** ethereum (chainId 1) | ...
- **Contract:** ContractName (`function`)
- **Deployed address:** 0x... (proxy) -> 0x... (implementation)
- **Source:** verified | decompiled
- **Location:** path/to/Contract.sol:L123-L145

## Description
What the bug is, in your own words, and which invariant it violates (cite the INV id).

## Root cause
The specific line/logic that is wrong — the cause, not just the symptom.

## Impact
Concretely what an attacker achieves: funds drained (how much), accounting corrupted,
DoS, governance hijack, who loses what.

## Attack path / preconditions
1. Required state / roles / prices / ordering.
2. Step ...
3. Step ...
4. Invariant INV-XX now violated.

## Proof of concept
`pocs/test_name.t.sol::test_...` — `forge test --match-test ... -vvvv`
(Until written: `POC: pending`.)

## Recommendation
The fix, ideally as a diff. This is the defensive deliverable.

```diff
- vulnerable line
+ fixed line
```

## References
- Solodit: <title> — <url/id> — <firm>. Why it applies here: ...
- Prior audit / known incident with the same root cause: ...
