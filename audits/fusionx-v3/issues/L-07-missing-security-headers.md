- **Severity:** Low
- **Status:** confirmed
- **Invariant broken:** none (off-chain)
- **Chain / network:** Mantle
- **Contract:** fusionx.finance (dapp)
- **Deployed address:** https://fusionx.finance
- **Source:** HTTP response headers
- **Location:** All pages

## Description
The dapp is missing three standard security response headers:

1. **X-Frame-Options** — without this, the dapp can be embedded in an iframe, enabling clickjacking attacks where a malicious site overlays deceptive UI elements on top of the dapp's interface
2. **X-Content-Type-Options: nosniff** — without this, browsers may MIME-sniff resources, increasing the risk of script injection if an attacker can control any resource loaded by the dapp
3. **Referrer-Policy** — without this, the full URL (including potential sensitive parameters) may be sent in the Referer header to cross-origin destinations

## Root cause
Security headers not configured in Vercel deployment configuration or Next.js config.

## Impact
Low — clickjacking requires significant user interaction to be effective (must trick user into signing a transaction). MIME-sniffing risk is low since JS chunks are self-hosted.

## Attack path / preconditions
1. Attacker creates a phishing page that iframes fusionx.finance
2. Overlays transparent buttons over genuine dapp buttons
3. Tricks user into clicking "Confirm" on a fraudulent transaction

## Recommendation
```diff
+ X-Frame-Options: DENY
+ X-Content-Type-Options: nosniff
+ Referrer-Policy: strict-origin-when-cross-origin
```

Configure in `vercel.json` or Next.js `next.config.js` headers.

## References
- OWASP Clickjacking Defense: https://cheatsheetseries.owasp.org/cheatsheets/Clickjacking_Defense_Cheat_Sheet.html
