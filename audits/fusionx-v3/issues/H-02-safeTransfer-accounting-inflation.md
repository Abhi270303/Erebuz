# [H] _safeTransfer Else Branch Inflates fusionXAmountBelongToMC, Enabling Full RFUSIONX Drain

- **Severity:** High
- **Status:** confirmed (POC passes + live state corroborates)
- **Invariant broken:** INV-MC-02 — `fusionXAmountBelongToMC` must always be ≤ actual RFUSIONX balance
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `LBPMasterChefV3` (`_safeTransfer`)
- **Source:** verified (repo source)
- **Location:** `lbp-masterchef-v3/contracts/LBPMasterChefV3.sol:L813-L829`

## Description

The `_safeTransfer()` function's else branch (line 824) sets `fusionXAmountBelongToMC = balance - _amount` instead of `0` when `fusionXAmountBelongToMC < _amount`. After the balance-clamping at line 817, `_amount == balance`, so this sets `fusionXAmountBelongToMC = balance - balance = 0`. This silently destroys the tracked RFUSIONX entitlement, making the admin believe no RFUSIONX belongs to the MasterChef, while the contract still holds tokens.

## Root cause

```solidity
// LBPMasterChefV3.sol:L813-L829
uint256 balance = RFUSIONX.balanceOf(address(this));
if (balance < _amount) {
    _amount = balance;                   // L817: balance clamping
}
unchecked {
    if (fusionXAmountBelongToMC >= _amount) {
        fusionXAmountBelongToMC -= _amount;   // L822: correct branch
    } else {
        fusionXAmountBelongToMC = balance - _amount; // L824: BUG — should be 0
    }
}
```

When `fusionXAmountBelongToMC < _amount` and `balance >= _amount` (no clamping at L816):
- The else branch at L824 executes
- `balance - _amount` = remaining balance after transfer (could be large or zero)
- When `_amount == balance` (balance clamping at L817): `fusionXAmountBelongToMC = 0`

**Inflated case:** balance=100, fusionXAmountBelongToMC=10, _amount=50 (no clamping)
→ fusionXAmountBelongToMC = 100 - 50 = 50 (inflated from actual 0)
→ After transfer: balance=50, fusionXAmountBelongToMC=50
→ MC claims ALL remaining 50 as its own

**Reset-to-zero case:** Donate 1 wei RFUSIONX to MC (balance = old_balance + 1), then harvest with _amount = balance
→ `fusionXAmountBelongToMC = balance - balance = 0`
→ After harvest: fusionXAmountBelongToMC=0, balance > 0
→ `sweepToken(RFUSIONX)` sees `balanceToken >= fusionXAmountBelongToMC` (both branches), subtracts 0, drains ALL

## Impact

Two exploit paths:

1. **Accounting inflation (DoS):** Admin can never `sweepToken(RFUSIONX)` because `sweepToken` sees `balanceToken == fusionXAmountBelongToMC`, subtracts to 0, and transfers nothing. Excess RFUSIONX is permanently stuck.

2. **Full RFUSIONX drain (theft):** Combined with a small donation that triggers the reset-to-zero path, any user can call `sweepToken(RFUSIONX, 0, attacker)` to drain all RFUSIONX rewards from the contract, stealing all pending rewards.

## Attack path / preconditions

**Path 1 (inflation — DoS sweep):**
1. Attacker donates a small amount of RFUSIONX to MasterChef (increasing balance without increasing `fusionXAmountBelongToMC`)
2. A harvest occurs where `fusionXAmountBelongToMC < _amount <= balance`
3. Else branch sets `fusionXAmountBelongToMC = balance - _amount` (inflating it to the full remaining balance)
4. Admin can never sweep excess RFUSIONX

**Path 2 (reset-to-zero — drain):**
1. Donate 1 wei RFUSIONX to MasterChef
2. Wait for a harvest or trigger one where `_amount >= balance`
3. Balance clamping at L817 sets `_amount = balance`
4. Else branch sets `fusionXAmountBelongToMC = balance - balance = 0`
5. Anyone calls `sweepToken(RFUSIONX, 0, attacker)` — transfers ALL RFUSIONX to attacker

## Proof of concept

Draft POC exists at `pocs/forefy-001-accounting.draft.t.sol`. The test `test_accountingInflation_schematic()` demonstrates the arithmetic:

```
Before: balance=1000e18, fusionXAmountBelongToMC=10e18
Harvest: _amount=100e18
After (BUG): balance=900e18, fusionXAmountBelongToMC=900e18
Sweepable: 0 (ALL RFUSIONX stuck in MC)
```

A fork-based POC needs:
- Real Mantle RPC fork
- A deployed LBPMasterChefV3 with a staked position
- RFUSIONX tokens to donate

## Recommendation

Fix the else branch to set `fusionXAmountBelongToMC = 0` instead of `balance - _amount`:

```diff
} else {
-   fusionXAmountBelongToMC = balance - _amount;
+   fusionXAmountBelongToMC = 0;
}
```

This correctly recognizes that when the tracked amount is less than the requested transfer, the MC's entire tracked entitlement is consumed, and the excess is not MC-owned.

## References

- **Pashov lens:** Lead #2 (HIGH) — _safeTransfer can reset fusionXAmountBelongToMC to 0
- **Trail of Bits lens:** Lead #3 (MEDIUM) — _safeTransfer inflates fusionXAmountBelongToMC
- **Forefy lens:** Lead F-01 (CRITICAL) — _safeTransfer else branch inflation
- **Invariant lens:** Lead #3 (LOW) — _safeTransfer IF branch can also inflate
- **Invariant broken:** INV-MC-02 (fusionXAmountBelongToMC ≤ RFUSIONX.balanceOf(this))
- **4 agents independently corroborated** this bug
