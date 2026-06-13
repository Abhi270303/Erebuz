# INIT Capital

- Setup

```shell
forge install
```


# Assumptions of using Multicall

The following actions need to construct the payload and create an atomic transaction via Multicall on InitCore to prevent frontrunning.

### Mint pool

1. Transfer the underlying token to LendingPool.
2. Call mintTo() in InitCore to mint LendingPool token to the receiver

### Burn pool

1. Transfer the LendingPool token to LendingPool.
2. Call burnTo() in InitCore to burn LendingPool token and send underlying token to the receiver

### Collateralize position

1. Transfer the underlying token to LendingPool.
2. Call mintTo() in InitCore to mint LendingPool token to the PositionManager
3. Call Collateralize() to create collateralized position.
