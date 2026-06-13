# H-01: flashLoan Missing nonReentrant Guard Enables Pool State Manipulation

| Field | Value |
|-------|-------|
| **Severity** | CRITICAL |
| **Status** | unconfirmed |
| **Invariant broken** | INV-11 (MISSING) |
| **Contract** | `LendingPool.sol` |
| **Function** | `flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)` |
| **Line range** | L486–L567 |
| **Source file** | `/protocol/lendingpool/LendingPool.sol` |

---

## Description

`LendingPool.flashLoan()` has **no reentrancy guard** (`whenNotPaused` only checks `_paused`, not reentrancy). The error constant `LP_REENTRANCY_NOT_ALLOWED` is defined at `Errors.sol` line 89 but is **never used** anywhere in the codebase — no modifier, no `require` statement references it.

The flashLoan flow violates the Checks-Effects-Interactions pattern:

1. **L509**: Underlying tokens are transferred to the receiver via `IAToken(...).transferUnderlyingTo(receiverAddress, amounts[i])`
2. **L512–L515**: The receiver's `executeOperation()` callback is called — this is an **arbitrary external call** controlled by the receiver contract
3. **L517–L566**: After the callback returns, the pool reclaims the flash-loaned amounts plus premiums via `safeTransferFrom`

During the callback (step 2), the receiver controls the flash-borrowed assets and can re-enter **any** `LendingPool` function — `deposit()`, `borrow()`, `withdraw()`, `repay()`, or `liquidationCall()` — with the pool's reserve state in a transient, inconsistent condition. None of these functions have `nonReentrant` guards either.

This is a known vulnerability class in Aave V2 forks. The original Aave V2 documentation notes this as an intentional trade-off for composability, but given the additional attack surface introduced by Lendle's `updateAssetPrice()` state-mutating oracle path and the `ChefIncentivesController` external call bridge, the risk is materially higher than in vanilla Aave V2.

## Impact

An attacker can:
1. Call `flashLoan()` with a malicious `IFlashLoanReceiver` contract
2. During `executeOperation()`, re-enter `deposit()` to deposit the flash-borrowed assets as collateral, minting aTokens at the current liquidity index
3. Re-enter `borrow()` to borrow other assets against the newly inflated collateral position
4. Since `_executeBorrow()` calls `updateAssetPrice()` (a state-mutating oracle write), the attacker can also influence the oracle price used for the health factor check
5. After the callback, the pool attempts to reclaim the flash-loaned principal — if the attacker has extracted value via borrowing, the remaining balance may not cover the flash loan, leaving bad debt

The `LP_REENTRANCY_NOT_ALLOWED` error code being defined but unused is strong evidence the developers intended to add this protection but never wired it.

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | lead 1 | CRITICAL |
| **trailofbits** | lead 1 | CRITICAL |
| **forefy** | forefy-001 | CRITICAL |
| **solodit** | SOLODIT-001 | HIGH |
| **invariant** | lead 1 | HIGH |

All 5 hunters independently flagged this issue from different analytical perspectives.

## Historical Precedent

- **Agave / Hundred Finance (March 2022, $11.7M combined)**: Exploited reentrancy in Aave V2 forks on Gnosis Chain via ERC677 `onTokenTransfer()` callback, enabling multiple borrows against the same collateral.
- **Consensys Diligence Aave V2 audit**: Noted the absence of a reentrancy guard on flashLoan was an intentional design choice, but Lendle's modifications (state-mutating oracle, external incentives bridge) change the risk calculus.

## PoC Sketch

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

interface ILendingPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function withdraw(address asset, uint256 amount, address to) external;
}

contract FlashLoanReentrancyExploit {
    ILendingPool public pool;
    address public asset;
    address public collateralAsset;
    bool public entered;
    
    function executeOperation(
        address[] calldata, uint256[] calldata, uint256[] calldata premiums,
        address initiator, bytes calldata
    ) external returns (bool) {
        if (!entered) {
            entered = true;
            // Re-enter: deposit flash-borrowed funds as collateral
            pool.deposit(collateralAsset, IERC20(collateralAsset).balanceOf(address(this)), address(this), 0);
            // Re-enter: borrow against inflated collateral
            pool.borrow(asset, maxBorrowable(), 2, 0, address(this));
        }
        return true;
    }
}
```

## Recommendation

1. Add OpenZeppelin's `ReentrancyGuard` (or equivalent) and apply `nonReentrant` to:
   - `flashLoan()`
   - `deposit()`
   - `borrow()`
   - `withdraw()`
   - `repay()`
   - `liquidationCall()`
2. Alternatively, wire the already-defined `LP_REENTRANCY_NOT_ALLOWED` error into a custom `nonReentrant` modifier

## POC Needs (Phase 9)

- Mantle mainnet fork RPC URL
- Deployed LendingPool proxy address
- One asset with available flash loan liquidity
- Malicious receiver contract implementing the reentrancy logic above
