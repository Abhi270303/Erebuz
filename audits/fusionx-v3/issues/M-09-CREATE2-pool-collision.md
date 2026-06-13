# [M] CREATE2 Pool Address Collision — Deterministic Salt Enables Address Prediction and Squatting

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-FAC-01 — getPool bidirectional mapping consistency (indirectly)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `FusionXV3PoolDeployer` (`deploy`)
- **Source:** verified (repo source)
- **Location:** `v3-core/contracts/FusionXV3PoolDeployer.sol:L49-L65`

## Description

The pool deployer uses CREATE2 with salt = `keccak256(abi.encode(token0, token1, fee))` which is entirely deterministic and publicly computable. An attacker can precompute any pool's address before it is created. While the classic CREATE2 squating attack (deploy malicious contract → selfdestruct → pool deploys at same address with old approvals) is blocked on Mantle due to EIP-6780 (selfdestruct disabled), the predictable address still enables:
1. Pre-deployment setup (approve tokens to the future pool address)
2. Callback validation bypass when combined with a deploy race
3. MEV strategies that rely on knowing pool addresses before the pool exists

## Root cause

```solidity
bytes32 salt = keccak256(abi.encode(token0, token1, fee));
pool = Create2.deploy(0, salt, abi.encodePacked(
    type(FusionXV3Pool).creationCode,
    abi.encode(factory, token0, token1, fee, tickSpacing)
));
```

The factory does NOT check if the address already has code before deploying. The salt includes only `token0`, `token1`, and `fee` — no `msg.sender`, no `block.timestamp`, no nonce.

## Impact

- **Callback spoofing (combined with L-02/solodit-002):** The callback validation in `V3SwapRouter` computes the expected pool address via init code hash but does NOT call `factory.getPool()`. If an attacker can deploy code at the predicted address before the legitimate pool, the router's callback validation would pass for the attacker's contract.
- **MEV / front-running:** Knowing pool addresses before `createPool()` is called enables MEV bots to prepare sandwich strategies around pool creation.
- **Time-bounded:** On Mantle, the absence of `selfdestruct` means the classic "deploy → selfdestruct → re-deploy" path is not available. However, EIP-6780 still allows selfdestruct in the same transaction as creation, so a sophisticated attacker might attempt deploy-and-destroy patterns.

## Attack path / preconditions

**Path 1 (callback spoofing):**
1. Attacker observes a pending `createPool(tokenA, tokenB, fee)` transaction
2. Attacker computes the future pool address (same formula: `keccak256(abi.encode(tokenA, tokenB, fee))`)
3. Attacker pre-deploys a malicious contract with `uniswapV3SwapCallback` logic at that exact address
4. If the attacker's contract can interact with V3SwapRouter before the pool creation clears, user approvals could be drained
5. *(Requires precise timing and block reordering — very difficult on a live network)*

**Path 2 (pre-approval trap):**
1. Attacker convinces users to approve token spending to a computed pool address
2. Pool deploys later, inheriting the approvals
3. Attacker drains user tokens through the pool

## Proof of concept

`POC: pending` — conceptual. Create2 address computation:
```solidity
address predictedPool = address(uint160(uint256(
    keccak256(abi.encodePacked(
        bytes1(0xff),
        deployer,
        keccak256(abi.encode(token0, token1, fee)),
        keccak256(bytes(type(FusionXV3Pool).creationCode))
    ))
)));
```

## Recommendation

Include a nonce or `msg.sender` in the CREATE2 salt to make pool addresses unpredictable:

```diff
- bytes32 salt = keccak256(abi.encode(token0, token1, fee));
+ bytes32 salt = keccak256(abi.encode(token0, token1, fee, msg.sender, poolCount));
```

Also add an existence check before deploying:
```diff
+ require(!_isContract(predicted), "already deployed");
```

## References

- **Solodit lens:** Lead SOL-001 (HIGH) — CREATE2 address collision (downgraded to M: no selfdestruct on Mantle)
- **Historical:** Katana V3 C4 #42 (identical salt formula); Panoptic C4 #178; Arcadia Sherlock #59; Caviar C4 #419
- **Invariant:** INV-FAC-01
