# Merchant Moe — Integration Map

## Contract Dependencies
```
LBFactory
  └→ creates LBPair (per tokenX, tokenY, binStep)
      └→ uses BinHelper, FeeHelper, OracleHelper, PriceHelper, etc.
      └→ LBToken (ERC-1155 for LP positions)
      └→ hooks → LBHooksBaseRewarder / LBHooksMCRewarder

LBRouter
  └→ swap(), mint(), burn() on LBPair
  └→ flashLoan() on LBPair

LBHooksManager (owner)
  └→ creates LBHooksMCRewarder (per LB pair, per MasterChef pid)
      └→ linked to LBPair as hooks contract
      └→ MasterChef.add() — rewarder token deposited as "farm"
          └→ MasterChef distributes MOE rewards to rewarder
          └→ rewarder distributes to LP holders proportionally

MoeStaking
  └→ stake/unstake MOE
  └→ onModify → VeMoe.onModify (update veMoe)
  └→ onModify → sMoe.onModify (update stable MOE)

VeMoe
  └→ vote(pid, delta) → allocates veMoe to MasterChef pools
  └→ weight(pid) = min(votes, votes^alpha) for top pools
  └→ bribe contracts can reward voters per pool

MasterChef
  └→ reward distribution per pid based on veMoe weights
  └→ deposit/withdraw LP tokens → earns MOE rewards
  └→ MOE minted by MasterChef (minter of Moe token)
  └→ treasury share deducted from rewards

MoeFactory
  └→ creates MoePair (traditional Uniswap V2 AMM)
      └→ MoeRouter routes swaps through MoePair

MOE Token
  └→ minted only by MasterChef (up to 1B max supply)
  └→ standard ERC20Permit

## External Integrations
- WMNT (Wrapped Mantle)
- USDC, USDT, USDE (stablecoins — bridged to Mantle)
- No external oracles (LB pairs use internal TWAP for fee calculation only)

## Data Flow: Reward Cycle
1. MasterChef mints MOE → distributes to farms by weight
2. LBHooksMCRewarder receives MOE as farm sink token
3. LBHooksMCRewarder tracks per-bin accRewardsPerShareX64
4. LP holders claim → rewards proportional to LP balance in rewarded bins
5. Rewarded range = [activeId + deltaBinA, activeId + deltaBinB)

## Data Flow: Voting Cycle
1. User stakes MOE in MoeStaking
2. VeMoe.veMoe accrues over time (capped by balance * MAX_VE_MOE_PER_MOE)
3. User votes on pool PIDs → weights calculated as min(votes, votes^alpha)
4. MasterChef reads weights → distributes MOE rewards proportional to weight
5. Bribes incentivize voting on specific pools

## Security Boundaries
- All LB pair operations go through `nonReentrant` guard (except hooks callbacks)
- MasterChef is ownable, access-controlled for admin functions
- LBHooksManager is ownable, controls hooks creation
- VeMoe checks `_rewarderFactory.getRewarderType()` for bribe validation
- MOE token only mintable by MasterChef (single minter)
