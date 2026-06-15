# M-03 Init code hash hardcoded in TropicalLibrary not verified against Factory — pair address computation can break

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** I-22 — Init code hash consistency between Factory and Library
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalFactory` / `TropicalLibrary`
- **Deployed address:** TBD
- **Source:** source code (verified)
- **Location:** `TropicalFactory.sol:L8`, `TropicalLibrary.sol:L19-L27`

## Description

The Factory contract derives `INIT_CODE_PAIR_HASH` at compile time from `type(TropicalPair).creationCode`. The Library contract hardcodes a literal hash `0x321aea434584ceee22f77514cbdc4c631d3feba4b643c492f852c922a409ed1e` in `pairFor()`. There is **no on-chain assertion, test, or runtime check** that these two values are equal.

If `TropicalPair` is ever recompiled with:
- A different Solidity compiler version (core contracts use 0.5.16, but upgrades may use newer)
- Different optimizer runs settings
- Different metadata flags
- Any code modification to Pair.sol

Then the Factory's hash will update (because it's derived at compile time from the actual bytecode), but the Library's hardcoded hash will stay fixed. The Router's `pairFor()` will compute **wrong pair addresses**, causing all Router operations to interact with non-existent pair contracts.

## Root cause

`TropicalFactory.sol` (at compile time):
```solidity
bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(TropicalPair).creationCode));
```

`TropicalLibrary.sol` (hardcoded):
```solidity
bytes constant private HEX_PAIR_HASH = hex'321aea434584ceee22f77514cbdc4c631d3feba4b643c492f852c922a409ed1e';
// Used in: pair = address(uint(keccak256(abi.encodePacked(hex'ff', factory, keccak256(abi.encodePacked(token0, token1)), HEX_PAIR_HASH))));
```

No assertion like:
```solidity
require(Factory.INIT_CODE_PAIR_HASH == keccak256(abi.encodePacked(type(TropicalPair).creationCode)), "hash mismatch");
```

## Impact

If the hash diverges:
- Router's `pairFor()` computes addresses that don't match Factory's actual pair addresses
- `addLiquidity()`, `removeLiquidity()`, and `swap()` operations that use `pairFor()` to locate pair contracts will interact with the **wrong addresses** or non-existent contracts
- **All funds sent via Router to a mismatched pair address are permanently lost** (sent to a contract with no `transfer()` handling, or to an EOA)
- Full protocol DoS for Router operations

## Attack path / preconditions

1. TropicalPair.sol is redeployed with any compiler change (solc version upgrade, optimizer tweak, metadata change)
2. Factory is redeployed or recompiled — its `INIT_CODE_PAIR_HASH` reflects the new bytecode
3. Library-linked contracts (Router) are NOT recompiled — their `pairFor()` still uses the old hardcoded hash
4. Any Router function that calls `pairFor()` to find a pair address gets the wrong address
5. Tokens sent to the wrong address are permanently lost

## Proof of concept

```
POC: pending — Compilation and verification
```

**Test plan:**
1. Compile TropicalPair with current solc (0.5.16) and optimizer settings
2. Compute expected hash from bytecode
3. Compare to hardcoded `0x321aea...ed1e`
4. Recompile with a different solc version (e.g., 0.5.17) or optimizer runs
5. Observe that the hardcoded hash no longer matches
6. Deploy Factory with new bytecode, observe Router computes wrong pair addresses

## Recommendation

Add a runtime assertion at least in a test, and ideally as a constructor check:

```solidity
// In TropicalFactory constructor or a setup function:
import {TropicalLibrary} from "./libraries/TropicalLibrary.sol";
// This is not directly possible because Libraries are not deployable contracts.
// Instead, add a view function:
function assertInitCodeHash() external view returns (bool) {
    bytes32 computed = keccak256(abi.encodePacked(type(TropicalPair).creationCode));
    return computed == INIT_CODE_PAIR_HASH;
}
```

Or better, eliminate the hardcoded hash entirely by having `pairFor()` read the hash from the Factory:

```diff
  function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
      pair = address(uint(keccak256(abi.encodePacked(
              hex'ff',
              factory,
              keccak256(abi.encodePacked(tokenA, tokenB)),
-             hex'321aea434584ceee22f77514cbdc4c631d3feba4b643c492f852c922a409ed1e' // Init code hash
+             IFactory(factory).INIT_CODE_PAIR_HASH()
      ))));
  }
```

This requires a cross-contract call (breaking the `pure` function) but eliminates the mismatch risk. Alternatively, use CREATE2 during deployment to verify the hash.

## References

- forefy (forefy-006) — Init code hash hardcoded — silent divergence on compiler change (L)
- invariant (INV-007) — Init code hash hardcoded, no on-chain assertion (H — re-assessed to M)
- pashov (pashov-007) — Init code hash not asserted on-chain (H — re-assessed to M)
- solodit (SOL-002) — Init code hash mismatch between Factory and Library (H — re-assessed to M)
- trailofbits (TB-04) — Init code hash hardcoded not verified (M)
- Common Uniswap V2 fork finding — multiple Solodit audit reports flag init code hash consistency as a deployment safety issue
