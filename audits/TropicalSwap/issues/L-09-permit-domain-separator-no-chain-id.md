# L-09 Permit DOMAIN_SEPARATOR lacks chain ID — cross-chain replay on fork

- **Severity:** Low
- **Status:** unconfirmed
- **Invariant broken:** none (spec quality)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** `TropicalERC20` (inherited by TropicalPair LP tokens)
- **Deployed address:** TBD
- **Source:** source code (verified)
- **Location:** `TropicalERC20.sol` (DOMAIN_SEPARATOR computation)

## Description

The `DOMAIN_SEPARATOR` for EIP-712 permit signatures is computed once at construction time and does not dynamically incorporate the current `block.chainid`. If Mantle chain forks or the same bytecode is deployed on another chain (testnet, alternate network), a permit signature signed for one chain can be replayed on the other chain.

## Root cause

The DOMAIN_SEPARATOR is computed in the constructor and cached:
```solidity
DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes(name)),
    keccak256(bytes("1")),
    chainId,  // Fixed at deployment time — does not update on fork
    address(this)
));
```

## Impact

- Low — only relevant if Mantle chain forks or LP token contract is reused on another chain
- Standard known limitation for many Uniswap V2 forks

## Proof of concept

Not required — documented limitation.

## Recommendation

Use the OpenZeppelin `EIP712` implementation which dynamically reads `block.chainid`:

```solidity
function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return keccak256(abi.encode(
        EIP712_DOMAIN_TYPEHASH,
        keccak256(bytes(name)),
        keccak256(bytes("1")),
        block.chainid,  // Dynamic, not cached
        address(this)
    ));
}
```

## References

- solodit (SOL-008) — Permit DOMAIN_SEPARATOR lacks chain ID replay protection (M — re-assessed to L)
- Solodit ref: Hacken.io — https://hacken.io/discover/uniswap-v2-core-contracts-security (Lack of Replay Protection Across Chain Forks)
