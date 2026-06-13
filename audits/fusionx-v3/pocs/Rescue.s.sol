// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface ILBPMasterChefV3 {
    function sweepToken(address token, uint256 amountMinimum, address recipient) external;
    function unwrapWETH9(uint256 amountMinimum, address recipient) external;
    function fusionXAmountBelongToMC() external view returns (uint256);
    function RFUSIONX() external view returns (address);
    function WETH() external view returns (address);
}

/// @title FusionX MasterChef Fund Rescue
/// @notice Whitehat sweep of vulnerable funds from LBPMasterChefV3
/// @dev
///   export SAFE=0xYourSafeAddress
///   forge script Rescue --fork-url https://rpc.mantle.xyz --broadcast --private-key $PK
contract Rescue is Script {
    ILBPMasterChefV3 constant MC = ILBPMasterChefV3(0xF6efaDb0fD3504EE1d55A3c35a8C5755aE78044e);
    address constant RFSX = 0xb7feC4ff66b32764758A7DF9D6410F6279929a7E;
    address constant WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    function run() external {
        address safe = vm.envAddress("SAFE");
        require(safe != address(0), "Set SAFE env var");
        console.log("Rescuing funds to:", safe);
        console.log("");

        vm.startBroadcast();

        sweepIfNonZero(safe, WMNT);
        sweepIfNonZero(safe, 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9);
        sweepIfNonZero(safe, 0x201eBA5Cc46d216ce6dC04F19615EF6e9B4e3ed7);
        sweepIfNonZero(safe, 0xcDA86A272531e8640cD7F1a92c01839911B90bb0);
        sweepIfNonZero(safe, RFSX);

        // Unwrap + drain WETH
        address weth = MC.WETH();
        if (weth.code.length > 0) {
            uint256 wethBal = IERC20(weth).balanceOf(address(MC));
            if (wethBal > 0) {
                console.log("Unwrapping WETH:", wethBal);
                MC.unwrapWETH9(0, safe);
            }
        }

        vm.stopBroadcast();
        console.log("");
        console.log("Rescue complete ->", safe);
    }

    function sweepIfNonZero(address safe, address token) internal {
        if (token.code.length == 0) return;
        uint256 bal = IERC20(token).balanceOf(address(MC));
        if (bal == 0) return;

        console.log("Sweeping token");
        console.log("  balance:", bal);
        MC.sweepToken(token, 0, safe);
    }
}
