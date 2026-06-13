# [M] transferToken Subtracts fusionXAmountBelongToMC From Collected RFUSIONX Fees — Users Underpaid

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-MC-02 — fusionXAmountBelongToMC ≤ RFUSIONX.balanceOf(this)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`transferToken`, `collectTo`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L630-L653`

## Description

When a V3 pool uses RFUSIONX as one of its pool tokens, `collectTo()` calls `transferToken(RFUSIONX, to)` which subtracts `fusionXAmountBelongToMC` from the collected fee balance before sending to the user. This means users collecting fees in RFUSIONX receive less than their actual collected amount — the reward tracking fund eats into their fee payout.

Additionally, `transferToken` and `sweepToken` share a similar clipping pattern in their else branches that silently resets `fusionXAmountBelongToMC` when balance is insufficient.

## Root cause

```solidity
// LBPMasterChefV3.sol:L630-L653
function transferToken(address _token, address _to) internal {
    uint256 balance = IERC20(_token).balanceOf(address(this));
    if (_token == address(RFUSIONX)) {
        unchecked {
            if (balance >= fusionXAmountBelongToMC) {
                balance -= fusionXAmountBelongToMC;  // Fee payout reduced by reward funds
            } else {
                fusionXAmountBelongToMC = balance;   // Clipping — silently eats tracked amount
                balance = 0;
            }
        }
    }
    // ... sends balance to _to
}
```

And in `collectTo()` (L610-625), after collecting fees from the pool to MasterChef, the collected fees are forwarded via `transferToken`. If the pool token is RFUSIONX, the fee collection interacts with reward accounting.

## Impact

- **Direct financial loss:** Users collecting fees from a RFUSIONX pool receive less than their actual collected amount because `fusionXAmountBelongToMC` is subtracted from the available balance
- **Accounting corruption:** The clipping branches silently reset tracked amounts, creating persistent state corruption
- **Exploit vector:** Any user who creates a pool with RFUSIONX as a token (factory allows any token pair with valid fee tier), provides liquidity, stakes in MC, and generates fees can manipulate reward accounting

## Attack path / preconditions

1. Factory permits creating a pool with RFUSIONX as token0/token1 (any token pair with valid fee tier)
2. Attacker creates such a pool, provides liquidity, stakes position in MC
3. Attacker swaps to generate fees in RFUSIONX
4. Attacker calls `collectTo()` to collect fees
5. `transferToken(RFUSIONX)` subtracts `fusionXAmountBelongToMC` from the fee payout
6. Attacker either loses fees (if balance ≥ tracked) or corrupts accounting (if balance < tracked)

## Proof of concept

`POC: pending` — integration test:
1. Create pool with RFUSIONX/WMNT
2. Add liquidity, stake in MC
3. Swap to generate RFUSIONX fees
4. Call collectTo, verify fee payout is reduced by fusionXAmountBelongToMC

## Recommendation

Separate the reward tracking from fee collection. `transferToken` should not adjust `fusionXAmountBelongToMC` when forwarding collected fees. The fee collection and reward accounting should use separate balance tracking:

```diff
function transferToken(address _token, address _to) internal {
    uint256 balance = IERC20(_token).balanceOf(address(this));
    if (_token == address(RFUSIONX)) {
-       unchecked {
-           if (balance >= fusionXAmountBelongToMC) {
-               balance -= fusionXAmountBelongToMC;
-           } else {
-               fusionXAmountBelongToMC = balance;
-               balance = 0;
-           }
-       }
+       // Do not adjust fusionXAmountBelongToMC for fee collections
+       // Fee RFUSIONX and reward RFUSIONX are distinct pools
    }
    // send balance
}
```

## References

- **Trail of Bits lens:** Lead #4 (MEDIUM) — transferToken subtracts fusionXAmountBelongToMC
- **Forefy lens:** Lead F-04 (MEDIUM) — collectTo manipulates fusionXAmountBelongToMC via RFUSIONX pool tokens
- **Pashov lens:** Lead #9 (LOW) — transferToken sends full non-MC balance
- **Invariant:** INV-MC-02
