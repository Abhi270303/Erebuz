# Severity rubric (impact x likelihood)

Assign severity from **impact** (how bad if it happens) and **likelihood** (how
plausible the preconditions are). When unsure, state both axes in the finding and let the
combination decide. This mirrors the scales used by Code4rena / Sherlock / Cyfrin so it
maps cleanly onto Solodit comparisons.

## Impact levels
- **High** — direct loss or freezing of user/protocol funds; insolvency; theft;
  permanent DoS of core functionality; governance/ownership takeover.
- **Medium** — loss is bounded, conditional, or affects only the attacker/griefer's
  funds; temporary DoS; value leak that needs unusual conditions; broken accounting that
  does not (yet) drain funds.
- **Low** — minor value leak, recoverable, or only under impractical conditions; safety
  margin erosion without direct loss.

## Likelihood levels
- **High** — any user can trigger it, cheaply, in normal operation; no special role.
- **Medium** — needs specific (reachable) state, ordering, modest capital, or a flash
  loan; or a semi-trusted role.
- **Low** — needs a trusted/privileged actor to misbehave, extreme market conditions, or
  an impractical setup.

## Combined severity

| | Impact High | Impact Medium | Impact Low |
|---|---|---|---|
| **Likelihood High** | High | Medium | Low |
| **Likelihood Medium** | High | Medium | Low |
| **Likelihood Low** | Medium | Low | Low/Info |

## Other classes
- **Informational (I)** — no direct security impact: spec deviation, missing event,
  unclear docs, defense-in-depth suggestion, or an **unconfirmed** observation worth
  recording. Many `I`/`L` notes become part of a High once chained (Phase 8) — keep them.
- **Gas (G)** — optimization only; no correctness/security impact.

## Centralization / admin powers
Privileged actions that can move or freeze funds are findings even if "intended": record
the trust assumption and the worst case if the key is compromised or malicious. Severity
reflects the blast radius and the safeguards (timelock? multisig? cap?).

## Adjusting after chaining
A finding's severity is provisional until Phase 8/9. If chaining raises a Low's
likelihood or impact, raise its severity and rename the file. If a POC fails to
reproduce it, lower it (often to `I`) rather than deleting — note why it did not work.
