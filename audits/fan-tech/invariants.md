# fan.tech - Invariants

## Protocol Overview
fan.tech is a SocialFi protocol on Mantle, forked from friend.tech V1. Users buy/sell "shares" of other users via a bonding curve. Major addition: initial offering/bidding system and a separate Gift/tipping contract.

## Key Contract Addresses
- FanTech proxy: `0x53167401aeebFf5677C31E1DDA945628422D7Ed2`
- FanTech impl: `0x20aa28a1f66a6cbd97de8eb1907a5643eef7a108`
- Gift proxy: `0xD42A821E584513e18cFB77e56Bf635C551dE5D63`
- Gift impl: `0xca3c6da9ef077590b75c0d909e808fc07c40981e`
- Proxy admin: `0x6018536f5B58f6c1B550f6650f0b9127F3E59d0c` (EOA)
- Owner: `0xA6B6Fd8bC4A063805bd1174cf3902e3e6b2368E3` (EOA)

## Invariants

### 1. Total shares supply = sum of all holder balances
- Each Pool has a `sharesSupply` and `sharesBalance` mappings
- sum(sharesBalance[subject][holder]) for all holders MUST equal sharesSupply
- NOT ENFORCED: No function checks or maintains this invariant across operations

### 2. Pool value tracks actual MNT backing (accounting invariant)
- `pool.value` tracks the MNT value of shares
- On buy: `value += msg.value - protocolFee - subjectFee - referrerFee`
- On sell: `value += poolFee - price`
- ON BID: `value += msg.value - refundAmount - protocolFee - subjectFee - referrerFee`
- VIOLATED: Pool fee (`poolFee`) is never subtracted from value on buys, but is added on sells

### 3. Price always follows bonding curve 
- Price = integral of squares from supply to supply+amount, scaled by PRICE_A/PRICE_B
- Formula: `getPrice(supply, amount)` uses sum-of-squares formula
- UNENFORCED: The actual pool value can diverge from theoretical curve price due to the `_getSupply` adjustment

### 4. Last share cannot be sold
- `require(supply > amount, "Cannot sell the last share")` for regulars
- Owner must keep balance > amount (effectively 1 share minimum)
- ENFORCED in `sellShares`

### 5. Owner can control all fees (up to 10% total)
- `_updateTotalFees` enforces totalFees <= 0.1 ether (10%)
- BYPASSABLE: totalFees check only runs on individual setter calls, not on transfer

### 6. OPERATOR_ROLE controls pool creation
- `initializeShares`, `initializeSharesBySystem`, `initializeSharesSub` require OPERATOR_ROLE
- `activateOwner` requires OPERATOR_ROLE signature
- ENFORCED via ECDSA recovery + hasRole check

### 7. Total fees must be <= 10%
- `_updateTotalFees` checks protocolFeePercent + subjectFeePercent + referrerFeePercent + poolFeePercent <= 0.1 ether
- NOT VIOLATED: Each setter validates

### 8. Gift contract protocol/holder tax max 33.33%
- `setProtocolTaxPercent` and `setHolderTaxPercent` enforce `<= BASE_PERCENTAGE / 3` (3333 bps = 33.33%)
- ENFORCED

### 9. `_bidShares` external call before state update
- VIOLATED: Line 783 sends ETH via `.call{value:}("")` BEFORE decrementing share balance on line 785
- Protected by `nonReentrant` but return value unchecked

### 10. Pool value monotonicity
- Pool value should only increase on buys/bids and decrease on sells
- BUY: value increases by msg.value - protocolFee - subjectFee - referrerFee (net increase after extracting fees)
- SELL: value changes by poolFee - price (net decrease since price > poolFee by definition)
- BID: value increases by msg.value - refundAmount - protocolFee - subjectFee - referrerFee
