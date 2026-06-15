- **Severity:** Info
- **Status:** confirmed
- **Chain / network:** off-chain
- **Contract:** agni.finance (community)
- **Location:** discord.gg/H3YrfAkrGc, t.me/AgniDEXCommunity, @Agnidex

## Description
Agni Finance uses public Discord and Telegram for community support. Anyone can join, rename to match moderator names, and impersonate staff. Combined with the GTM attack surface (M-04), this enables a multi-vector phishing kill chain: fake support DMs → links to fake dapp interface → wallet drainer.

## Assessment
This is standard for DeFi projects and not unique to Agni. Flagged as Info because:
1. No identity verification on community channels
2. No published "staff will never DM first" policy
3. No audit trail for support interactions
4. No official ticketing system

## Recommendation
- Publish official support policy: "Agni Finance staff will NEVER DM you first"
- Add verification badges on Discord for official team members
- Consider a ticketing system (Zendesk, Freshdesk) for sensitive support requests
- Pin anti-phishing warnings in all community channels
