// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/// @notice Minimal interfaces for on-chain state queries
interface IInitCore {
    function oracle() external view returns (address);
    function config() external view returns (address);
    function POS_MANAGER() external view returns (address);
}

interface ILendingPool {
    function underlyingToken() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function cash() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint256);
}

interface IConfig {
    function isAllowedForCollateral(uint16 mode, address pool) external view returns (bool);
    function isAllowedForBorrow(uint16 mode, address pool) external view returns (bool);
    function getTokenFactors(uint16 mode, address pool) external view returns (uint256 collFactor, uint256 borrFactor);
}

interface IPosManager {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getPosMode(uint256 posId) external view returns (uint16);
}

interface ILiqIncentiveCalculator {
    function maxLiqIncentiveMultiplier_e18() external view returns (uint256);
    function modeLiqIncentiveMultiplier_e18(uint16 mode) external view returns (uint256);
    function tokenLiqIncentiveMultiplier_e18(address token) external view returns (uint256);
    function minLiqIncentiveMultiplier_e18(uint16 mode) external view returns (uint256);
}

contract QueryState is Script {
    // Mantle chain ID
    uint256 constant MANTLE_CHAIN_ID = 5000;

    // Core contracts
    address constant INIT_CORE = 0x972BcB0284cca0152527c4f70f8F689852bCAFc5;
    address constant CONFIG = 0x007F91636E0f986068Ef27c950FA18734BA553Ac;

    // Lending pools (Mantle)
    address constant POOL_WETH = 0x51AB74f8B03F0305d8dcE936B473AB587911AEC4;
    address constant POOL_WBTC = 0x9c9F28672C4A8Ad5fb2c9Aca6d8D68B02EAfd552;
    address constant POOL_WMNT = 0x44949636f778fAD2b139E665aee11a2dc84A2976;
    address constant POOL_USDC = 0x00A55649E597d463fD212fBE48a3B40f0E227d06;
    address constant POOL_USDT = 0xadA66a8722B5cdfe3bC504007A5d793e7100ad09;
    address constant POOL_METH = 0x5071c003bB45e49110a905c1915EbdD2383A89dF;

    // LiqIncentiveCalculator
    address constant LIQ_CALC = 0x66BDbf2Eefc84f83b476dB238574ca5Cb00550aD;

    // Helper: convert bool to string
    function _yn(bool b) internal pure returns (string memory) {
        return b ? "Y" : "N";
    }

    // Helper: string concat-ish log
    function _logSep() internal { console2.log("-------------------------------"); }

    function run() external {
        string memory mantleRpc = vm.envOr("MANTLE_RPC", string("https://rpc.mantle.xyz"));
        vm.createSelectFork(mantleRpc);

        IInitCore core = IInitCore(INIT_CORE);
        IConfig config = IConfig(CONFIG);

        address[6] memory poolAddrs = [
            POOL_WETH, POOL_WBTC, POOL_WMNT,
            POOL_USDC, POOL_USDT, POOL_METH
        ];
        string[6] memory poolNames = ["WETH", "WBTC", "WMNT", "USDC", "USDT", "METH"];

        console2.log("============================================");
        console2.log("INIT Capital on Mantle - Pool State Query");
        console2.log("============================================");
        console2.log("Fork block: ", block.number);
        console2.log("");

        address[6] memory underlyingTokens;
        uint256 totalCashUSD;
        uint256 totalAssetsUSD;
        uint256 totalDebtUSD;

        for (uint256 i = 0; i < 6; i++) {
            ILendingPool pool = ILendingPool(poolAddrs[i]);
            address underlying = pool.underlyingToken();
            underlyingTokens[i] = underlying;
            uint8 decimals = IERC20(underlying).decimals();

            uint256 cash = pool.cash();
            uint256 totalAssets = pool.totalAssets();
            uint256 totalDebt = pool.totalDebt();
            uint256 totalSupply = pool.totalSupply();

            uint256 price_e36;
            {
                (bool ok, bytes memory priceData) = address(core.oracle()).staticcall(
                    abi.encodeWithSignature("getPrice_e36(address)", underlying)
                );
                if (ok && priceData.length >= 32) {
                    price_e36 = abi.decode(priceData, (uint256));
                }
            }

            uint256 cashUSD = 0;
            uint256 assetsUSD = 0;
            uint256 debtUSD = 0;
            if (price_e36 > 0) {
                cashUSD = cash * price_e36 / 10 ** decimals / 1e18;
                assetsUSD = totalAssets * price_e36 / 10 ** decimals / 1e18;
                debtUSD = totalDebt * price_e36 / 10 ** decimals / 1e18;
            }

            totalCashUSD += cashUSD;
            totalAssetsUSD += assetsUSD;
            totalDebtUSD += debtUSD;

            console2.log("--- %s Pool ---", poolNames[i]);
            console2.log("Underlying:    ", underlying);
            console2.log("Decimals:      ", decimals);
            console2.log("Cash:          ", cash);
            console2.log("Total Assets:  ", totalAssets);
            console2.log("Total Debt:    ", totalDebt);
            console2.log("Total Supply:  ", totalSupply);
            console2.log("Cash USD:      ", cashUSD);
            console2.log("Assets USD:    ", assetsUSD);
            console2.log("Debt USD:      ", debtUSD);
            console2.log("");
        }

        console2.log("============================================");
        console2.log("Aggregate Pool State (USD)");
        console2.log("============================================");
        console2.log("Total Cash:        $", totalCashUSD);
        console2.log("Total Assets:      $", totalAssetsUSD);
        console2.log("Total Debt:        $", totalDebtUSD);
        console2.log("Utilization:       ", totalAssetsUSD > 0 ? totalDebtUSD * 10000 / totalAssetsUSD / 100 : 0, "%");
        console2.log("");

        // ── Liquidation Incentive Params ──
        console2.log("============================================");
        console2.log("Liquidation Incentive Calculator");
        console2.log("============================================");
        ILiqIncentiveCalculator calc = ILiqIncentiveCalculator(LIQ_CALC);

        uint256 maxGlobal = calc.maxLiqIncentiveMultiplier_e18();
        console2.log("Max Global Multiplier_e18: ", maxGlobal);
        console2.log("Max Bonus (global):        ", maxGlobal > 1e18 ? (maxGlobal - 1e18) * 100 / 1e16 : 0, "%");

        for (uint16 mode = 1; mode <= 5; mode++) {
            try calc.modeLiqIncentiveMultiplier_e18(mode) returns (uint256 modeMult) {
                if (modeMult > 0) {
                    console2.log("Mode", mode, "Multiplier:    ", modeMult);
                }
            } catch {
                break;
            }
        }

        for (uint16 mode = 1; mode <= 5; mode++) {
            try calc.minLiqIncentiveMultiplier_e18(mode) returns (uint256 minMult) {
                if (minMult > 0 && minMult != 1e18) {
                    console2.log("Mode", mode, "Min Multiplier:", minMult);
                }
            } catch {
                break;
            }
        }

        for (uint256 i = 0; i < 6; i++) {
            try calc.tokenLiqIncentiveMultiplier_e18(underlyingTokens[i]) returns (uint256 tokMult) {
                if (tokMult > 0 && tokMult != 1e18) {
                    console2.log("Token Mult:", poolNames[i], tokMult);
                }
            } catch {}
        }

        // ── Mode 1 Config ──
        console2.log("");
        console2.log("============================================");
        console2.log("Mode 1 - Token Factors");
        console2.log("============================================");
        for (uint256 i = 0; i < 6; i++) {
            bool isColl = config.isAllowedForCollateral(1, poolAddrs[i]);
            bool isBorr = config.isAllowedForBorrow(1, poolAddrs[i]);
            if (isColl || isBorr) {
                (uint256 collFactor, uint256 borrFactor) = config.getTokenFactors(1, poolAddrs[i]);
                console2.log(poolNames[i], "- Coll:", _yn(isColl));
                console2.log("  Borr:", _yn(isBorr));
                console2.log("  CF:", collFactor);
                console2.log("  BF:", borrFactor);
            }
        }

        // ── Positions ──
        console2.log("");
        console2.log("============================================");
        console2.log("Position Enumeration");
        console2.log("============================================");
        address posMgr = core.POS_MANAGER();

        (bool ok2, bytes memory supplyData) = posMgr.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        if (ok2 && supplyData.length >= 32) {
            uint256 totalPositions = abi.decode(supplyData, (uint256));
            console2.log("Total positions:  ", totalPositions);

            uint256 sampleSize = totalPositions < 50 ? totalPositions : 50;
            uint256 unhealthyCount;
            for (uint256 i = 1; i <= sampleSize; i++) {
                try IPosManager(posMgr).ownerOf(i) returns (address owner) {
                    uint16 mode = IPosManager(posMgr).getPosMode(i);

                    (bool ok3, bytes memory healthData) = INIT_CORE.staticcall(
                        abi.encodeWithSignature("getPosHealthCurrent_e18(uint256)", i)
                    );
                    uint256 health;
                    if (ok3 && healthData.length >= 32) {
                        health = abi.decode(healthData, (uint256));
                    }
                    bool unhealthy = ok3 && health < 1e18;

                    if (unhealthy) {
                        unhealthyCount++;
                        console2.log("  Pos:", i, "Mode:", mode);
            console2.log("  Health:", health);
            console2.log("  *** UNHEALTHY ***");
                    }
                } catch {
                    break;
                }
            }

            console2.log("");
            console2.log("Unhealthy (first %s sampled): %s", sampleSize, unhealthyCount);
            console2.log("Note: Full enumeration needs `cast logs` from PosManager");
            console2.log("      Filter Transfer(from=0x0) to find all positions.");
        }

        // ── Oracle sources ──
        console2.log("");
        console2.log("============================================");
        console2.log("Oracle Sources");
        console2.log("============================================");
        address oracleAddr = core.oracle();
        for (uint256 i = 0; i < 6; i++) {
            (bool ok4, bytes memory primData) = oracleAddr.staticcall(
                abi.encodeWithSignature("primarySources(address)", underlyingTokens[i])
            );
            (bool ok5, bytes memory secData) = oracleAddr.staticcall(
                abi.encodeWithSignature("secondarySources(address)", underlyingTokens[i])
            );
            address primary;
            address secondary;
            if (ok4 && primData.length >= 32) primary = abi.decode(primData, (address));
            if (ok5 && secData.length >= 32) secondary = abi.decode(secData, (address));
            if (primary != address(0) || secondary != address(0)) {
                console2.log("%s: primary=%s secondary=%s", poolNames[i], primary, secondary);
            }
        }

        // ── Exploit Size Estimate ──
        uint256 bonusBps = maxGlobal > 1e18 ? (maxGlobal - 1e18) * 10000 / 1e18 : 0;
        uint256 maxProfitAllCash = totalCashUSD * bonusBps / (10000 + bonusBps);

        console2.log("");
        console2.log("============================================");
        console2.log("MAXIMUM EXTRACTABLE VALUE ESTIMATE");
        console2.log("============================================");
        console2.log("");
        console2.log("Exploit: Capital-free liquidation-bonus farming");
        console2.log("  via callback reentrancy in _liquidate()");
        console2.log("");
        console2.log("Available pool cash:      $", totalCashUSD);
        console2.log("Liquidation bonus:", bonusBps, "bps");
        console2.log("  =", bonusBps / 100, "%");
        console2.log("Max with 1 position:      $", totalCashUSD * bonusBps / 10000);
        console2.log("Max with infinite pos:    $", maxProfitAllCash);
        console2.log("  (all cash borrowed, liquidated, bonus extracted)");
        console2.log("");
        console2.log("Bottleneck: # of underwater positions.");
        console2.log("Each position yields: debt_outstanding * bonus_pct");
        console2.log("Bonus for a $100k debt position @", bonusBps / 100, "%: $", 100000 * bonusBps / 10000);
        console2.log("");
    }
}
