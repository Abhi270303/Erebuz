- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (off-chain)
- **Chain / network:** Mantle
- **Contract:** fusionx.finance (dapp)
- **Deployed address:** https://fusionx.finance
- **Source:** Next.js build manifest
- **Location:** /_next/static/chunks/*.js.map (potential)

## Description
The Next.js build ID (`SuAQo6RtEblDYX6i-dLgN`) is publicly exposed in the build manifest. If source maps are enabled in the production build, the full dapp source code — including internal API endpoints, configuration, and potentially sensitive logic — would be accessible at predictable chunk map file paths.

Passive verification was not possible without active HTTP requests to check for .map files.

## Root cause
Next.js generates source maps by default in development. Production builds may or may not disable them.

## Impact
If source maps are enabled, an attacker can:
- Reverse-engineer the full frontend source code
- Identify subgraph/API endpoints
- Find any hardcoded test keys or internal URLs
- Study the code for client-side vulnerabilities

## Recommendation
1. Verify source maps are disabled:
   ```bash
   curl -o /dev/null -s -w "%{http_code}" https://fusionx.finance/_next/static/chunks/pages/swap-*.js.map
   ```
   (Expect 404; if 200, source maps are exposed)
2. In `next.config.js`, ensure `productionBrowserSourceMaps: false` (default)
3. Consider removing the build ID from the manifest or using a CDN that blocks `.map` files

## References
- Next.js Source Maps: https://nextjs.org/docs/advanced-features/source-maps
