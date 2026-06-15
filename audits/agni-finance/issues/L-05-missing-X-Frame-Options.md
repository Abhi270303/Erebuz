- **Severity:** Low
- **Status:** confirmed
- **Chain / network:** off-chain — web
- **Contract:** agni.finance (dapp)
- **Location:** HTTP response headers

## Description
Agni Finance does not set `X-Frame-Options` or `Content-Security-Policy: frame-ancestors`. An attacker can embed the Agni dapp in an iframe on a malicious site and use social engineering (overlaid buttons, transparent overlays) to trick users into signing transactions or connecting wallets.

## Root cause
Missing frame-busting protection headers.

## Impact
Clickjacking attacks: users think they are clicking buttons on the attacker's site but are actually interacting with the Agni dapp in a hidden iframe.

## Attack path / preconditions
1. Attacker creates phishing page with invisible iframe of agni.finance/swap
2. Overlays fake UI elements (e.g., "Claim Airdrop" button) aligned over real swap/approve buttons
3. User clicks "Claim Airdrop" — actually signs a swap or token approval on Agni

## Proof of concept
```bash
curl -sI https://agni.finance | grep -iE "x-frame-options|frame-ancestors"
# (no output — both missing)
```

## Recommendation
```diff
+ X-Frame-Options: DENY
# OR equivalently via CSP:
+ Content-Security-Policy: frame-ancestors 'none'
```

## References
- OWASP Clickjacking Defense
- Same class as FusionX L-07 (missing headers)
