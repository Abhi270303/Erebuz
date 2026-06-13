// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IAgniPool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint32 feeProtocol,
        bool unlocked
    );
    function protocolFees() external view returns (uint128 token0, uint128 token1);
    function liquidity() external view returns (uint128);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract ProtocolFeePOC is Test {
    address constant POOL_005_WMNT_USDC = 0x1858d52cf57c07A018171D7a1E68DC081F17144f;
    address constant POOL_1_WMNT_USDC = 0x8E2C009E45420D2B36bC15315F9de8CeCa2cc724;
    address constant POOL_005_WMNT_USDT = 0xD08C50F7E69e9aeb2867DefF4A8053d9A855e26A;
    address constant USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address constant USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
    address constant WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    function setUp() public {
        vm.createSelectFork("https://rpc.mantle.xyz");
    }

    function testDefaultProtocolFees() public {
        testPoolFees(POOL_005_WMNT_USDC, "WMNT/USDC 0.05%");
        testPoolFees(POOL_1_WMNT_USDC, "WMNT/USDC 1%");
        testPoolFees(POOL_005_WMNT_USDT, "WMNT/USDT 0.05%");
    }

    function testPoolFees(address poolAddr, string memory name) internal {
        IAgniPool pool = IAgniPool(poolAddr);

        (,,,,, uint32 feeProtocol, ) = pool.slot0();
        uint24 fee = pool.fee();

        uint32 feeProtocol0 = feeProtocol % 65536;
        uint32 feeProtocol1 = feeProtocol >> 16;

        (uint128 protocolToken0, uint128 protocolToken1) = pool.protocolFees();
        uint128 lpLiquidity = pool.liquidity();

        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 token0Balance = IERC20(token0).balanceOf(poolAddr);
        uint256 token1Balance = IERC20(token1).balanceOf(poolAddr);

        console.log("");
        console.log("=== %s ===", name);
        console.log("Fee tier: %s (%s)", fee, fee == 100 ? "0.01%" : fee == 500 ? "0.05%" : fee == 3000 ? "0.3%" : fee == 10000 ? "1%" : "?");
        console.log("Protocol fee token0: %s bps (%s%%)", feeProtocol0, uint(feeProtocol0) * 100 / 10000);
        console.log("Protocol fee token1: %s bps (%s%%)", feeProtocol1, uint(feeProtocol1) * 100 / 10000);
        console.log("LP share: %s%%", 100 - uint(feeProtocol0) * 100 / 10000);
        console.log("Accumulated protocol token0: %s", protocolToken0);
        console.log("Accumulated protocol token1: %s", protocolToken1);
        console.log("Pool liquidity: %s", lpLiquidity);
        console.log("Pool token0 balance: %s", token0Balance);
        console.log("Pool token1 balance: %s", token1Balance);

        assertTrue(feeProtocol0 >= 3000, "feeProtocol0 should be >= 3000 (30%)");
        assertTrue(feeProtocol0 <= 4000, "feeProtocol0 should be <= 4000 (40%)");
        assertTrue(feeProtocol1 >= 3000, "feeProtocol1 should be >= 3000 (30%)");
        assertTrue(feeProtocol1 <= 4000, "feeProtocol1 should be <= 4000 (40%)");
    }

    function testProtocolFeeDefaultValues() public view {
        (,,,,, uint32 fp00, ) = IAgniPool(POOL_005_WMNT_USDC).slot0();
        (,,,,, uint32 fp01, ) = IAgniPool(POOL_1_WMNT_USDC).slot0();

        // Verify these are the DEFAULT values from initialize(), not custom
        // 500 fee tier default: 222825800 = 3400:3400 (34%)
        assertEq(fp00, 222825800, "0.05% pool should have default feeProtocol 222825800 (3400:3400 = 34%)");
        // 10000 fee tier default: 209718400 = 3200:3200 (32%)
        assertEq(fp01, 209718400, "1% pool should have default feeProtocol 209718400 (3200:3200 = 32%)");
    }

    function testLpFeeShare() public view {
        (,,,,, uint32 fp00, ) = IAgniPool(POOL_005_WMNT_USDC).slot0();
        uint32 fp0 = fp00 % 65536;

        // For 0.05% pool: 3400 out of 10000 -> LPs get 6600/10000 = 66%
        console.log("");
        console.log("SWAP FEE BREAKDOWN (WMNT/USDC 0.05%%):");
        console.log("  Total swap fee: 0.05%%");
        console.log("  Protocol takes: %s%% (of the 0.05%%)", uint(fp0) * 100 / 10000);
        console.log("  LP receives: %s%% (of the 0.05%%)", (10000 - uint(fp0)) * 100 / 10000);
        console.log("  Effective LP fee: %s%%", (uint(500) * (10000 - fp0)) / 10000 / 100); 
    }

    function testAccumulatedProtocolFees() public {
        (uint128 pt00_0, uint128 pt01_0) = IAgniPool(POOL_005_WMNT_USDC).protocolFees();
        (uint128 pt10_0, uint128 pt10_1) = IAgniPool(POOL_1_WMNT_USDC).protocolFees();

        console.log("");
        console.log("Uncollected Protocol Fees:");
        console.log("  WMNT/USDC 0.05%%: %s USDC / %s WMNT", pt00_0, pt01_0);
        console.log("  WMNT/USDC 1%%: %s USDC / %s WMNT", pt10_0, pt10_1);
    }
}
