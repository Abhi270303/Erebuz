# L-01: ChefIncentivesController Owner Can Redirect Any User's Rewards

| Field | Value |
|-------|-------|
| **Severity** | LOW |
| **Status** | unconfirmed |
| **Contract** | `ChefIncentivesController.sol` |
| **Function** | `setClaimReceiver(address _user, address _receiver)` |
| **Line range** | L144–L147 |
| **Source file** | `/staking/ChefIncentivesController.sol` |

---

## Description

`setClaimReceiver()` allows setting a `claimReceiver` for **any** user address:

```solidity
function setClaimReceiver(address _user, address _receiver) external {
    require(msg.sender == _user || msg.sender == owner());
    claimReceiver[_user] = _receiver;
}
```

The `owner()` can set the claim receiver for **any** user via the `||` condition. This means the owner can redirect reward distributions intended for a specific user to themselves or any other address.

### Impact

- The owner can silently redirect any user's earned LEND rewards to themselves
- The affected user would believe their rewards are accumulating (they see the rewards in `pendingReward()` calculations) but when they call `claim()`, the minted LEND goes to the `claimReceiver` address instead
- This is a centralization risk: the owner is trusted, but the ability is unchecked and could be exploited if the owner key is compromised

### Mitigation

Remove the `owner()` override:
```solidity
function setClaimReceiver(address _user, address _receiver) external {
    require(msg.sender == _user, "Only user can set their own claim receiver");
    claimReceiver[_user] = _receiver;
}
```

## Corroboration

| Agent | Lead ID | Severity Guess |
|-------|---------|---------------|
| **pashov** | lead 8 | LOW |

Only 1 hunter flagged this.
