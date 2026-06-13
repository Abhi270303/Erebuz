# I-02: SwapRouter Callback Validation Uses CREATE2 Address Without Factory Cross-Verification

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** none — defense-in-depth suggestion
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** CallbackValidation (`verifyCallback`)
- **Deployed address:** N/A
- **Source:** verified
- **Location:** source/libraries/CallbackValidation.sol:L28-L35

## Description

`CallbackValidation.verifyCallback()` computes the expected pool address using `PoolAddress.computeAddress()` and checks `msg.sender` against it, but does NOT additionally verify with the factory (`AgniFactory.getPool()`) that the pool was actually deployed by the canonical factory:

```solidity
function verifyCallback(address deployer, PoolAddress.PoolKey memory poolKey)
    internal view returns (IAgniPool pool)
{
    pool = IAgniPool(PoolAddress.computeAddress(deployer, poolKey));
    require(msg.sender == address(pool));
}
```

This means any contract deployed at the correct CREATE2 address (with matching parameters) would pass the verification, even if it was deployed by a different factory or has different runtime code.

While CREATE2 address collisions are computationally infeasible with different init code, this removes a safety layer that could have caught misconfiguration or edge-case deployment errors.

## Root cause

The callback verification relies solely on deterministic address computation without cross-referencing the canonical registry (`AgniFactory.getPool`).

## Impact

- **Theoretical only**: An attacker would need to find a CREATE2 address collision — requiring ~2^160 attempts — which is computationally infeasible
- **Defense-in-depth**: Adding a factory check would be a cheap safety layer

## Attack path / preconditions

Theoretical only — no practical exploit path:
1. Attacker computes the CREATE2 address for a legitimate pool's parameters
2. Attacker deploys a contract with different bytecode at that exact CREATE2 address
3. This would require finding a bytecode whose init code hash produces the same target address — computationally infeasible

## Recommendation

Add a factory pool lookup as an additional safety layer:

```diff
function verifyCallback(address deployer, PoolAddress.PoolKey memory poolKey)
    internal view returns (IAgniPool pool)
{
    pool = IAgniPool(PoolAddress.computeAddress(deployer, poolKey));
    require(msg.sender == address(pool));
+   // Additionally verify the pool was deployed by the canonical factory
+   require(IAgniFactory(poolKey.factory).getPool(poolKey.token0, poolKey.token1, poolKey.fee) == address(pool));
}
```

## References

- **solodit solodit-008** — "SwapRouter callback validation uses PoolAddress.computeAddress without factory verification" (M)
- Solodit reference: https://github.com/code-423n4/2023-11-panoptic-findings/issues/178 (Address collision in callback validation)
- Solodit reference: https://github.com/sherlock-audit/2023-10-real-wagmi-judging/issues/158
