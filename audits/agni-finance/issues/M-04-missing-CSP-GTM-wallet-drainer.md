- **Severity:** Medium
- **Status:** confirmed
- **Chain / network:** off-chain — web
- **Contract:** agni.finance (dapp)
- **Location:** HTTP response headers + GTM tag

## Description
Agni Finance has no Content-Security-Policy (CSP) header. Google Tag Manager (`GTM-TLF66T4`) is loaded on every page. If the GTM account is compromised (credential theft, insider threat, supply chain), an attacker can inject arbitrary JavaScript — including a wallet drainer — into every page view across the entire dapp.

This is the same finding class as FusionX M-15. GTM is a high-value target because it allows arbitrary script injection without code deployment.

## Root cause
CSP header not configured; GTM container has no script-allowlist restriction.

## Impact
Complete dapp takeover via GTM compromise: wallet drainer scripts, fake transaction requests, seed phrase phishing.

## Attack path / preconditions
1. Attacker compromises GTM-TLF66T4 account (phishing, credential stuffing, insider)
2. Injects malicious JavaScript tag (e.g., wallet drainer, fake approve() prompt)
3. Every visitor to agni.finance executes the injected code
4. Users signing transactions have funds drained

## Proof of concept
```bash
curl -sI https://agni.finance | grep -i content-security-policy
# (no output — CSP missing)

curl -s https://agni.finance | grep -o "GTM-[A-Z0-9]*"
# GTM-TLF66T4
```

## Recommendation
```diff
+ Content-Security-Policy: default-src 'self'; script-src 'self' https://www.googletagmanager.com https://ssl.google-analytics.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; frame-ancestors 'none'; base-uri 'none'
```
- Restrict GTM container permissions to read-only for non-admin users
- Audit GTM users regularly
- Add report-uri for CSP violation monitoring

## References
- Same class as FusionX V3 M-15
- GTM compromise vector documented by numerous security researchers
