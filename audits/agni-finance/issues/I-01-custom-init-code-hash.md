# I-01: Custom POOL_INIT_CODE_HASH and Architecture Change — Integration Compatibility Risk

- **Severity:** Informational
- **Status:** unconfirmed
- **Invariant broken:** INV-07 (Pool address is deterministic and verifiable — the custom hash is correct for this architecture, but differs from standard UniV3)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** PoolAddress (`computeAddress`), AgniPoolDeployer (`deploy`)
- **Deployed address:** N/A
- **Source:** verified
- **Location:** source/libraries/PoolAddress.sol:L6, L33-L47; source/core/AgniPoolDeployer.sol:L52

## Description

Agni Finance uses a custom `POOL_INIT_CODE_HASH` and a separate `AgniPoolDeployer` contract for CREATE2 pool deployment, differing from the standard Uniswap V3 architecture:

**Standard UniV3:**
- Factory self-deploys pools: `new Pool{key}` → `address(this)` is the factory
- PoolAddress.computeAddress takes `factory` as first parameter
- `POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`

**Agni Finance:**
- Separate `AgniPoolDeployer` deploys pools: `new AgniPool{salt: ...}()` 
- PoolAddress.computeAddress takes `deployer` as first parameter, not `factory`
- `POOL_INIT_CODE_HASH = 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a`

The x-ray.md threat model initially claimed "CREATE-based deployment" but the code actually uses `new AgniPool{salt: ...}` which is Solidity's CREATE2 syntax (available since Solidity 0.6.2), so addresses ARE deterministic.

## Root cause

Agni has made architectural changes to the deployment process:
1. Pool deployment is done by a separate `AgniPoolDeployer` contract (not the factory)
2. The init code hash differs because `AgniPool` bytecode has custom modifications (LM pool integration, no `NoDelegateCall`, etc.)

These are intentional design differences, not bugs. The `PoolAddress.computeAddress` function correctly uses the deployer address and the custom hash. The concern is purely about integration compatibility.

## Impact

- **Integration risk**: Any external contract or off-chain system that computes pool addresses using the standard UniV3 formula will get wrong addresses
- **SDK compatibility**: Front-ends, subgraphs, and SDKs that hardcode the UniV3 init code hash or factory pattern will fail to compute correct pool addresses
- **No direct security vulnerability** — the custom hash is correct for Agni's architecture

## Attack path / preconditions

1. An integrator copies standard UniV3 `PoolAddress.computeAddress` which uses the UniV3 factory address and init code hash
2. All computed pool addresses are incorrect
3. Transactions interacting via the wrong address revert or interact with incorrect contracts

## Recommendation

1. Document the custom `POOL_INIT_CODE_HASH` prominently in all integration documentation
2. Provide an SDK or library with the correct `computeAddress` function
3. Ensure all periphery contracts (SwapRouter, Quoter, NonfungiblePositionManager) use the correct `PoolAddress` library
4. Verify on-chain that the bytecode hash deployed matches `0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a`

## References

- **trailofbits** — "Non-standard pool address derivation — PoolAddress.computeAddress uses CREATE2 formula but actual deployment also uses CREATE2" (medium)
- **solodit solodit-007** — "Custom POOL_INIT_CODE_HASH and architecture change require all periphery PoolAddress.computeAddress to use deployer not factory" (L)
- Solodit reference: https://github.com/Uniswap/v3-periphery/issues/348 (Hardcoded POOL_INIT_CODE_HASH unexpected value issue)
- Solodit reference: https://ethereum.stackexchange.com/questions/153231 (Create2 address mismatch in forks)
