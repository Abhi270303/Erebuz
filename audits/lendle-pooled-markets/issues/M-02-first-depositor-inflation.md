# M-02: Empty Pool / First-Depositor Inflation Attack on Newly Activated Reserves

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Status** | unconfirmed |
| **Invariant broken** | INV-03 (assumed) |
| **Contracts** | `AToken.sol` |
| **Functions** | `AToken.mint()`, `AToken.burn()` |
| **Source file** | `/protocol/tokenization/AToken.sol` |

---

## Description

`AToken.mint()` and `burn()` use `rayDiv` for converting between amounts and scaled balances:

```solidity
// AToken.mint() — simplified
amountScaled = amount.rayDiv(liquidityIndex);  // L143
_scaledBalance[user] = _scaledBalance[user].add(amountScaled);  // L145
// ...
mint(amountScaled);  // increase scaledTotalSupply
```

The `liquidityIndex` starts at `1e27` (WadRayMath.ray()). On an empty reserve, the first depositor can manipulate `liquidityIndex` by:
1. Making a tiny deposit (e.g., 1 wei)
2. Donating underlying tokens directly to the aToken contract (inflating `aToken.totalSupply()` without minting scaled tokens)
3. Subsequent `liquidityIndex` accruals via `cumulateToLiquidityIndex()` cause the manipulated index to affect all new depositors' scaled balances

While Aave V2's core code has some protections (minimum deposit must be large enough), this attack class has been successfully exploited in multiple Aave V2 forks.

### Why MEDIUM for Lendle

- Lendle is **already deployed** with ~$300K TVL and active reserves
- Existing reserves have sufficient deposits to prevent this
- **However**: if the PoolAdmin activates any **new reserve** without seeding it with a minimum deposit in the same transaction, the new reserve is vulnerable
- The Radiant ($4.5M, Jan 2024) and Sonne ($20M, May 2024) exploits targeted newly activated pools on existing deployments

## Impact

If a new reserve is activated without a minimum deposit:
- An attacker can front-run legitimate deposits
- The attacker can manipulate `liquidityIndex` to steal value from subsequent depositors
- After manipulation, the attacker can borrow against inflated collateral

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **solodit** | SOLODIT-007 | MEDIUM |

Only 1 hunter flagged this directly. However, the MixBytes "AAVE and Compound Forking: Empty Pool Attacks" article and multiple real-world exploits confirm this is a valid concern.

## Recommendation

1. **Seed new reserves**: When activating a new reserve via `LendingPoolConfigurator.initReserve()`, simultaneously deposit a minimum amount (e.g., $1000 worth of the underlying asset) in the same transaction to establish a non-manipulable `liquidityIndex`
2. **Virtual shares**: Implement the "virtual shares" pattern used by newer Aave versions that prevents index manipulation by tracking a separate `liquidityIndex` accumulator that can't be inflated by direct token transfers
3. **Document the requirement**: If no code change is made, document that PoolAdmin must seed any new reserve with sufficient initial deposits

## Historical Precedent

- **Radiant Capital (Jan 2024, $4.5M)**: First-depositor inflation attack on a newly activated USDC pool on Arbitrum. Attacker manipulated `liquidityIndex` using flash loans.
- **Sonne Finance (May 2024, $20M)**: Same attack class on Compound V2 fork. Attacker exploited the empty pool to drain newly added assets.
- **MixBytes technical analysis**: "AAVE and Compound Forking: Empty Pool Attacks" provides a detailed breakdown of the attack mechanics.
