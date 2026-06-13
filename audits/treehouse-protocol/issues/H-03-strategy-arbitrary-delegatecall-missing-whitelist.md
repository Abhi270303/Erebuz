# H-03: Strategy Arbitrary Delegatecall via Missing Action Whitelist Enforcement

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** INV-5 (Only executor can execute strategies)
- **Chain / network:** ethereum (chainId 1)
- **Contracts:** Strategy, ActionExecutor, StrategyStorage, ActionRegistry
- **Source:** verified
- **Location:**
  - `strategy/Strategy.sol:L40-L45` — `callExecute()` checks executor but NOT whitelisted action
  - `strategy/Strategy.sol:L53-L68` — `execute()` uses `delegatecall` with arbitrary `_target`/`_data`
  - `strategy/StrategyStorage.sol:L44` — `isActionWhitelisted()` exists but is never called from Strategy

## Description

`Strategy.callExecute()` at line 40 verifies that `msg.sender == strategyStorage.strategyExecutor()`, but it never verifies that `_target` is a whitelisted action via `strategyStorage.isActionWhitelisted(_target)`. The whitelist function exists in `StrategyStorage` but is **not called anywhere in the Strategy contract**.

Since `Strategy.execute()` at line 53 uses `delegatecall` (via inline assembly at line 57-67), a strategy executor can cause the Strategy to delegatecall into any arbitrary address. This gives the target full control over the Strategy's storage context and, by extension, any assets accessible through the Strategy's Vault privileges.

Additionally, the `ActionRegistry` supports immediate rollback via `revertToPreviousAddress()` with no timelock. A compromised owner could register a malicious action, whitelist it, and have the executor call it — all in one transaction.

**Delegatecall storage collision risk:** The delegatecall chain (`StrategyExecutor → Strategy → ActionExecutor → Action contracts`) means all action contracts share the Strategy's storage. If any action contract writes to a storage slot that Strategy uses, corruption occurs. This was previously flagged as TOB-TETH-5 (Trail of Bits tETH audit, Sep 2024).

## Root cause

Two root causes:
1. **Missing whitelist check**: `Strategy.callExecute()` authenticates the caller but not the target. `isActionWhitelisted()` exists in storage but is dead code.
2. **No timelock on action upgrades**: `ActionRegistry.revertToPreviousAddress()` is immediate, allowing one-transaction action swaps.

## Impact

- **If `strategyExecutor` is compromised** or is a malicious contract: the entire Vault can be drained via the Strategy's `withdraw` privileges (Vault.withdraw() at Vault.sol:L64 allows active strategies to pull whitelisted assets).
- **If owner is compromised**: can register malicious actions, whitelist them, and have executor call them. Immediate, one-transaction drain.
- **If a future action contract writes to colliding storage slots**: strategy state corruption, potentially bricking the strategy or diverting assets.

## Attack path

1. Owner registers a malicious action contract in `ActionRegistry`.
2. Owner (or strategy executor) whitelists the malicious action.
3. Executor calls `StrategyExecutor.executeOnStrategy()` which triggers the delegatecall chain.
4. Malicious action runs in Strategy's delegatecall context.
5. Malicious action calls `Vault.withdraw(wstETH, type(uint).max)` — Vault sees Strategy as active and whitelisted.
6. All wstETH is transferred from Vault to the malicious action's address.
7. Attacker can withdraw from the malicious action contract.

## Proof of concept

`POC: pending` — Foundry fork test:
1. Deploy a malicious action contract that calls `Vault.withdraw(wstETH, attacker, balance)`
2. Register it in ActionRegistry (requires owner)
3. Whitelist it for a strategy (requires owner/strategyExecutor)
4. Execute via `StrategyExecutor.executeOnStrategy()`
5. Verify Vault wstETH transferred to attacker

## References

- **pashov-003**: Strategy.callExecute lacks action whitelist enforcement
- **trailofbits-04**: Strategy delegatecall chain supply chain risk (ActionRegistry)
- **solodit-005**: Delegatecall storage collision risk (TOB-TETH-5)
- **ToB Audit TOB-TETH-5**: Dangerous use of delegatecall in strategy system

## Recommendation

1. **Add whitelist check to `Strategy.callExecute()`:**
   ```diff
   function callExecute(address _target, bytes memory _data) external payable returns (bytes32 _response) {
       if (msg.sender != strategyStorage.strategyExecutor()) revert Unauthorized();
   +    if (!strategyStorage.isActionWhitelisted(_target)) revert Unauthorized();
       if (_target == address(0)) revert Failed();
       _response = IStrategy(address(this)).execute{ value: msg.value }(_target, _data);
   }
   ```
2. Add a timelock to `ActionRegistry.revertToPreviousAddress()` and action changes.
3. Ensure all current and future action contracts have storage layouts that do not collide with Strategy's two-slot layout (`vault` and `strategyStorage`, both `immutable` — currently safe, but future changes could break this).
