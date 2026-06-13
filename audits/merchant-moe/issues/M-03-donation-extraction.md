# Medium Findings - Merchant Moe Liquidity Book

## MEDIUM [M-03]: Direct Token Transfers to LB Pairs Extractable by Next Minter

**Severity:** MEDIUM (4.5/10)
**Impact:** Accidental or malicious direct transfers to LB pairs can be claimed by next minter
**Status:** Confirmed (code analysis)

### Root Cause

`LBPair.sol:671` — The `mint()` function computes `amountsReceived` as the difference between the pair's current token balance and the stored `_reserves`:

```solidity
amountsReceived = reserves.received(_tokenX(), _tokenY());
```

The `received` function (`PackedUint128Math.sol:303-318`) simply computes `balanceOf(token) - reserve`. Any tokens sent directly to the pair contract are included in `amountsReceived` and distributed across bins. Tokens that cannot be deposited into bins (due to ratio constraints) are refunded as `amountsLeft` to `refundTo` (line 684):

```solidity
if (amountsLeft > 0) amountsLeft.transfer(_tokenX(), _tokenY(), refundTo);
```

### Flow

1. User sends N tokens directly to pair contract (donation or mistake)
2. Anyone calls `mint()` with minimal deposit to same pair
3. `amountsReceived` includes the N tokens
4. Excess beyond the depositor's fair share is returned as `amountsLeft` to the depositor (or their nominated `refundTo` address)
5. Depositor effectively claims the donation

### Missing `skim()` Function

Uniswap V2 provides a `skim(address to)` function that sends `balanceOf - reserve` to any address, letting LPs recover accidental transfers. The LB pair has no equivalent.

### Affected Code

- `LBPair.sol:671` — `reserves.received(...)` uses balance snapshot
- `LBPair.sol:675` — `amountsLeft = _mintBins(...)` with remaining amounts
- `LBPair.sol:684` — `amountsLeft.transfer(...)` refunds excess to minter

### Recommendations

1. Add a `skim(address to)` function analogous to Uniswap V2 that sends excess `balanceOf - reserve` to any address
2. Alternatively, require that anyone calling mint must send a minimum proportional deposit relative to the donation amount
