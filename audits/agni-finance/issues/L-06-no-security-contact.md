- **Severity:** Low
- **Status:** confirmed
- **Chain / network:** off-chain
- **Contract:** agni.finance
- **Location:** /.well-known/security.txt, website, GitHub

## Description
No security.txt, no bug bounty, and no security contact email is published anywhere on the agni.finance website, docs, or GitHub repository. Security researchers who discover vulnerabilities have no clear channel to report them, increasing the risk of public disclosure or exploitation before the team is notified.

## Root cause
Security disclosure process not implemented.

## Impact
Researchers may disclose vulnerabilities publicly (via Twitter, GitHub issues, or forums) before the team is aware, giving attackers a head start on exploitation.

## Recommendation
```diff
+ Create /.well-known/security.txt with:
+   Contact: mailto:security@agni.finance
+   Encryption: https://keys.openpgp.org/...
+   Preferred-Languages: en
```
- Establish a security@agni.finance email alias
- Consider listing on Immunefi or similar bug bounty platform

## References
- RFC 9116: security.txt
- Same class as FusionX L-08
