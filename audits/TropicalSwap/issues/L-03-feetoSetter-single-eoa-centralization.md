# L-03 Factory feeToSetter is a single EOA with full control over fee direction and rate

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** I-06 — Only feeToSetter changes feeTo/feeToSetter/fee (property itself is fine, but the implementation is fragile)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalFactory` (`setFeeTo`, `setFeeToSetter`, `updateTropicalFee`)
- **Deployed address:** TBD
- **Source:** source code (verified)
- **Location:** `TropicalFactory.sol:L69-L83`

## Description

All privileged factory functions (`setFeeTo`, `setFeeToSetter`, `updateTropicalFee`) are guarded only by `msg.sender == feeToSetter`. The `feeToSetter` is a single address (likely EOA) with:
- No multisig requirement
- No timelock
- No two-step ownership transfer

A compromised `feeToSetter` can:
1. Redirect all protocol fees to an attacker-controlled address (`setFeeTo`)
2. Transfer admin control to a new address (`setFeeToSetter`)
3. Set the protocol fee rate to the maximum (15 = 0.15%) (`updateTropicalFee`)

## Root cause

```solidity
function setFeeTo(address _feeTo) external {
    require(msg.sender == feeToSetter, 'Tropical: FORBIDDEN');
    feeTo = _feeTo;
}
function setFeeToSetter(address _feeToSetter) external {
    require(msg.sender == feeToSetter, 'Tropical: FORBIDDEN');
    feeToSetter = _feeToSetter;
}
function updateTropicalFee(uint8 _tropicalFee) external {
    require(msg.sender == feeToSetter, 'Tropical: FORBIDDEN');
    require(_tropicalFee <= MAX_TROPICAL_FEE, "Tropical: FORBIDDEN");
    tropicalFee = _tropicalFee;
}
```

## Impact

- **Protocol fee theft:** Attacker redirects fees to own address — at default 0.15% of swap volume, this could be significant over time
- **Permanent admin hijack:** `setFeeToSetter` can transfer control, removing the original admin's access permanently

## Attack path / preconditions

1. feeToSetter EOA key is compromised
2. Attacker calls `setFeeTo(attackerWallet)` — all future protocol fees go to attacker
3. Attacker calls `setFeeToSetter(attackerWallet2)` — permanent admin control
4. Optionally: Attacker calls `updateTropicalFee(15)` — maximum fee extraction

## Proof of concept

```
POC: not required — code is clear
```

## Recommendation

1. **Use a multisig** (e.g., 2/3 Gnosis Safe) for the feeToSetter role
2. **Add a timelock** (e.g., 48 hours) for fee-related changes
3. **Implement two-step ownership transfer** for `setFeeToSetter`:
   - Step 1: nominate a new feeToSetter
   - Step 2: new feeToSetter accepts the role

## References

- pashov (pashov-011) — feeToSetter is single EOA with full control (L)
- trailofbits (TB-09) — feeToSetter single-EOA centralization risk (L)
- Standard centralization finding — common to Uniswap V2 forks
