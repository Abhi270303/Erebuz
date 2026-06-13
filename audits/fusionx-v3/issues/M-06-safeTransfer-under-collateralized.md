# [M] _safeTransfer Under-Collateralized Reward Distribution — First Harvester Drains Entire Balance

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-MC-02 — fusionXAmountBelongToMC ≤ RFUSIONX.balanceOf(this)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`_safeTransfer`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L813-L829`

## Description

When `RFUSIONX.balanceOf(MasterChef) < pendingReward` (the contract is under-collateralized for rewards), `_safeTransfer()` silently caps `_amount = balance` and sends the entire remaining RFUSIONX balance to the first harvester. Subsequent harvesters receive 0 because the balance is exhausted. This is a first-come-first-served discontinuity in a system that should distribute proportionally.

## Root cause

```solidity
// LBPMasterChefV3.sol:L816-L829
uint256 balance = RFUSIONX.balanceOf(address(this));
if (balance < _amount) {
    _amount = balance;  // Silently reduces reward to full balance
}
// ... sends _amount (= balance) to the first harvester
// Subsequent harvesters will have balance = 0, _amount = 0
```

There is no revert, no proportional reduction, no warning — the first caller gets everything.

## Impact

- **Unfair reward distribution:** In an under-collateralized state, the first harvester receives all remaining rewards
- **Subsequent loss:** All other users with pending rewards receive 0
- **Compounds with H-02:** If the accounting inflation bug (H-02) causes `fusionXAmountBelongToMC` to inflate, the admin may believe rewards exist when they don't, preventing replenishment via `upkeep()`
- **Gas war risk:** Users will race to harvest first in under-collateralized states, creating MEV opportunities

## Attack path / preconditions

1. MC's RFUSIONX balance is less than cumulative pending rewards (e.g., due to sweepToken draining, accounting errors, or skipped upkeeps)
2. First harvester calls `harvest()` — receives the entire remaining balance
3. Second harvester calls `harvest()` — receives 0 because balance is 0
4. Both users had legitimate pending rewards but only one gets paid

## Proof of concept

`POC: pending` — unit test:
1. Deposit two positions into MC
2. Drain MC's RFUSIONX balance via token transfer (simulating accounting error)
3. Harvest position 1 → gets full remaining balance
4. Harvest position 2 → gets 0

## Recommendation

Revert instead of silently reducing the reward amount:

```diff
if (balance < _amount) {
-   _amount = balance;
+   revert("Insufficient RFUSIONX balance for reward");
}
```

This prevents silent underpayments and makes the under-collateralized state visible. The protocol can then replenish via `upkeep()` before users harvest.

## References

- **Trail of Bits lens:** Lead #9 (LOW) — _safeTransfer silent underpayment
- **Forefy lens:** Lead F-02 (HIGH) — _safeTransfer sends full balance when under-collateralized
- **Invariant:** INV-MC-02 (MISSING — edge cases can push fusionXAmountBelongToMC above balance)
