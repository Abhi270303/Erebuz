# H-02: Forced-ETH NAV Inflation Enables Protocol Drain via Keeper-Triggered Excess IAU Minting

## Severity
**High** — Direct repeated value extraction up to 2.5% of TVL per hour (60%+ per day).

## Files
- `modules/nav/NavErc20.sol:36-50` — `nav()` reads `_target.balance`
- `periphery/PnlAccounting.sol:17` — `PRECISION = 1e4` gives 2.5%/window not 0.025%
- `TreehouseAccounting.sol:33-48` — `mark()` has NO deviation check, only `onlyOwnerOrExecutor`
- `Vault.sol:42-57` — Vault has no `receive()`, but ETH can be force-sent via `selfdestruct`

## Description

### The NAV Donation Attack Surface

The `NavErc20.nav()` function computes the Vault's NAV as:

```solidity
function nav(address _target, address[] memory _tokens) external view returns (uint _nav) {
    _nav += _target.balance;  // <-- INCLUDES force-sent ETH via selfdestruct
    // ... token balances ...
    _nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;
}
```

The Vault contract does not have a `receive()` function, but ETH can be force-sent via `selfdestruct`. The `_target.balance` is used directly in the NAV calculation, converting it to stETH/wstETH terms.

### Deviation Guard is 100× Weaker Than Documented

```solidity
// PnlAccounting.sol
uint16 public deviation = 250; // Comment says "1e6 base. 250 == 0.025%"
uint constant PRECISION = 1e4;   // <-- CODE USES 1e4 NOT 1e6

function maxPnl() public view returns (uint) {
    return (deviation * NAV_LENS.lastRecordedProtocolNav()) / PRECISION;
    // = 250 * lastNav / 10000 = 2.5% per window, NOT 0.025%
}
```

The comment claims `250 == 0.025%` (based on 1e6) but the code divides by 1e4, giving **2.5% per window**. The Aave technical assessment relied on the comment's 0.025% figure, not the actual 2.5% in code.

### Two Exploit Paths

**Path A — Slow drain via automated keeper (realistic):**
1. Attacker creates a `DonationRouter` contract
2. Attacker funds it with ETH (up to 2.5% of TVL per window)
3. `DonationRouter.selfdestruct()` → ETH force-sent to Vault
4. Keeper bot calls `PnlAccounting.doAccounting()` (automated, e.g., Gelato/Chainlink Keepers)
5. `doAccounting()` sees `currentNav > lastNav` within deviation → calls `TreehouseAccounting.mark(MINT)`
6. Excess IAU minted to TAsset → inflates tETH exchange rate
7. Attacker redeems tETH via Fastlane → receives real wstETH from Vault
8. Repeat every cooldown (3600s) until Vault is drained

**Path B — Instant drain via compromised executor (privileged):**
1. Attacker force-sends ETH to Vault (any amount, even >2.5%)
2. Compromised executor calls `TreehouseAccounting.mark(MINT, huge, 0)` directly
3. TreehouseAccounting.mark() has NO deviation check — mints unlimited IAU
4. Attacker redeems tETH for all wstETH in Vault

### Impact Calculation
With $70M TVL and 2.5% per hour:
- Per window: $1.75M extractable
- Per day (24 windows): $42M (60% of TVL)
- After 40 hours: Full protocol drain

## Chain of Small Issues
This finding chains three small issues:
1. **Low:** `NavErc20.nav()` reads `_target.balance` (counts force-sent ETH)
2. **Low:** Deviation comment says 0.025% but code gives 2.5%
3. **Low:** `TreehouseAccounting.mark()` has no deviation check of its own
4. **Low:** Vault has no `receive()` but `selfdestruct` bypasses it
