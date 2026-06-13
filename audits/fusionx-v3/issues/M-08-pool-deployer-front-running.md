# [M] FusionXV3PoolDeployer.setFactoryAddress Has Zero Access Control — Deployment Front-Running Risk

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** None (deployment-time risk)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3PoolDeployer` (`setFactoryAddress`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3PoolDeployer.sol:L34-L40`

## Description

`setFactoryAddress()` requires `factoryAddress == address(0)` (one-time initialization) but has **no caller authentication**. Anyone can front-run the legitimate deployer's transaction to set a malicious factory address during the initial deployment phase. After initialization, only the set factory can call `deploy()`.

## Root cause

```solidity
function setFactoryAddress(address _factoryAddress) external {
    require(factoryAddress == address(0), "already initialized");
    factoryAddress = _factoryAddress;
}
```

No `onlyOwner`, no `msg.sender` check — just an uninitialized guard. A front-runner can call this first.

## Impact

- **Full control of pool deployment:** If front-ran, the attacker's factory creates pools at attacker-controlled addresses
- **Time-limited:** Only exploitable during the window between deployer contract creation and the legitimate `setFactoryAddress` transaction
- **On Mantle:** If the deployer contract is already initialized (check Mantle mainnet state), this finding is historical only

## Attack path / preconditions

1. Deployer contract is deployed to Mantle with `factoryAddress == address(0)`
2. Attacker monitors the mempool for the legitimate `setFactoryAddress` transaction
3. Attacker submits a front-running transaction with higher gas price
4. Attacker sets a malicious factory address
5. All subsequent pool deployments use the malicious factory

## Proof of concept

`POC: pending` — simple unit test:
1. Deploy FusionXV3PoolDeployer
2. Call setFactoryAddress from any EOA
3. Verify it succeeds

## Recommendation

Add caller authentication or make the factory address immutable in the constructor:

```diff
- function setFactoryAddress(address _factoryAddress) external {
-     require(factoryAddress == address(0), "already initialized");
-     factoryAddress = _factoryAddress;
- }
+ constructor(address _factoryAddress) {
+     factoryAddress = _factoryAddress;
+ }
```

If post-deployment initialization is required, use a privileged role:

```diff
function setFactoryAddress(address _factoryAddress) external {
+   require(msg.sender == deployer, "not deployer");
    require(factoryAddress == address(0), "already initialized");
    factoryAddress = _factoryAddress;
}
```

## References

- **Pashov lens:** Lead #10 (INFO) — setFactoryAddress no access control
- **Trail of Bits lens:** Lead #9 (MEDIUM) — setFactoryAddress has no access control
- **x-ray report:** Issue #1 — "PoolDeployer front-running" (noted as HIGH deployment-time)
