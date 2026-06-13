# M-01: onlyFactoryOrFactoryOwner Modifier Grants Both Factory and Owner Admin Access to Pools

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-12 (Protocol fee is withdrawn only by factory owner — the modifier allows both factory AND owner, widening the attack surface)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniPool (`setFeeProtocol`, `collectProtocol`, `setLmPool`)
- **Deployed address:** N/A (implementation contract)
- **Source:** verified
- **Location:** source/core/AgniPool.sol:L107-L110

## Description

The `onlyFactoryOrFactoryOwner` modifier in `AgniPool` allows both the factory contract address AND the factory owner EOA to call sensitive pool admin functions. This is a deviation from standard Uniswap V3 where only the factory owner (not the factory contract) has these powers.

```solidity
modifier onlyFactoryOrFactoryOwner() {
    require(msg.sender == factory || msg.sender == IAgniFactory(factory).owner());
    _;
}
```

This modifier protects three functions:
- `setFeeProtocol()` (line 853) — sets protocol fee up to 40%
- `collectProtocol()` (line 869) — withdraws accumulated protocol fees
- `setLmPool()` (line 887) — sets the LM pool address called during swaps

The dual authority means that if **either** the factory contract OR the factory owner key is compromised, all three admin functions are at risk. Additionally, `AgniFactory` itself has `setFeeProtocol(pool, fee0, fee1)` (line 131) which forwards to the pool with `msg.sender == address(factory)` — passing the modifier check.

## Root cause

The modifier conflates two distinct trust domains: the factory contract (a programmable address whose code could change via upgrade) and the factory owner (a human-controlled account or multisig).

```solidity
modifier onlyFactoryOrFactoryOwner() {
    require(msg.sender == factory || msg.sender == IAgniFactory(factory).owner());
    _;
}
```

Standard UniV3 uses `onlyOwner` on the factory, and the pool checks only the factory address. The factory then forwards calls from the owner to the pool. This creates a single trust path: owner → factory → pool.

Agni's approach creates two independent trust paths: owner → pool (direct) and factory → pool (direct). Any function on the factory that isn't `onlyOwner`-guarded but calls pool admin functions would bypass the owner check.

## Impact

- **Wider attack surface**: If the factory contract is ever compromised (via delegatecall, upgrade, or a bug in a new function), pool admin functions are exposed without the owner's involvement
- **Future upgrade risk**: While the current factory code is clean (all factory-to-pool admin paths are `onlyOwner`-guarded), the modifier invites future code changes that could expose these paths
- **Defense-in-depth degradation**: The modifier weakens isolation between the factory and pool security domains

## Attack path / preconditions

1. Factory contract is upgraded or a new non-`onlyOwner` function is added that calls `pool.setFeeProtocol()` or `pool.collectProtocol()`
2. An attacker exploits this new function to call pool admin functions
3. Since `msg.sender == factory`, the `onlyFactoryOrFactoryOwner` check passes
4. Attacker manipulates protocol fees or withdraws protocol fees

Alternatively, a delegatecall-based attack on the factory contract could exploit the same path.

## Proof of concept

`POC: pending` — Factory upgrade or delegatecall to factory leads to pool admin exposure. Verify no current non-`onlyOwner` factory function calls pool admin methods.

**Needs:**
- Review factory upgrade path; check if factory is upgradeable
- Confirm all factory-to-pool calls are guarded by `onlyOwner`

## Recommendation

Restrict pool admin access to the factory owner only, not the factory contract itself. Use the standard UniV3 pattern where the factory forwards calls from the owner:

```diff
modifier onlyFactoryOrFactoryOwner() {
-    require(msg.sender == factory || msg.sender == IAgniFactory(factory).owner());
+    require(msg.sender == IAgniFactory(factory).owner());
    _;
}
```

Or, alternatively, keep the factory path but enforce on the factory side that only `onlyOwner`-guarded functions can call pool admin methods — with documentation that this invariant must be maintained through all future upgrades.

## References

- **trailofbits** — "onlyFactoryOrFactoryOwner modifier allows both factory AND owner — widening access" (medium)
- **forefy FORE-006** — "onlyFactoryOrFactoryOwner modifier allows factory contract itself to call sensitive pool functions" (L)
- **solodit solodit-003** — "OnlyFactoryOrFactoryOwner modifier conflates factory and owner, granting both admin-level pool access" (M)
- **invariant INV-12 lead** — "onlyFactoryOrFactoryOwner allows both factory contract and EOA owner to collect protocol fees" (low)
- Solodit reference: https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/253 (similar access control considerations in UniV3 fee management)
