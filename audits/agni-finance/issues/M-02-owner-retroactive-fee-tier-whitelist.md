# M-02: Owner Can Retroactively Disable Fee Tiers or Enable Whitelist After Pools Exist

- **Severity:** Medium
- **Status:** unconfirmed
- **Invariant broken:** INV-09 (Fee tiers cannot be disabled after being enabled — MISSING); INV-10 (Only whitelisted users create pools in whitelisted fee tiers — MISSING)
- **Chain / network:** Mantle (chainId 5000)
- **Contract:** AgniFactory (`setFeeAmountExtraInfo`, `createPool`)
- **Deployed address:** N/A
- **Source:** verified
- **Location:** source/core/AgniFactory.sol:L112-L124; IAgniFactory.sol:L50

## Description

`AgniFactory.setFeeAmountExtraInfo()` allows the owner to modify two critical parameters on any fee tier at any time, even after pools have already been created on that tier:

1. **`enabled`**: The owner can set `enabled = false` on any fee tier, permanently blocking new pool creation on that tier. Existing pools continue operating but cannot be joined by new LPs.

2. **`whitelistRequested`**: The owner can set `whitelistRequested = true` retroactively, meaning pools that were previously freely creatable now require whitelist approval — but only for future creation. Pools created before the whitelist was enabled remain freely accessible.

The `IAgniFactory.sol` interface comment at line 50 states: *"A fee amount can never be removed"* — but the implementation allows effective removal via `enabled = false`.

## Root cause

The `setFeeAmountExtraInfo()` function (line 112-124) has no constraint preventing modification of fee tier parameters after pools have been created:

```solidity
function setFeeAmountExtraInfo(uint24 fee, bool whitelistRequested, bool enabled)
    public override onlyOwner
{
    require(feeAmountTickSpacing[fee] != 0);
    feeAmountTickSpacingExtraInfo[fee] = TickSpacingExtraInfo({
        whitelistRequested: whitelistRequested,
        enabled: enabled
    });
}
```

The `createPool()` function (line 70) enforces these params:
```solidity
require(tickSpacing != 0 && info.enabled, "fee is not available yet");
if (info.whitelistRequested) {
    require(_whiteListAddresses[msg.sender], "pool whitelist requested");
}
```

No timelock, multisig requirement, or user notification mechanism exists for these changes. No check prevents disabling a tier that already has pools.

## Impact

### Fee tier disablement
- New LPs cannot create pools on the disabled tier
- Existing pools become "zombie pools" — alive but unreproducible
- Integrators relying on `feeAmountTickSpacing` to discover available tiers may break
- Competitors cannot deploy competing pools for the disabled tier

### Retroactive whitelist
- Can be used to freeze out specific deployers from creating new pools
- Does not affect existing pools (no retroactive enforcement), limiting practical censorship power
- But creates confusion: a tier that was freely accessible becomes restricted

### Combined effect
- Significant centralization power in the owner's hands
- No timelock means these changes can be made instantly
- No event monitoring required for users to detect changes (though events are emitted)

## Attack path / preconditions

1. Multiple pools exist on the 0.05% (500) fee tier
2. Owner calls `setFeeAmountExtraInfo(500, false, false)` — disables the tier
3. No new pools can be created with the 0.05% fee
4. Existing pools continue trading normally
5. If the owner also enabled a whitelist, new pools still cannot be created on this tier

## Proof of concept

`POC: pending` — Confirm existing pools are unaffected by fee tier disablement.

**Needs:**
- Check if existing pools continue to function after tier is disabled
- Confirm no revert in pool operations after `enabled=false`

## Recommendation

### For INV-09 (fee tier immutability)
Track pool count per fee tier and disallow disabling tiers that have existing pools:

```diff
function setFeeAmountExtraInfo(uint24 fee, bool whitelistRequested, bool enabled)
    public override onlyOwner
{
    require(feeAmountTickSpacing[fee] != 0);
+   require(!enabled || poolCount[fee] == 0,
+       "Cannot disable fee tier with existing pools");
    feeAmountTickSpacingExtraInfo[fee] = TickSpacingExtraInfo({...});
}
```

### For INV-10 (whitelist)
Document that whitelist is only enforced at creation time and can be enabled retroactively. Or implement a time-delayed activation:

```diff
+   require(!whitelistRequested || block.timestamp >= activationDelay[fee],
+       "Whitelist not yet active");
```

### General
Add a timelock (e.g., 48 hours) for all fee tier parameter changes to give users and integrators time to react.

## References

- **trailofbits** — "Owner can disable fee tiers or impose whitelist retroactively — pool zombification risk" (medium)
- **trailofbits** — "Whitelist requirement for fee tiers can be bypassed by creating pools before whitelist is enabled" (medium)
- **forefy FORE-003** — "Factory owner can disable fee tiers after pools exist, breaking pool discoverability" (M)
- **solodit solodit-005** — "Owner can disable fee tiers after pools exist, potentially bricking pool creation or trapping users" (M)
- **invariant INV-09 lead** — "Fee tiers can be disabled after pools already exist — spec deviation" (medium)
- **invariant INV-10 lead** — "Whitelist requirement can be retroactively enabled on fee tiers after pools exist" (medium)
