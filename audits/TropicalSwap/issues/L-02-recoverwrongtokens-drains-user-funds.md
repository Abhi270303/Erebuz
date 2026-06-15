# L-02 ZapV1 owner can drain any token via recoverWrongTokens without safeguards

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (centralization risk)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalZapV1` (`recoverWrongTokens`)
- **Deployed address:** TBD
- **Source:** source code (GitHub)
- **Location:** `TropicalZapV1.sol:L179-L182`

## Description

The `onlyOwner` function `recoverWrongTokens()` can transfer **any ERC20 token** from the Zap contract with no safeguards — no token whitelist, no amount cap, no timelock. During active zap operations, user funds temporarily reside in the contract (after `transferFrom` but before `addLiquidity`). A compromised or malicious owner can drain these mid-operation funds.

Additionally, LP tokens held by the Zap contract (from prior zap operations) and any accumulated residual tokens can be withdrawn at any time.

## Root cause

```solidity
function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
    IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
}
```

No token whitelist, no pending-operation check, no timelock.

## Impact

- **Complete loss of user funds if the owner key is compromised** — all token balances in Zap contract are withdrawable
- Users have no guarantee that tokens sent to Zap (during zapIn approval) will not be extracted before the operation completes
- Standard centralization risk for a single-EOA owner (no multisig detected)

## Attack path / preconditions

1. Owner EOA key is compromised
2. Attacker calls `recoverWrongTokens(LPToken, all)` — drains LP tokens
3. Attacker calls `recoverWrongTokens(WMANTLE, all)` — drains ETH equivalent
4. All tokens held by the Zap contract are stolen

## Proof of concept

```
POC: not required — code is clear
```

## Recommendation

1. **Add a token whitelist** — only pre-approved tokens can be recovered
2. **Add a timelock** (e.g., 48-hour delay) for recovery operations
3. **Recommend multisig** for the owner role
4. **Check no pending operations** before allowing recovery

```diff
+ address[] public recoveryWhitelist;
+ uint256 public constant RECOVERY_DELAY = 2 days;
+ mapping(address => uint256) public recoveryScheduled;

  function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
+     require(recoveryWhitelist.contains(_tokenAddress), "token not whitelisted");
+     require(block.timestamp >= recoveryScheduled[_tokenAddress], "delay not elapsed");
      IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
      emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
  }
```

## References

- pashov (pashov-010) — recoverWrongTokens allows owner to drain without safeguards (L)
- solodit (SOL-009) — Owner recoverWrongTokens can drain any token (M — re-assessed to L)
- Common Code4rena finding: "Centralization risk: owner can drain contract"
