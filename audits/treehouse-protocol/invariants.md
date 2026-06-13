# Treehouse Protocol Invariants

## Core Financial Invariants

### INV-1: 1 IAU = 1 wstETH NAV unit
IAU.totalSupply() should always equal the total protocol NAV measured in wstETH.
The protocol NAV = Vault wstETH balance + Strategy positions (in wstETH terms).
TreehouseAccounting.mark() adjusts IAU supply to match NAV changes.

### INV-2: Deposit preserves backing ratio
Router.deposit(): user sends wstETH to Vault, IAU is minted 1:1, TAsset deposits IAU.
Vault wstETH increases by `_amount`, IAU.totalSupply() increases by `_amount` + yield.
TAsset totalAssets() = IAU.balanceOf(TAsset) increases proportionally.

### INV-3: Redemption cannot extract more than deposited
finalizeRedeem(): _getReturnAmount must return ≤ IAU received from TAsset.redeem().
The formula: `_minC * min(_b0, _bn) / _maxC` should always cap return at fair value.
Over-redemption would drain the Vault below its backing.

### INV-4: NAV calculation is manipulation-resistant
NavErc20.nav() uses _target.balance + token.balanceOf.
No external actor should be able to inflate NAV without depositing real value.
PnlAccounting.deviation (2.5% per window) limits impact of any single manipulation.

### INV-5: Only executor can execute strategies
Strategy.callExecute() requires strategyStorage.strategyExecutor().
Vault.withdraw() requires active strategy + whitelisted asset.
No path to move Vault assets without executor approval.

### INV-6: IAU supply integrity
Only minters (set by owner) can mint/burn IAU.
TreehouseAccounting.mark() is the canonical mint/burn path (onlyOwnerOrExecutor).
No mint without corresponding NAV increase.

### INV-7: 7-day waiting period is inviolable
finalizeRedeem: block.timestamp >= _redeem.startTime + waitingPeriod.
waitingPeriod change applies prospectively only.

### INV-8: Rescuable cannot bypass VaultRescuer timelock
Vault.rescueERC20() is onlyRescuer; rescuer set by onlyOwner.
VaultRescuer enforces 5-day WAIT_TIME between rescue and withdrawal.
No path to instant-drain Vault via rescue functions.

## Violated Invariants

### INV-4 VIOLATED: NavErc20.nav() reads _target.balance
ETH can be force-sent to Vault via selfdestruct, inflating vaultNav().
Deviation check (2.5%/window) mitigates but doesn't eliminate the risk.
Repeated forced-ETH + doAccounting() can drain the Vault over time.

### INV-8 VIOLATED: Owner bypasses VaultRescuer timelock
Vault.updateRescuer() is onlyOwner → can set rescuer to any address.
Owner: updateRescuer(self) → rescueERC20(wstETH, attacker, max) → instant drain.
VaultRescuer 5-day timelock is architecturally irrelevant.
