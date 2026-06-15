- **Severity:** High
- **Status:** confirmed
- **Invariant broken:** none (social engineering)
- **Chain / network:** off-chain — email infrastructure
- **Contract:** fusionx.finance (email)
- **Deployed address:** N/A
- **Source:** DNS records
- **Location:** fusionx.finance TXT records, _dmarc.fusionx.finance

## Description
FusionX's email domain has SPF set to softfail (`~all`), no DKIM records, and no DMARC policy. Anyone can spoof `@fusionx.finance` email addresses. Attackers can send convincing phishing emails to team members (confirmed Google Workspace MX), users, or partners — appearing to come from the legitimate domain. Without DMARC rejection (`p=reject`), these emails pass all email authentication checks.

## Root cause
Email authentication is incomplete:
- SPF uses `~all` (softfail) instead of `-all` (hardfail)
- No DKIM signing key published
- No DMARC record published to tell receivers what to do with unauthenticated email

## Impact
An attacker can:
1. Spear-phish FusionX team members with emails from `admin@fusionx.finance`, `security@fusionx.finance`, or `ceo@fusionx.finance`
2. Phish users with fake airdrop announcements, wallet migration warnings, or security alerts
3. Impersonate FusionX to partners, exchanges, or listing platforms
4. Since Google Workspace is confirmed, the attacker can research team email addresses from the domain

## Attack path / preconditions
1. Attacker sends email with spoofed `From: support@fusionx.finance`
2. Email passes SPF (softfail — not rejected) and has no DMARC to enforce rejection
3. Receiver sees email from legitimate FusionX domain — trusts it
4. Email contains phishing link to fake dapp or requests seed phrase / private key

## Proof of concept
```
# Verify missing DMARC:
dig TXT _dmarc.fusionx.finance +short
# (returns nothing — no DMARC)

# Verify softfail SPF:
dig TXT fusionx.finance +short | grep spf
# "v=spf1 a mx ~all" — ~all means softfail, not hardfail

# Verify no DKIM:
dig TXT default._domainkey.fusionx.finance +short
# (returns nothing — no DKIM)
```

## Recommendation
```diff
+ DMARC: "v=DMARC1; p=reject; rua=mailto:dmarc-reports@fusionx.finance"
+ DKIM: Enable DKIM signing in Google Workspace → publish CNAME record
+ SPF: Change "v=spf1 a mx ~all" → "v=spf1 a mx -all"
```

Deploy in order: DKIM first, then DMARC p=quarantine (monitor), then DMARC p=reject, then SPF hardfail.

## References
- DMARC.org: https://dmarc.org/
- OWASP Email Security: https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html
