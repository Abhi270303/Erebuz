- **Severity:** Medium
- **Status:** confirmed
- **Chain / network:** off-chain — email
- **Contract:** agni.finance (email infrastructure)
- **Location:** DNS TXT records

## Description
DMARC is set to `p=quarantine` (move to spam) instead of `p=reject`. Combined with SPF softfail (`~all`), a sophisticated attacker can still spoof `@agni.finance` email successfully against recipients whose email provider does not honor quarantine, or against users who check their spam folder.

DKIM is properly configured (Google Workspace DKIM key published), which means the team can safely upgrade DMARC to `p=reject` without risking legitimate email rejection.

## Root cause
DMARC policy not hardened to `p=reject`; SPF uses `~all` instead of `-all`.

## Impact
Phishing emails from `@agni.finance` can reach user inboxes if the recipient's provider treats quarantine as advisory. Team members using non-Google email providers are particularly at risk.

## Attack path / preconditions
1. Attacker sends email with spoofed `From: support@agni.finance`
2. SPF softfail (`~all`) does not hard-reject
3. DMARC `p=quarantine` moves to spam — but some providers or users still see it
4. Email appears to come from the legitimate Agni domain

## Proof of concept
```bash
dig TXT _dmarc.agni.finance +short
# "v=DMARC1;p=quarantine;pct=100;fo=1; rua=mailto:dmarc-reports@agni.finance"

dig TXT agni.finance +short | grep spf
# "v=spf1 include:_spf.google.com ~all"
```

## Recommendation
```diff
- DMARC: "v=DMARC1;p=quarantine;pct=100;fo=1; rua=mailto:dmarc-reports@agni.finance"
+ DMARC: "v=DMARC1;p=reject;pct=100;fo=1; rua=mailto:dmarc-reports@agni.finance"
- SPF: "v=spf1 include:_spf.google.com ~all"
+ SPF: "v=spf1 include:_spf.google.com -all"
```
Verify DKIM signing works for all legitimate email before changing SPF to hardfail.

## References
- DMARC.org best practices
- RFC 7489 DMARC specification
