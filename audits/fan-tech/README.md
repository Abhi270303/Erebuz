# fan.tech Security Audit — Mantle Chain

**Protocol**: fan.tech (friend.tech V1 fork with bidding/gift additions)
**Chain**: Mantle (ID 5000)
**Date**: June 2026
**Scope**: FanTech & Gift contracts, ~94K MNT TVL (~$75K)

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 1 | `_getSupply` argument inversion → sell price cap |
| High | 2 | Unchecked refund calls, value accounting surplus |
| Medium | 1 | Owner EOA centralization |

## Exploitable Value (USD)

**$0 from existing pools.** The `_getSupply` bug (Critical) theoretically allows any single-share holder to drain an entire pool's liquid value, but no existing pool meets the necessary condition (supply=1). An attacker cannot create a supply=1 pool without the operator's signature.

**~$13.7K (17K MNT) permanently locked** due to value accounting divergence from unchecked refund failures. This MNT is in the contract but inaccessible through trading functions.

## Key Findings

| # | Title | Severity | Exploitable? |
|---|-------|----------|-------------|
| 001 | `_getSupply` increase-branch argument inversion | Critical | No (no supply=1 pools exist) |
| 002 | `_bidShares` unchecked external call | High | Partial (~17K MNT surplus locked) |
| 003 | Value accounting divergence | High | No (locked surplus) |
| 004 | Owner EOA centralization | Medium | Only by owner |

## Contract Addresses

- FanTech proxy: `0x53167401aeebFf5677C31E1DDA945628422D7Ed2`
- FanTech impl: `0x20aa28a1f66a6cbd97de8eb1907a5643eef7a108`
- Gift proxy: `0xD42A821E584513e18cFB77e56Bf635C551dE5D63`
- Gift impl: `0xca3c6da9ef077590b75c0d909e808fc07c40981e`
- Proxy admin: `0x6018536f5B58f6c1B550f6650f0b9127F3E59d0c` (EOA)
- Owner: `0xA6B6Fd8bC4A063805bd1174cf3902e3e6b2368E3` (EOA)

## On-chain State (Latest Block)

| Metric | Value | USD |
|--------|-------|-----|
| FT contract balance | 42,999 MNT | ~$34K |
| Gift contract balance | 51,059 MNT | ~$41K |
| Total tracked pool value | 25,801 MNT | ~$21K |
| Untracked surplus | 17,198 MNT | ~$13.7K |
| Pools found | 40 (of 7,309 subjects) | |
