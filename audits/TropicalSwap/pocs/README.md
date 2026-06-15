# TropicalSwap Proof-of-Concept Tests

## Setup
```bash
forge install foundry-rs/forge-std
```

## Run
```bash
# Set Mantle RPC
export MANTLE_RPC_URL=https://rpc.mantle.xyz

# Run the residual extraction POC
forge test --fork-url $MANTLE_RPC_URL --match-test testZapResidualDrain -vvv

# Run the sandwich POC
forge test --fork-url $MANTLE_RPC_URL --match-test testZapSandwichExtraction -vvv
```

## POC Files
- `H02-M01-ResidualDrain.sol` — Proves M-01 + H-02 chain: residual token extraction from ZapV1
- `H01-FlashSwapReentrancy.sol` — Proves H-01: flash swap callback cross-contract reentrancy
