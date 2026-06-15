- **Severity:** Medium
- **Status:** confirmed
- **Invariant broken:** none (off-chain)
- **Chain / network:** Mantle
- **Contract:** fusionx.finance (dapp — frontend codebase)
- **Deployed address:** https://fusionx.finance
- **Source:** Inferred from JS bundle analysis (private frontend repo)
- **Location:** JS bundle (localStorage keys, page structure, tech stack)

## Description
The FusionX dapp's frontend codebase is a fork of PancakeSwap's frontend. This is evidenced by:
- Matched localStorage key naming convention (`fusionx:isHotTokensDisplay` matches PancakeSwap's pattern)
- Identical page structure across all major features (swap, pools, farms, IFO, lottery, prediction)
- Same tech stack (Next.js SSR, styled-components, ethers.js v5 with ABI coder 5.7.0)

Any past or future frontend vulnerability disclosed in PancakeSwap's codebase likely applies to FusionX. The fork relationship means security patches in PancakeSwap must be manually ported.

## Root cause
The frontend was forked from PancakeSwap without establishing an independent security review process. The fork divergence is unknown.

## Impact
If a critical frontend CVE is published for PancakeSwap's swap interface (e.g., permit injection, swap recipient manipulation, price display manipulation), FusionX users are at immediate risk before a patch can be ported and deployed.

## Attack path / preconditions
1. Security researcher or hacker discovers frontend vulnerability in PancakeSwap
2. Vulnerability is disclosed or exploited before FusionX team ports the fix
3. FusionX users are exposed until the fix is manually ported

## Recommendation
1. Establish a process to track PancakeSwap frontend security advisories and CVEs
2. Maintain a documented diff of all FusionX-specific changes against the PancakeSwap base
3. Run automated dependency scanning on the frontend repo (npm audit, Snyk, Dependabot)
4. Consider a one-time independent security review of the frontend codebase

## References
- PancakeSwap GitHub: https://github.com/pancakeswap/pancake-frontend
