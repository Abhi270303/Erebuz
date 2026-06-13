# H-02: IncentivizedERC20 → ChefIncentivesController → onwardIncentives Reentrancy Bridge

| Field | Value |
|-------|-------|
| **Severity** | CRITICAL |
| **Status** | unconfirmed |
| **Invariants broken** | INV-12 (MISSING), INV-11 (MISSING — amplifying) |
| **Contracts** | `IncentivizedERC20.sol`, `ChefIncentivesController.sol`, `AToken.sol` |
| **Functions** | `IncentivizedERC20._transfer()`, `ChefIncentivesController.handleAction()`, `AToken._transfer()` |
| **Line ranges** | IncentivizedERC20 L176–L230, ChefIncentivesController L224–L245, AToken L380–L401 |
| **Source files** | `/protocol/tokenization/IncentivizedERC20.sol`, `/staking/ChefIncentivesController.sol`, `/protocol/tokenization/AToken.sol` |

---

## Description

Every aToken and debtToken transfer, mint, or burn triggers a chain of external calls that can bridge back into the LendingPool — **without any reentrancy protection**.

### The call chain

```
aToken.transfer(recipient, amount)
  └─ IncentivizedERC20._transfer(sender, recipient, amount)
       ├─ _balances state updated (L186–189)     ← STATE MUTATED BEFORE EXTERNAL CALL
       ├─ IncentivesController.handleAction(sender, ...) (L193)
       │    └─ ChefIncentivesController.handleAction() (L224)
       │         ├─ _updatePool() (L228)
       │         ├─ user.amount = _balance (L238)
       │         └─ pool.onwardIncentives.handleAction() (L242)  ← ARBITRARY EXTERNAL CALL
       │              └─ [MALICIOUS CONTRACT] → re-enters LendingPool
       └─ IncentivesController.handleAction(recipient, ...) (L195)
```

### Key vulnerability points

1. **State mutation before call (IncentivizedERC20 L186–189 → L191–197)**: `_balances` is updated **before** the external call to the incentives controller. Any re-entered function sees the post-transfer state.

2. **Two external call hops**: The callback goes through `ChefIncentivesController.handleAction()` → `onwardIncentives.handleAction()` — two external call layers with no reentrancy mutex between them.

3. **OnwardIncentives is settable by owner**: `ChefIncentivesController.setOnwardIncentives()` (L136–L142) lets the owner register any contract as the onward incentives handler. While the owner is trusted, this creates a centralization surface that, if ever compromised, allows the bridge to be activated.

4. **AToken._transfer() calls pool.finalizeTransfer() AFTER super._transfer()** (AToken L394–L398): The `pool.finalizeTransfer()` health-factor check runs after the incentives callbacks. A re-entered pool operation during the callback can modify state before the health check validates it.

### Concrete exploit scenarios

**Scenario A — Malicious onwardIncentives (owner-compromise or misconfiguration)**:
1. Owner sets a malicious `onwardIncentives` contract (or an attacker compromises the owner key)
2. Any normal aToken transfer triggers the bridge
3. The malicious contract re-enters `LendingPool.borrow()` on behalf of the sender
4. The re-entrant borrow succeeds because the post-transfer state shows the sender with sufficient collateral
5. After the callback, `finalizeTransfer()` checks health factor using **post-borrow state** (inflated debt), potentially reverting the transfer (DoS) — but the attacker may have already extracted value

**Scenario B — Read-only reentrancy (no owner compromise needed)**:
1. A protocol that depends on aToken `balanceOf()` calls is exploited during the transfer callback
2. The balance update happens before the callback, so the reading contract sees the post-transfer balance
3. This is exploitable by any contract that reads aToken balances as part of its state validation

## Impact

This finding is the **cross-contract reentrancy bridge** that amplifies H-01 (flashLoan reentrancy). Combined:

- FlashLoan receiver re-enters via the flashLoan callback (H-01)
- During that re-entry, performs a simple aToken transfer on another asset
- The transfer triggers the incentives bridge (H-02), giving the attacker an additional reentry point with post-transfer state
- The attacker can manipulate multiple LendingPool states in a single transaction

Even without the flashLoan, any aToken transfer is an attack surface — this is **every deposit, every withdrawal, every transfer of aTokens**.

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | lead 2 | HIGH |
| **trailofbits** | lead 3 | HIGH |
| **forefy** | forefy-002 | CRITICAL |
| **solodit** | SOLODIT-002 | HIGH |
| **invariant** | lead 2 | HIGH |

All 5 hunters independently identified this bridge from different angles. Forefy rated it CRITICAL due to the amplification with other findings.

## Historical Precedent

- **ConvexMasterChef (Code4rena 2022 #313)**: Reward token accounting update after transfer — if reward token has hooks (ERC777), attacker re-enters and drains rewards.
- **VMEX (Hats Finance 2023 #14)**: Incorrect access control in `IncentivesController.handleAction()` — anyone could impersonate an aToken.
- **Radiant V2 (OpenZeppelin audit 2023)**: Reentrancy via `handleActionAfter` hook through eligibility updates.

## Recommendation

1. Add `nonReentrant` modifier to all LendingPool functions (see H-01)
2. In `ChefIncentivesController.handleAction()`, consider removing the `onwardIncentives` external call, or add a reentrancy mutex
3. Move the `_balances` update in `IncentivizedERC20._transfer()` to **after** the incentives controller call (CEI pattern)
4. Document that any reentrancy in LendingPool is amplified by this bridge

## POC Needs (Phase 9)

- Fork test: Set `onwardIncentives` to a malicious contract on a fork
- Trigger an aToken transfer
- Observe the re-entered pool state and verify HV/collateral manipulation
- Chain with H-01: flashLoan → re-enter borrow → re-enter via token transfer bridge
