# [M] MasterChef refund() Sends Entire Contract ETH Balance Instead of Refund Surplus Only

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** None (spec quality / value leak)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`refund`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L563-L570`

## Description

When the WETH path is used in `increaseLiquidity` and `msg.value > 0`, the `refund()` internal function sends `address(this).balance` to the caller — the entire ETH balance of the contract — instead of only the overpaid/surplus amount. Any ETH accumulated from other users' operations (deposits, refund leftovers, direct sends) is drained to the refund caller.

## Root cause

```solidity
function refund(address _token, uint256 _amount) internal {
    if (_token == WETH && msg.value > 0) {
        nonfungiblePositionManager.refundETH();
        safeTransferETH(msg.sender, address(this).balance); // Sends ALL ETH
    } else {
        IERC20(_token).safeTransfer(msg.sender, _amount);   // Sends exactly _amount
    }
}
```

The WETH path sends `address(this).balance` (the entire contract balance). The ERC20 path correctly sends only `_amount`. There is no calculation of the actual surplus; the function assumes the entire balance belongs to `msg.sender`.

## Impact

- **Value leak:** If multiple users' ETH has accumulated in the contract, a single refund call drains all of it to one user
- **Accumulation sources:** Other users' `increaseLiquidity` deposits, `unwrapWETH9` leftovers, direct ETH sends
- **Exploitability:** An attacker can call `increaseLiquidity` with a deliberately large `msg.value` for a WETH pool, then the refund sends the entire contract ETH balance

## Attack path / preconditions

1. User A deposits via `increaseLiquidity` with 10 ETH for a WETH pool, gets refund of 9.5 ETH (500 wei left as dust)
2. User B deposits via `increaseLiquidity` with 1 ETH, gets refund of 1 ETH + A's 500 wei (because `address(this).balance` includes A's leftover)
3. Attacker deliberately sends large `msg.value` to extract all accumulated ETH

## Proof of concept

`POC: pending` — fork test:
1. Send 1 ETH directly to MasterChef (simulating accumulated dust)
2. Call `increaseLiquidity` with 0.1 ETH for a WETH pool
3. Verify refund sends 1.1 ETH (entire balance) rather than just the 0.1 ETH overpayment

## Recommendation

Calculate the surplus amount explicitly and send only that:

```diff
function refund(address _token, uint256 _amount) internal {
    if (_token == WETH && msg.value > 0) {
        nonfungiblePositionManager.refundETH();
-       safeTransferETH(msg.sender, address(this).balance);
+       uint256 refundAmount = address(this).balance;
+       if (refundAmount > 0) {
+           safeTransferETH(msg.sender, refundAmount);
+       }
    } else {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
```

Note: A proper fix requires tracking `msg.value` per-caller and computing the actual surplus. The minimal fix above still sends the entire balance — the real fix should store `msg.value` used and only refund the surplus over the actual swap cost.

## References

- **Pashov lens:** Lead #5 (MEDIUM) — refund sends entire ETH balance
- **Trail of Bits lens:** Lead #8 (LOW) — refund sends entire ETH balance instead of refund amount
- **Pashov report:** "Exploit chain: User A deposits 10 ETH, gets refund of 9.5 ETH, User B deposits 1 ETH, gets refund of 1.5 ETH (includes A's leftover)"
- This issue was also flagged in the x-ray report (Issue #5: "MasterChef refund could drain ETH")
