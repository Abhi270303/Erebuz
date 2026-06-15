- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** none (off-chain)
- **Chain / network:** Mantle
- **Contract:** fusionx.finance (dapp)
- **Deployed address:** https://fusionx.finance
- **Source:** Passive analysis only
- **Location:** Multiple

## Description
The off-chain audit was conducted under passive-only constraints (no active scanning, no authenticated testing). Several areas could not be verified:

1. **Affiliate dashboard authorization (IDOR)**: The `/affiliates-program/dashboard` route exists but could not be tested for cross-account access without creating authenticated sessions. If sequential/numeric affiliate IDs are used without proper authorization, attackers could view other users' commission data and withdrawal addresses.

2. **Input validation**: All user-facing forms (swap, add liquidity, approval limits) require wallet interaction to test. Client-side validation bypasses or SSR error page information disclosure could not be verified.

3. **Subgraph/API endpoints**: The frontend code is in a private repository. Subgraph or API endpoints could not be analyzed for access control or rate limiting issues.

## Root cause
Passive-only constraint limited testing depth.

## Impact
These untested areas represent coverage gaps, not confirmed vulnerabilities. A full-scope web application assessment including active testing and authenticated sessions would be needed to clear them.

## Recommendation
1. Conduct an authorized active security assessment of the affiliate dashboard including cross-account access testing
2. Include input fuzzing and error path testing in any future web security review
3. If using a private subgraph, ensure it has proper access control and rate limiting
