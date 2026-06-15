- **Severity:** Low
- **Status:** confirmed
- **Invariant broken:** none (off-chain)
- **Chain / network:** Mantle
- **Contract:** fusionx.finance (dapp)
- **Deployed address:** https://fusionx.finance
- **Source:** N/A
- **Location:** /.well-known/security.txt

## Description
The FusionX dapp has no vulnerability disclosure policy. No `security.txt` file exists at `/.well-known/security.txt`, no security contact email is listed on the website, documentation, or GitHub repos, and there is no bug bounty program.

## Root cause
Security contact and disclosure infrastructure not implemented.

## Impact
Security researchers who discover vulnerabilities have no clear channel to report them responsibly. This increases the likelihood that vulnerabilities are disclosed publicly or exploited before the team is notified.

## Recommendation
1. Create a `security.txt` file at `https://fusionx.finance/.well-known/security.txt`
2. Establish a dedicated security contact email or PGP-encrypted channel
3. Consider launching a bug bounty program on a platform like Immunefi

Example `security.txt`:
```
Contact: mailto:security@fusionx.finance
Encryption: https://fusionx.finance/pgp-key.txt
Preferred-Languages: en
Policy: https://fusionx.finance/security-policy
```

## References
- security.txt RFC 9116: https://www.rfc-editor.org/rfc/rfc9116
