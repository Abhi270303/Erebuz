//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

struct Pool {
    uint256 initialShares;
    uint256 endTimeBid;
    uint256 value;
    uint256 sharesSupply;
    uint256 subjectFee;
    uint256 referrerFee;
    address owner;
    address referrer;
    mapping(address => uint256) sharesBalance;
}

struct PoolInitialTop {
    address account;
    uint256 amount;
}

contract FanTech is
    Initializable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    using ECDSA for bytes32;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant PERCENT_BASE = 100;
    uint256 public constant PRICE_STEP_PERCENT = 10;

    // pricing params
    uint256 public constant PRICE_A = 1 ether;
    uint256 public constant PRICE_B = 5;
    uint256 public constant PRICE_C = 4680000; // tax param

    uint256 public constant INIT_BID_PRICE = PRICE_A;

    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public referrerFeePercent;
    uint256 public poolFeePercent;
    uint256 public maxInitialShares;

    uint256 private totalFees;

    mapping(address => Pool) pools;
    mapping(address => PoolInitialTop[]) poolInitialTops;

    // ReentrancyGuard
    // Add new variable - 0.3.0
    uint256 private constant GUARD_NOT_ENTERED = 1;
    uint256 private constant GUARD_ENTERED = 2;
    uint256 private _guardStatus;
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        require(_guardStatus != GUARD_ENTERED);
        _guardStatus = GUARD_ENTERED;
        _;
        _guardStatus = GUARD_NOT_ENTERED;
    }

    event Trade(
        address trader,
        address subject,
        bool isBuy,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolFee,
        uint256 subjectFee,
        uint256 referrerFee,
        uint256 poolFee,
        uint256 balance,
        uint256 totalSupply,
        bool isAirdrop,
        bool isBid
    );

    function initialize() public initializer {
        __Ownable_init();
        __AccessControl_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // init value
        protocolFeeDestination = owner();
        protocolFeePercent = ((1 ether) * 3) / 100;
        subjectFeePercent = ((1 ether) * 5) / 100;
        referrerFeePercent = ((1 ether) * 1) / 100;
        poolFeePercent = ((1 ether) * 1) / 100;
        _updateTotalFees();

        maxInitialShares = 10;
    }

    ///////////////////////////
    ////// SYSTEM ACTION //////
    ///////////////////////////
    function initializeSharesSub(
        address sharesSubject,
        uint256 _initialShares,
        uint256 _blockTime
    ) external payable onlyRole(OPERATOR_ROLE) {
        require(_initialShares <= maxInitialShares, "Initial shares exceeded");
        require(pools[sharesSubject].sharesSupply == 0, "Share pool exist");

        Pool storage newPool = pools[sharesSubject];
        newPool.initialShares = _initialShares;
        newPool.endTimeBid = block.timestamp + _blockTime;
        newPool.sharesSupply = 1;
        newPool.sharesBalance[sharesSubject] = 1;

        emit Trade(
            sharesSubject,
            sharesSubject,
            true,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            1,
            false,
            false
        );
    }

    function initializeSharesBySystem(
        address sharesSubject,
        address referrer,
        uint256 _initialShares,
        uint256 _blockTime
    ) external onlyRole(OPERATOR_ROLE) {
        require(_initialShares <= maxInitialShares, "Initial shares exceeded");
        require(sharesSubject != address(0), "Invalid Share Subject");
        require(
            referrer != address(0) && sharesSubject != referrer,
            "Invalid Referer"
        );
        require(pools[sharesSubject].sharesSupply == 0, "Share pool exist");

        //BUY FIRST SHARE FOR SHARE SUBJECT
        Pool storage newPool = pools[sharesSubject];
        newPool.owner = sharesSubject;
        newPool.referrer = referrer;
        newPool.initialShares = _initialShares;
        newPool.endTimeBid = block.timestamp + _blockTime;
        newPool.sharesSupply = 1;
        newPool.sharesBalance[sharesSubject] = 1;

        emit Trade(
            sharesSubject,
            sharesSubject,
            true,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            1,
            false,
            false
        );

        //BUY SHARE FOR REF
        newPool.sharesBalance[referrer] = 1;
        newPool.sharesSupply += 1;
        newPool.value = 0;

        emit Trade(
            referrer,
            sharesSubject,
            true,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            2,
            true,
            false
        );
    }

    /////////////////////////
    ////// USER ACTION //////
    /////////////////////////
    function initializeShares(
        address referrer,
        uint256 _initialShares,
        uint256 _blockTime,
        uint256 nonce,
        bytes memory signature
    ) external payable {
        address sharesSubject = msg.sender;

        require(_initialShares <= maxInitialShares, "Initial shares exceeded");
        require(
            referrer != address(0) && sharesSubject != referrer,
            "Invalid Referer"
        );
        require(pools[sharesSubject].sharesSupply == 0, "Share pool exist");

        bytes32 hash = keccak256(
            abi.encodePacked(
                address(this),
                sharesSubject,
                referrer,
                _initialShares,
                _blockTime,
                msg.value,
                nonce
            )
        );
        address recoverAddress = hash.toEthSignedMessageHash().recover(
            signature
        );

        require(
            hasRole(OPERATOR_ROLE, recoverAddress),
            "Caller doesn't have permission of operator"
        );

        //BUY FIRST SHARE FOR SHARE SUBJECT
        Pool storage newPool = pools[sharesSubject];
        newPool.owner = sharesSubject;
        newPool.referrer = referrer;
        newPool.initialShares = _initialShares;
        newPool.endTimeBid = block.timestamp + _blockTime;
        newPool.sharesSupply = 1;
        newPool.sharesBalance[sharesSubject] = 1;

        emit Trade(
            sharesSubject,
            sharesSubject,
            true,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            1,
            false,
            false
        );

        //BUY SHARE FOR REF
        uint256 price = getPrice(1, 1);
        require(msg.value == price, "Invalid price");
        newPool.sharesBalance[referrer] = 1;
        newPool.sharesSupply += 1;
        newPool.value = price;

        emit Trade(
            referrer,
            sharesSubject,
            true,
            1,
            price,
            0,
            0,
            0,
            0,
            1,
            2,
            true,
            false
        );
    }

    function buyShares(address sharesSubject) external payable nonReentrant {
        require(
            pools[sharesSubject].sharesSupply > 0,
            "Shared subject not initialize"
        );
        //check if initialBuys finish
        if (_isBidding(sharesSubject)) {
            _bidShares(sharesSubject);
        } else {
            _buyShares(sharesSubject);
        }
    }

    function sellShares(
        address sharesSubject,
        uint256 amount
    ) external nonReentrant {
        Pool storage pool = pools[sharesSubject];
        require(
            amount > 0 && pool.sharesSupply > amount,
            "Cannot sell the last share"
        );

        require(
            !_isBidding(sharesSubject),
            "Cannot sell share in initial buy time"
        );
        require(
            (pool.owner != msg.sender &&
                pool.sharesBalance[msg.sender] >= amount) ||
                (pool.owner == msg.sender &&
                    pool.sharesBalance[msg.sender] > amount),
            "Insufficient shares"
        );
        uint256 price = getSellPrice(sharesSubject, amount);
        (
            uint256 protocolFee,
            uint256 subjectFee,
            uint256 referrerFee,
            uint256 poolFee
        ) = getFee(price);

        pool.sharesBalance[msg.sender] -= amount;
        pool.sharesSupply -= amount;

        pool.value = pool.value + poolFee - price;

        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee - poolFee - referrerFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        require(success1 && success2, "Unable to send funds");

        _transferForOwner(sharesSubject, subjectFee);
        _transferForReferrer(sharesSubject, referrerFee);

        uint balance = pool.sharesBalance[msg.sender];
        uint supply = pool.sharesSupply;
        emit Trade(
            msg.sender,
            sharesSubject,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            referrerFee,
            poolFee,
            balance,
            supply,
            false,
            false
        );
    }

    function activateOwner(
        address sharesSubject,
        address referrer,
        uint256 nonce,
        bytes memory signature
    ) external nonReentrant {
        Pool storage pool = pools[sharesSubject];
        require(
            pools[sharesSubject].sharesSupply > 0,
            "Share pool does not exist"
        );
        require(
            pools[sharesSubject].owner == address(0),
            "Share pool activated owner"
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                address(this),
                sharesSubject,
                referrer,
                msg.sender,
                nonce
            )
        );

        address recoverAddress = hash.toEthSignedMessageHash().recover(
            signature
        );

        require(
            hasRole(OPERATOR_ROLE, recoverAddress),
            "Caller doesn't have permission of operator"
        );

        pool.owner = msg.sender;
        pool.referrer = referrer;

        _transferForOwner(sharesSubject, 0);
        _transferForReferrer(sharesSubject, 0);

        uint supply = pool.sharesSupply;
        uint balance = pool.sharesBalance[sharesSubject];

        // Transfer 1 share from shareSuject to new owner
        pool.sharesBalance[sharesSubject] -= 1;
        pool.sharesBalance[pool.owner] += 1;

        emit Trade(
            sharesSubject,
            sharesSubject,
            false,
            1,
            0,
            0,
            0,
            0,
            0,
            balance - 1,
            supply,
            false,
            false
        );

        uint ownerBalance = pool.sharesBalance[pool.owner];
        emit Trade(
            pool.owner,
            sharesSubject,
            true,
            1,
            0,
            0,
            0,
            0,
            0,
            ownerBalance,
            supply,
            false,
            false
        );
    }

    ////////////////////
    ////// SETTER //////
    ////////////////////
    function setProtocolFeeDestination(
        address _feeDestination
    ) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
        _updateTotalFees();
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
        _updateTotalFees();
    }

    function setReferrerFeePercent(uint256 _feePercent) public onlyOwner {
        referrerFeePercent = _feePercent;
        _updateTotalFees();
    }

    function setPoolFeePercent(uint256 _feePercent) public onlyOwner {
        poolFeePercent = _feePercent;
        _updateTotalFees();
    }

    function setMaxInitialShares(uint256 _maxInitialShares) public onlyOwner {
        maxInitialShares = _maxInitialShares;
    }

    ////////////////////
    ////// GETTER //////
    ////////////////////
    function getPrice(
        uint256 supply,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 sum1 = supply == 0
            ? 0
            : ((supply - 1) * (supply) * (2 * (supply - 1) + 1)) / 6;
        uint256 sum2 = supply == 0 && amount == 1
            ? 0
            : ((supply + amount - 1) *
                (supply + amount) *
                (2 * (supply + amount - 1) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return (summation * PRICE_A) / PRICE_B;
    }

    function _getSupply(
        uint256 supply,
        uint256 liquid
    ) internal pure returns (uint256 _supply) {
        _supply = supply;
        uint256 _normLiquid1 = getPrice(0, _supply);
        uint256 _normLiquid2 = _normLiquid1;
        if (_normLiquid1 > liquid) {
            while (_supply > 1 && _normLiquid2 > liquid) {
                _supply--;
                _normLiquid2 = getPrice(0, _supply);
            }
            if (_supply < supply) _supply++;
        } else {
            while (_normLiquid2 < liquid) {
                _supply++;
                _normLiquid2 = getPrice(_supply - supply, supply);
            }
        }
    }

    function getBuyPrice(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256 price) {
        uint256 _supply = _getSupply(
            pools[sharesSubject].sharesSupply,
            pools[sharesSubject].value
        );
        price = getPrice(_supply, amount);
    }

    function getSellPrice(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256 price) {
        uint256 supply = pools[sharesSubject].sharesSupply;
        uint256 liquid = pools[sharesSubject].value;
        uint256 _supply = _getSupply(supply, liquid);
        if (_supply <= amount) _supply = amount + 1;
        price = getPrice(_supply - amount, amount);
        if (price > liquid) price = liquid;
    }

    function getBuyPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        (
            uint256 protocolFee,
            uint256 subjectFee,
            uint256 referrerFee,
            uint256 poolFee
        ) = getFee(price);
        return price + protocolFee + subjectFee + referrerFee + poolFee;
    }

    function getSellPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        (
            uint256 protocolFee,
            uint256 subjectFee,
            uint256 referrerFee,
            uint256 poolFee
        ) = getFee(price);
        return price - protocolFee - subjectFee - referrerFee - poolFee;
    }

    function balanceOf(
        address sharesSubject,
        address account
    ) external view returns (uint256) {
        return pools[sharesSubject].sharesBalance[account];
    }

    function supplyOf(address sharesSubject) external view returns (uint256) {
        return pools[sharesSubject].sharesSupply;
    }

    function ownerOf(address sharesSubject) external view returns (address) {
        return pools[sharesSubject].owner;
    }

    function getPoolSubjectFee(
        address sharesSubject
    ) external view returns (uint256) {
        return pools[sharesSubject].subjectFee;
    }

    function getPoolReferrerFee(
        address sharesSubject
    ) external view returns (uint256) {
        return pools[sharesSubject].referrerFee;
    }

    function getPoolInitialTops(
        address sharesSubject
    ) external view returns (PoolInitialTop[] memory) {
        return poolInitialTops[sharesSubject];
    }

    function getPoolValue(
        address sharesSubject
    ) external view returns (uint256) {
        return pools[sharesSubject].value;
    }

    function getPoolReferrer(
        address sharesSubject
    ) external view returns (address) {
        return pools[sharesSubject].referrer;
    }

    function getPoolInitialBuy(
        address sharesSubject
    ) external view returns (bool) {
        return _isBidding(sharesSubject);
    }

    function getPoolInitialBuyPriceAfterFee(
        address sharesSubject
    ) public view returns (uint256) {
        if (
            poolInitialTops[sharesSubject].length <
            pools[sharesSubject].initialShares
        ) {
            return INIT_BID_PRICE;
        } else {
            return
                (poolInitialTops[sharesSubject][0].amount *
                    (100 + PRICE_STEP_PERCENT)) / 100;
        }
    }

    function getBiddingTime(
        address sharesSubject
    ) external view returns (uint256) {
        return pools[sharesSubject].endTimeBid;
    }

    function getFee(
        uint256 price
    )
        public
        view
        returns (
            uint256 protocolFee,
            uint256 subjectFee,
            uint256 referrerFee,
            uint256 poolFee
        )
    {
        uint maxTax = 1000;
        uint taxByPrice = PRICE_C / _sqrt((price * PRICE_B * 10000) / PRICE_A);
        if (taxByPrice > maxTax) taxByPrice = maxTax;

        protocolFee =
            ((price * protocolFeePercent * taxByPrice) / maxTax) /
            1 ether;
        subjectFee =
            ((price * subjectFeePercent * taxByPrice) / maxTax) /
            1 ether;
        referrerFee =
            ((price * referrerFeePercent * taxByPrice) / maxTax) /
            1 ether;
        poolFee = ((price * poolFeePercent * taxByPrice) / maxTax) / 1 ether;
    }

    function version() external pure returns (string memory) {
        return "0.3.0";
    }

    //////////////////////
    ////// INTERNAL //////
    //////////////////////
    function _isBidding(address sharesSubject) internal view returns (bool) {
        return block.timestamp <= pools[sharesSubject].endTimeBid;
    }

    function _updateTotalFees() internal {
        totalFees =
            protocolFeePercent +
            subjectFeePercent +
            referrerFeePercent +
            poolFeePercent;
        require(totalFees <= (1 ether) / 10, "Total Fee must less than 10%");
    }

    function _checkIfValidToTop(
        address sharesSubject,
        uint256 amount
    ) internal view returns (bool valid, uint256 index) {
        valid = amount >= getPoolInitialBuyPriceAfterFee(sharesSubject);

        if (poolInitialTops[sharesSubject].length != 0 && valid) {
            uint256 i;
            if (
                poolInitialTops[sharesSubject].length <
                pools[sharesSubject].initialShares
            ) {
                i = poolInitialTops[sharesSubject].length;
                while (
                    i > 0 &&
                    amount < poolInitialTops[sharesSubject][i - 1].amount
                ) {
                    i--;
                }
            } else {
                i = poolInitialTops[sharesSubject].length - 1;
                while (
                    i > 0 && amount < poolInitialTops[sharesSubject][i].amount
                ) {
                    i--;
                }
            }
            index = i;
        }
    }

    function _injectToTops(
        address sharesSubject,
        address account,
        uint256 amount
    ) internal returns (address shiftAccount, uint256 refundAmount) {
        (bool isValidToTops, uint256 index) = _checkIfValidToTop(
            sharesSubject,
            amount
        );

        require((isValidToTops), "Invalid amount");

        if (
            poolInitialTops[sharesSubject].length <
            pools[sharesSubject].initialShares
        ) {
            //expand the array
            PoolInitialTop memory newPoolInitialTop;
            newPoolInitialTop.account = address(0);
            poolInitialTops[sharesSubject].push(newPoolInitialTop);
            // shift from index to right
            for (
                uint i = poolInitialTops[sharesSubject].length - 1;
                i > index;
                i--
            ) {
                poolInitialTops[sharesSubject][i].account = poolInitialTops[
                    sharesSubject
                ][i - 1].account;
                poolInitialTops[sharesSubject][i].amount = poolInitialTops[
                    sharesSubject
                ][i - 1].amount;
            }
        } else {
            shiftAccount = poolInitialTops[sharesSubject][0].account;
            refundAmount = poolInitialTops[sharesSubject][0].amount;
            // shift from index to left
            for (uint i = 0; i < index; i++) {
                poolInitialTops[sharesSubject][i].account = poolInitialTops[
                    sharesSubject
                ][i + 1].account;
                poolInitialTops[sharesSubject][i].amount = poolInitialTops[
                    sharesSubject
                ][i + 1].amount;
            }
        }
        poolInitialTops[sharesSubject][index].account = account;
        poolInitialTops[sharesSubject][index].amount = amount;
    }

    // Buy in bidding time
    function _bidShares(address sharesSubject) internal {
        (address shiftAccount, uint256 refundAmount) = _injectToTops(
            sharesSubject,
            msg.sender,
            msg.value
        );

        Pool storage pool = pools[sharesSubject];
        pool.sharesBalance[msg.sender] += 1;
        // //shift first element of top list and refund to account if top list exceed
        if (shiftAccount != address(0)) {
            (bool status, ) = shiftAccount.call{value: refundAmount}("");
            // payable(shiftAccount).transfer(refundAmount);
            pool.sharesBalance[shiftAccount] -= 1;
        } else {
            pool.sharesSupply++;
        }

        uint256 diffPrice = ((msg.value - refundAmount) * 1 ether) /
            (totalFees + 1 ether);

        (
            uint256 protocolFee,
            uint256 subjectFee,
            uint256 referrerFee,
            uint256 poolFee
        ) = getFee(diffPrice);

        pool.value =
            pool.value +
            msg.value -
            refundAmount -
            protocolFee -
            subjectFee -
            referrerFee;

        (bool success, ) = protocolFeeDestination.call{value: protocolFee}("");
        require(success, "Unable to send funds");
        _transferForOwner(sharesSubject, subjectFee);
        _transferForReferrer(sharesSubject, referrerFee);

        uint balance = pool.sharesBalance[shiftAccount];
        uint supply = pool.sharesSupply;

        if (shiftAccount != address(0)) {
            emit Trade(
                shiftAccount,
                sharesSubject,
                false,
                1,
                refundAmount,
                0,
                0,
                0,
                0,
                balance,
                supply,
                false,
                true
            );
        }

        balance = pool.sharesBalance[msg.sender];
        emit Trade(
            msg.sender,
            sharesSubject,
            true,
            1,
            (msg.value * (1 ether)) / (1 ether + totalFees),
            protocolFee,
            subjectFee,
            referrerFee,
            poolFee,
            balance,
            supply,
            false,
            true
        );
    }

    // buy
    function _buyShares(address sharesSubject) internal {
        Pool storage pool = pools[sharesSubject];
        uint256 price = getBuyPrice(sharesSubject, 1);
        (
            uint256 protocolFee,
            uint256 subjectFee,
            uint256 referrerFee,
            uint256 poolFee
        ) = getFee(price);
        require(
            msg.value >=
                price + protocolFee + subjectFee + referrerFee + poolFee,
            "Insufficient payment"
        );

        pool.sharesBalance[msg.sender] += 1;
        pool.sharesSupply += 1;

        pool.value =
            pool.value +
            msg.value -
            protocolFee -
            subjectFee -
            referrerFee;

        (bool success, ) = protocolFeeDestination.call{value: protocolFee}("");
        require(success, "Unable to send funds");

        _transferForOwner(sharesSubject, subjectFee);
        _transferForReferrer(sharesSubject, referrerFee);

        uint balance = pool.sharesBalance[msg.sender];
        uint supply = pool.sharesSupply;
        emit Trade(
            msg.sender,
            sharesSubject,
            true,
            1,
            price,
            protocolFee,
            subjectFee,
            referrerFee,
            poolFee,
            balance,
            supply,
            false,
            false
        );
    }

    function _transferForOwner(address sharesSubject, uint256 amount) internal {
        address owner = pools[sharesSubject].owner;

        if (owner != address(0)) {
            uint subjectFee = pools[sharesSubject].subjectFee + amount;
            require(subjectFee > 0, "Subject fee more than 0");
            pools[sharesSubject].subjectFee = 0;
            (bool success, ) = owner.call{value: subjectFee}("");
            require(success, "Unable to send funds");
        } else {
            pools[sharesSubject].subjectFee += amount;
        }
    }

    function _transferForReferrer(
        address sharesSubject,
        uint256 amount
    ) internal {
        address referrer = pools[sharesSubject].referrer;

        if (referrer != address(0)) {
            uint referrerFee = pools[sharesSubject].referrerFee + amount;
            require(referrerFee > 0, "Referrer fee more than 0");
            pools[sharesSubject].referrerFee = 0;

            (bool success, ) = referrer.call{value: referrerFee}("");
            require(success, "Unable to send funds");
        } else {
            pools[sharesSubject].referrerFee += amount;
        }
    }

    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
