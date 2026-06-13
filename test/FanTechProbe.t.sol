// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IFanTech {
    function supplyOf(address) external view returns (uint256);
    function getPoolValue(address) external view returns (uint256);
    function getBuyPrice(address, uint256) external view returns (uint256);
    function getSellPrice(address, uint256) external view returns (uint256);
    function balanceOf(address, address) external view returns (uint256);
    function ownerOf(address) external view returns (address);
    function getPoolReferrer(address) external view returns (address);
    function getPoolInitialBuy(address) external view returns (bool);
}

contract FanTechProbe is Test {
    address constant FANTECH = 0x53167401aeebFf5677C31E1DDA945628422D7Ed2;
    address constant OWNER = 0xA6B6Fd8bC4A063805bd1174cf3902e3e6b2368E3;

    IFanTech ft;

    bytes20 constant RAW1 = bytes20(hex"1d76b2f702c7ec44321762e71db1504f399e0b69");
    bytes20 constant RAW2 = bytes20(hex"8d825e844ca6b726ffe1741b2ee8154ce6424349");
    bytes20 constant RAW3 = bytes20(hex"94a920e94fb67241e8cf0eb72f6c7a6eafac1d29");
    bytes20 constant RAW4 = bytes20(hex"6f7862e872d84de795182f9eacc2c29db8668df8");
    bytes20 constant RAW5 = bytes20(hex"b3619062fb74800b79a0c2a005c4f253a94b2f01");
    bytes20 constant RAW6 = bytes20(hex"e59a55351cfca6a23ab72f818b434a5dfcdbee3c");
    bytes20 constant RAW7 = bytes20(hex"a1c40520f3bb012b95fc5c929da3fce6f023ce37");
    bytes20 constant RAW8 = bytes20(hex"f831fc49a856557321467988874827e505cc2b99");
    bytes20 constant RAW9 = bytes20(hex"a3f48d5b4725d7e4744f95cc053c237c9390c235");
    bytes20 constant RAW10 = bytes20(hex"2236c95858629771ee2380dd9cde2e195737969d");
    bytes20 constant RAW11 = bytes20(hex"7cc7bd52df572d61c87ec9d05d089077bab709aa");
    bytes20 constant RAW12 = bytes20(hex"42dadd578ae14b0ce0766e87eb15b042c44a1f7c");
    bytes20 constant RAW13 = bytes20(hex"670890e4ae31940a0cf28b485a3e6c1303b39d69");
    bytes20 constant RAW14 = bytes20(hex"1426ed22b90bcce4141fa513711973fdc23833d1");
    bytes20 constant RAW15 = bytes20(hex"384d7179a823c2630b97df42687bd4ab9ce2f649");
    bytes20 constant RAW16 = bytes20(hex"2917eda0301a94ad0fe5782d389bfa0691471879");
    bytes20 constant RAW17 = bytes20(hex"41bb49a9ab95f7f66f2ce54bcbcdb601fd5ddd47");
    bytes20 constant RAW18 = bytes20(hex"a26d9d2361f1ba4dec9623a9a99c9ddb4ae4c896");
    bytes20 constant RAW19 = bytes20(hex"2a94b077ab41e34abd68671d6a9ad16a3c748258");
    bytes20 constant RAW20 = bytes20(hex"6c45c298f15847964a2592e4d91b154ac06a7a22");
    bytes20 constant RAW21 = bytes20(hex"a7b80ce632a2232b093b629a8b48978a753dc9ff");
    bytes20 constant RAW22 = bytes20(hex"b802b24202f427993d245dfa43c2a183a4467c67");
    bytes20 constant RAW23 = bytes20(hex"cdeb6321d8378f5e757dd3e13ab50d62ec2f97c0");
    bytes20 constant RAW24 = bytes20(hex"eaebf2140408fcd5a4a4f31dc15811069b1e7279");
    bytes20 constant RAW25 = bytes20(hex"e300ee1ef7277ba2ce78795bf0414e34c6f0c6e8");
    bytes20 constant RAW26 = bytes20(hex"a46fd56bfae747e625a0f07dce080a57c187f707");
    bytes20 constant RAW27 = bytes20(hex"5a99aac8704ea542bc08943c0652739ac1033e4a");
    bytes20 constant RAW28 = bytes20(hex"197f59319a01ba79dc060b8daf109b2e85fc7dfc");
    bytes20 constant RAW29 = bytes20(hex"7df3b86e5fc88e46f62d08a1f6c8e71e3a547f3f");
    bytes20 constant RAW30 = bytes20(hex"805a31ed0c881beff5751ea42f3b4ed21cac7f4f");
    bytes20 constant RAW31 = bytes20(hex"c8279850ad26c6d3043ad00c30617ae291a56620");
    bytes20 constant RAW32 = bytes20(hex"d33a588670a8ff0c263d08ce2e0281c5523249d9");
    bytes20 constant RAW33 = bytes20(hex"7c75a1c36d6c72e6f85487bdb1d14277f2353a68");
    bytes20 constant RAW34 = bytes20(hex"36d2e41636e770bb74406ca875f040a2e0cfc4a9");
    bytes20 constant RAW35 = bytes20(hex"241695e552580cfb43af4ba8df534a46cb7a4e67");
    bytes20 constant RAW36 = bytes20(hex"909524ac40dbd16bb8f179255c57297b8e692fec");
    bytes20 constant RAW37 = bytes20(hex"bcc4a7cf873e4970e633d4532e8173a35a75a630");
    bytes20 constant RAW38 = bytes20(hex"31b0eeee6e9a56ed140dfa4a008e9130896bf552");
    bytes20 constant RAW39 = bytes20(hex"99a2c68a4f600acfb0f85b46ebf5f037ea10ec45");
    bytes20 constant RAW40 = bytes20(hex"b053031ae7adb0fa634127e50d2459002f87bb0a");

    function setUp() public {
        vm.createSelectFork("mantle_pub");
        ft = IFanTech(FANTECH);
    }

    function test_ScanTop40() public {
        address[40] memory subjects;
        subjects[0] = address(RAW1);
        subjects[1] = address(RAW2);
        subjects[2] = address(RAW3);
        subjects[3] = address(RAW4);
        subjects[4] = address(RAW5);
        subjects[5] = address(RAW6);
        subjects[6] = address(RAW7);
        subjects[7] = address(RAW8);
        subjects[8] = address(RAW9);
        subjects[9] = address(RAW10);
        subjects[10] = address(RAW11);
        subjects[11] = address(RAW12);
        subjects[12] = address(RAW13);
        subjects[13] = address(RAW14);
        subjects[14] = address(RAW15);
        subjects[15] = address(RAW16);
        subjects[16] = address(RAW17);
        subjects[17] = address(RAW18);
        subjects[18] = address(RAW19);
        subjects[19] = address(RAW20);
        subjects[20] = address(RAW21);
        subjects[21] = address(RAW22);
        subjects[22] = address(RAW23);
        subjects[23] = address(RAW24);
        subjects[24] = address(RAW25);
        subjects[25] = address(RAW26);
        subjects[26] = address(RAW27);
        subjects[27] = address(RAW28);
        subjects[28] = address(RAW29);
        subjects[29] = address(RAW30);
        subjects[30] = address(RAW31);
        subjects[31] = address(RAW32);
        subjects[32] = address(RAW33);
        subjects[33] = address(RAW34);
        subjects[34] = address(RAW35);
        subjects[35] = address(RAW36);
        subjects[36] = address(RAW37);
        subjects[37] = address(RAW38);
        subjects[38] = address(RAW39);
        subjects[39] = address(RAW40);

        uint256 contractBal = address(FANTECH).balance;
        emit log_named_decimal_uint("FT contract MNT", contractBal, 18);
        emit log_string("");

        uint256 totalValue = 0;
        uint256 exploitableMNT = 0;
        uint256 poolsFound = 0;

        for (uint256 i = 0; i < 40; i++) {
            address sub = subjects[i];
            uint256 supply;
            // Use staticcall to avoid revert if pool doesn't exist
            (bool ok, bytes memory d) = address(ft).staticcall(
                abi.encodeWithSelector(IFanTech.supplyOf.selector, sub)
            );
            if (!ok || d.length < 32) continue;
            supply = abi.decode(d, (uint256));
            if (supply == 0) continue;
            poolsFound++;

            uint256 value = ft.getPoolValue(sub);
            uint256 sellPrice = ft.getSellPrice(sub, 1);
            uint256 buyPrice = ft.getBuyPrice(sub, 1);
            totalValue += value;

            emit log_string("---");
            emit log_named_address("Subj", sub);
            emit log_named_uint("Sup", supply);
            emit log_named_decimal_uint("Val", value, 18);
            emit log_named_decimal_uint("Buy", buyPrice, 18);
            emit log_named_decimal_uint("Sell", sellPrice, 18);

            if (sellPrice >= value && value > 0) {
                emit log_string("[DRAIN] 1 share -> whole pool!");
                exploitableMNT += value;
            }
        }

        emit log_string("");
        emit log_string("=== SUMMARY ===");
        emit log_named_uint("Pools found", poolsFound);
        emit log_named_decimal_uint("Total tracked value", totalValue, 18);
        emit log_named_decimal_uint("Exploitable (sell=val)", exploitableMNT, 18);
        emit log_named_decimal_uint("Contract balance", contractBal, 18);
        if (contractBal > totalValue) {
            emit log_named_decimal_uint("Untracked MNT", contractBal - totalValue, 18);
        }
    }
}
