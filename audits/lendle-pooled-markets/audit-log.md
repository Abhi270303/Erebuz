# Audit log — lendle-pooled-markets (top-level auditor notebook)

## Coverage
- [x] LendingPool — All 5 hunters reviewed; CRITICAL findings (H-01, H-02)
- [x] ChefIncentivesController — All 5 hunters reviewed; CRITICAL bridge finding (H-02)
- [x] PythPriceFeed — All 5 hunters reviewed; HIGH oracle finding (H-03)
- [x] MultiFeeDistribution — All 5 hunters reviewed; HIGH arithmetic bug (H-04)
- [x] AaveOracle — All 5 hunters reviewed; HIGH price divergence (H-05)
- [x] LendingPoolCollateralManager — 4/5 hunters reviewed; MEDIUM delegatecall (M-01)
- [x] IncentivizedERC20 — 3/5 hunters reviewed; folded into H-02
- [x] AToken — 2/5 hunters reviewed; MEDIUM inflation (M-02)
- [ ] WETHGateway — 0/5 reviewed — **coverage gap** (4 entry points)
- [ ] MasterChef — 0/5 reviewed — **coverage gap**
- [ ] TokenVesting — 0/5 reviewed
- [ ] ProtocolOwnedDEXLiquidity — 0/5 reviewed
- [ ] ProtocolRevenueDistribution — 0/5 reviewed
- [ ] StakingConfigurator — 0/5 reviewed
- [ ] StableDebtToken — 0/5 reviewed (stable-rate borrow specific path)
- [ ] AaveProtocolDataProvider — 0/5 reviewed
- [ ] MerkleDistributor — 1/5 reviewed; code quality (L-03)

## Hunches (not yet findings)
1. **StableDebtToken rebalance path** — `rebalanceStableBorrowRate()` can be called by anyone to force rate adjustments. Could be used to grief stable-rate borrowers.
2. **Unbounded loops in MultiFeeDistribution** — `withdraw()` iterates over `userEarnings[]`. A user with many earnings entries (dust from many reward distributions) could be DoS'd (gas griefing).
3. **Fee-on-transfer tokens** — If any supported reserve is a fee-on-transfer token, the deposit/borrow accounting breaks (actual received ≠ transferred amount).
4. **No `getPriceNoOlderThan()` usage** — All Pyth queries use the unsafe path. Even with deviation checks, stale prices from Pyth's own feed could persist.

## Chaining ideas (Phase 8)

### Chain 1: FlashLoan Reentrancy + Oracle Manipulation (H-01 + H-03 + H-05)
**Severity**: CRITICAL (escalates H-01 and H-03 individually → full protocol drain)
**Hypothesis**: FlashLoan receiver re-enters LendingPool → calls borrow() → borrow path triggers updateAssetPrice() (writes lastGoodPrice to PythPriceFeed). Since MAX_PRICE_DEVIATION is never checked (H-03), attacker pushes an extreme price. Meanwhile, health factor validation uses getAssetPrice() which may differ (H-05), enabling undercollateralized borrowing.
**Test**: Fork PoC demonstrating flashLoan → re-enter borrow → oracle price manipulation → extracted value exceeds flash loan principal.
**Contracts**: LendingPool, PythPriceFeed, AaveOracle
**Invariants at risk**: INV-11, INV-07, INV-06, INV-01

### Chain 2: Token Transfer → Incentives Bridge → Oracle Contamination (H-02 + H-03 + H-05)
**Severity**: CRITICAL
**Hypothesis**: Any aToken transfer → IncentivizedERC20._transfer() → ChefIncentivesController.handleAction() → onwardIncentives.handleAction(). Malicious onwardIncentives re-enters LendingPool.borrow() → updateAssetPrice() writes contaminated oracle state. Meanwhile, AToken._transfer() calls pool.finalizeTransfer() AFTER the incentives callback, so the health factor check sees post-contamination state.
**Test**: Set onwardIncentives to malicious contract → trigger aToken transfer → re-enter borrow → observe oracle price contamination affecting finalizeTransfer() health check.
**Contracts**: AToken, IncentivizedERC20, ChefIncentivesController, LendingPool, PythPriceFeed
**Invariants at risk**: INV-12, INV-07, INV-06, INV-01

### Chain 3: Double-Subtraction → Inflated Rewards Extraction (H-04)
**Severity**: HIGH
**Hypothesis**: MultiFeeDistribution double-subtraction (H-04) overcharges penalty by 2x and sends excess to rewards. Attacker can: 1) stake LEND, 2) get reward distribution to generate bal.earned, 3) call withdraw() with locked earnings → penalty overcharged by 2x → inflated reward distribution, 4) second account claims inflated rewards via ChefIncentivesController.
**Test**: Multi-step PoC: stake → trigger reward → withdraw with penalty → verify penaltyAmount = remaining (should be remaining/2) → check totalSupply and reward pool inflation.
**Contracts**: MultiFeeDistribution, ChefIncentivesController
**Invariants at risk**: INV-13, INV-14, INV-04

### Chain 4: DELEGATECALL + AddressesProvider Governance Escalation (M-01)
**Severity**: CRITICAL (if owner key compromised)
**Hypothesis**: AddressesProvider owner sets malicious CollateralManager → any liquidationCall triggers delegatecall → malicious contract drains LendingPool storage.
**Test**: Manual key-rotation analysis of AddressesProvider.
**Contracts**: LendingPool, LendingPoolCollateralManager, LendingPoolAddressesProvider
**Invariants at risk**: INV-08

## Questions for the protocol team
1. Is the AddressesProvider owner a multisig? What is the quorum?
2. Is there a timelock on the LendingPoolCollateralManager address change?
3. Is `onwardIncentives` set to `address(0)` on the deployed ChefIncentivesController?
4. Has the PoolAdmin activated any new reserves recently (post-initial deployment)? If so, was the reserve seeded with a minimum deposit?
5. Are there any non-standard ERC20 tokens (fee-on-transfer, ERC777, ERC677) among the supported reserves?
6. Was the `LP_REENTRANCY_NOT_ALLOWED` error intentionally never wired (Aave V2 design choice) or was it an oversight?
