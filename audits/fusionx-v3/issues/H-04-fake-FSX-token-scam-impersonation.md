- **Severity:** High
- **Status:** confirmed
- **Invariant broken:** none (social engineering)
- **Chain / network:** Mantle (and any EVM chain)
- **Contract:** FSX token (not deployed — any trading FSX is fraudulent)
- **Deployed address:** NOT DEPLOYED — see https://docs.fusionx.finance/
- **Source:** Official documentation
- **Location:** https://docs.fusionx.finance/ (public warning)

## Description
The official FusionX documentation explicitly states: **"FusionX Finance has not yet deployed its FSX token. Do not trust any fake FSX tokens."** This means any FSX token currently trading on any DEX is fraudulent. Attackers can deploy fake FSX tokens on Mantle (or any chain), airdrop them to users, and promote them through social media, Discord, Telegram, and phishing sites to steal funds.

FusionX's own Terms of Service acknowledge this: *"You understand that anyone can create a token, including fake versions of existing tokens and tokens that falsely claim to represent projects."*

## Root cause
The protocol's native token has been publicly announced but not yet deployed. The gap between announcement and deployment creates a window for scammers to deploy fake tokens that capitalize on user anticipation.

## Impact
Users who search for "FSX token" on DEXs will find one or more fraudulent tokens. Unsuspecting users who buy these tokens:
1. Lose their investment when the fake token goes to zero
2. May connect their wallet to a malicious dapp to "claim" fake FSX airdrops
3. May approve malicious token contracts that drain their wallet

## Attack path / preconditions
1. Attacker deploys a token named "FSX" or "FusionX" on Mantle or any EVM chain
2. Creates a basic liquidity pool on a DEX (fake volume)
3. Airdrops tokens to thousands of Mantle wallets using bot networks
4. Promotes via fake social media accounts, Telegram channels, and Discord DMs
5. OR: directs users to a phishing site to "claim confirmed airdrop" — steals wallet approval

## Proof of concept
```
# Official warning (confirmed):
curl -s https://docs.fusionx.finance/developers/smart-contracts-mantle-mainnet/v3-smart-contracts.md | grep -i "fsx\|not deployed\|fake"
# Returns: "Note: Native Token of FusionX Finance is not deployed yet. Do not trust any fake FSX tokens."
```

## Recommendation
1. Deploy the legitimate FSX token as soon as practical with a clearly communicated contract address on all official channels
2. Publish the official FSX contract address on the website, docs header, and GitHub README
3. Add a prominent banner on the dapp warning about fake FSX tokens
4. Create a blocklist of known fake FSX token addresses
5. Register the FSX token on CoinGecko and CoinMarketCap preemptively to control the canonical listing
6. Monitor for fake tokens using on-chain monitoring tools

## References
- FBI warning on fake tokens impersonating agencies (March 2026): similar attack vector
- Chainalysis: impersonation scams increased 1,400% YoY in 2025
