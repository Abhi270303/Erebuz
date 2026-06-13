# H-03: PoolDeployer.setFactoryAddress() Lacks Access Control — Front-Runnable Initialization

- **Severity:** High
- **Status:** unconfirmed
- **Invariant broken:** INV-07 (Pool address is deterministic and verifiable — violated if a malicious actor front-runs setFactoryAddress)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPoolDeployer (`setFactoryAddress`, `deploy`)
- **Deployed address:** N/A (deployment-time vulnerability)
- **Source:** verified
- **Location:** source/core/AgniPoolDeployer.sol:L29-L35

## Description

`AgniPoolDeployer.setFactoryAddress()` has no access control — it only requires that `factoryAddress` is currently `address(0)`. Any address can call this function before the legitimate factory does, permanently locking the deployer to a malicious factory. The `AgniFactory` constructor stores the `poolDeployer` address but does NOT atomically call `setFactoryAddress()` back on the deployer, leaving a window for front-running.

Once a malicious actor takes control of the deployer, they can call `deploy()` (gated by `onlyFactory`, which they satisfy) to create pools with arbitrary parameters (token0, token1, fee, tickSpacing). The legitimate factory would be unable to deploy any pools, and the incorrect pools would occupy the deterministic CREATE2 addresses that the periphery contracts compute.

## Root cause

```solidity
// AgniPoolDeployer.sol:L29-L35
function setFactoryAddress(address _factoryAddress) external {
    require(factoryAddress == address(0), "already initialized");
    factoryAddress = _factoryAddress;
    emit SetFactoryAddress(_factoryAddress);
}
```

The function has no `onlyOwner` modifier or any caller restriction. The `AgniFactory` constructor (L36-57) accepts `_poolDeployer` as a parameter and stores it, but never calls `setFactoryAddress()` on the deployer. This means the two contracts are deployed separately, and the `setFactoryAddress()` call must happen in a separate transaction — creating a front-running window.

## Impact

If exploited during deployment:

- **Legitimate factory cannot deploy pools**: All `createPool()` calls will fail because `deploy()` checks `msg.sender == factory` (which is now the attacker's address)
- **Attacker deploys malicious pools**: The attacker can deploy pools at the deterministic CREATE2 addresses, potentially with extreme fee configurations or manipulated parameters
- **Permanent damage**: `setFactoryAddress()` can only be called once (guarded by `factoryAddress == address(0)`), so the error is irreversible. A new `AgniPoolDeployer` must be deployed and all address references updated everywhere

## Attack path / preconditions

1. Legitimate deployer deploys `AgniPoolDeployer` contract (in transaction A)
2. Legitimate deployer deploys `AgniFactory` with `_poolDeployer` set to the deployer (in transaction B)
3. Attacker front-runs transaction B and calls `setFactoryAddress(attackerAddress)` on the deployer (in transaction C between A and B)
4. `AgniFactory` constructor completes — but the deployer's factory address is now the attacker
5. Attacker calls `deploy()` to create pools with arbitrary parameters at the deterministic pool addresses
6. Legitimate factory's `createPool()` always reverts (fails `onlyFactory` check)

## Proof of concept

`POC: pending`

**Needs:**
- Check deployment scripts: is deployer deployed and `setFactoryAddress()` called in one atomic transaction?
- Fork POC: simulate front-running by calling `setFactoryAddress()` between deployer and factory deployment, confirm pools cannot be deployed

## Recommendation

### Option A: Atomic deployment
Set the factory address in the constructor:

```diff
- contract AgniPoolDeployer is IAgniPoolDeployer {
+ contract AgniPoolDeployer is IAgniPoolDeployer {
+     constructor(address _factoryAddress) {
+         require(_factoryAddress != address(0));
+         factoryAddress = _factoryAddress;
+     }
```

This eliminates the front-running window entirely. The `setFactoryAddress` function can be removed.

### Option B: Access control
Add `onlyOwner` to `setFactoryAddress()` and deploy the deployer with the deployer's deployer address (typically a multisig) set as owner in the constructor. Then call `setFactoryAddress()` in the same atomic transaction as both deployments.

### Option C: Two-phase initialization
Use a `create2`-based deployer where the factory address is part of the salt, making the deployer bound to a specific factory from inception.

## References

- **trailofbits** — "PoolDeployer setFactoryAddress() has no access control — front-runnable initialization" (high)
- **trailofbits** — "PoolDeployer factory address is set once but cannot be updated — irreversible" (low)
- **forefy FORE-005** — "PoolDeployer.setFactoryAddress lacks access control, can be frontrun at deploy time" (M)
- **solodit solodit-004** — "setFactoryAddress in AgniPoolDeployer lacks access control, enabling frontrunning of deployer initialization" (H)
