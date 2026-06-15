- **Severity:** Medium
- **Status:** confirmed
- **Invariant broken:** none (social engineering)
- **Chain / network:** off-chain — Discord, Telegram, Twitter
- **Contract:** fusionx.finance (community channels)
- **Deployed address:** https://discord.gg/fusionx, https://t.me/fusionx_finance, https://twitter.com/FusionX_Finance
- **Source:** Public community platforms
- **Location:** FusionX website footer

## Description
FusionX's user support is handled entirely through public Discord and Telegram channels. Anyone can join these channels, rename themselves to match admin/mod nicknames, and offer fake support to users. Attackers can impersonate FusionX staff to:

1. Offer fake "wallet recovery" services that steal seed phrases
2. Promote fake FSX token airdrops with phishing links
3. Share links to fake dapp interfaces that drain wallets
4. Create fake Telegram groups with similar names (e.g., "FusionX Announcements" vs "FusionX_Announcements")

No identity verification system, official ticketing system, or audit trail exists for support interactions. Discord mods have no cryptographic proof of affiliation visible to users.

## Root cause
Community-based support model without verification infrastructure. No formal ticketing system, no staff verification badges, and no published official support process.

## Impact
Users seeking help in community channels are indistinguishable from scammers. A new user joining the Discord cannot verify which "admin" is genuine. This enables:
- Targeted phishing of users who ask for help publically (attackers DM them with "I'm a mod, what's the issue?")
- Bulk phishing via fake announcements in Telegram
- Seed phrase theft via fake wallet recovery services

## Attack path / preconditions
1. User joins FusionX Discord with a question about a failed swap
2. Attacker monitoring the channel DMs the user: "I'm a FusionX mod, I can help you with that"
3. Attacker directs user to a fake "wallet verification" site that steals the seed phrase
4. OR: Attacker asks the user to "approve a test transaction" via a malicious dapp

## Recommendation
1. Implement a verified support ticketing system (Zendesk, Freshdesk, or Intercom)
2. Add a Discord bot that auto-warns about DMs from non-staff accounts
3. Publish the official support process on docs.fusionx.finance with a clear statement: "FusionX staff will NEVER DM you first"
4. Add a website support widget that redirects to the ticketing system
5. Create verified roles on Discord with color-coded badges visible to all users
6. Pin an announcement in every channel about how to identify official staff
7. Set Telegram groups to have slow mode + require admin approval for new joins

## References
- Mountain Wolf: Impersonation scams in crypto — Discord/Telegram are primary vectors
- Kaspersky (2025): Telegram scam report — fake token airdrops and support impersonation
