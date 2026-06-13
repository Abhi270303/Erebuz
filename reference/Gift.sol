//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

struct Creator {
    uint256 creatorTotalAmount;
    uint256 holdersTotalAmount;
    uint256 creatorTotalPayout;
    uint256 holdersTotalPayout;
}

contract Gift is
    Initializable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant BASE_PERCENTAGE = 10000;

    address public protocolTaxDestination;
    uint256 public protocolTaxPercent;

    address public holderTaxDestination;
    uint256 public holderTaxPercent;

    mapping(address => Creator) public creators;

    mapping(address => mapping(address => uint256)) private _balances; // user => contentId => gift amount

    event Gifted(
        address contentId,
        address creator,
        address user,
        uint256 amount,
        uint256 balance,
        uint256 holderTax,
        uint256 protocolTax,
        uint256 creatorTotalAmount,
        uint256 holdersTotalAmount
    );

    event WidthdrawHolderTax(
        address[] creators,
        uint256[] amounts,
        uint256 totalAmount
    );

    event WidthdrawGift(address creator, uint256 amount);

    function initialize() public initializer {
        __Ownable_init();
        __AccessControl_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __ReentrancyGuard_init();
        // init value
        protocolTaxDestination = owner();
        protocolTaxPercent = BASE_PERCENTAGE / 10;

        holderTaxDestination = owner();
        holderTaxPercent = BASE_PERCENTAGE / 10;
    }

    ///////////////////////////
    ////// SYSTEM ACTION //////
    ///////////////////////////
    function withdrawHolderTax(
        address[] memory creators_
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        uint256 totalAmount = 0;
        uint256[] memory amounts = new uint256[](creators_.length);
        for (uint256 i; i < creators_.length; i++) {
            Creator storage creator = creators[creators_[i]];
            amounts[i] =
                creator.holdersTotalAmount -
                creator.holdersTotalPayout;
            totalAmount += amounts[i];
            // update payout for holders
            creator.holdersTotalPayout = creator.holdersTotalAmount;
        }
        require(totalAmount > 0, "Unavailable Holders Payout");

        // transfer protocol tax
        (bool success, ) = holderTaxDestination.call{value: totalAmount}("");
        require(success, "Send Holder Tax Fail.");

        emit WidthdrawHolderTax(creators_, amounts, totalAmount);
    }

    ///////////////////////////
    /////// USER ACTION ///////
    ///////////////////////////

    // user send gift to creator for a content
    function giftTo(
        address creator_,
        address contentId_,
        bytes memory signature_
    ) external payable nonReentrant {
        // verify input param to make sure contentId belong to creator_
        bytes32 hash = keccak256(
            abi.encodePacked(address(this), creator_, contentId_)
        );
        address recoverAddress = hash.toEthSignedMessageHash().recover(
            signature_
        );

        require(
            hasRole(OPERATOR_ROLE, recoverAddress),
            "Caller doesn't have permission of operator"
        );

        uint256 amount = msg.value;
        require(amount > 0);

        uint256 protocolTax = (amount * protocolTaxPercent) / BASE_PERCENTAGE;
        uint256 holderTax = (amount * holderTaxPercent) / BASE_PERCENTAGE;
        uint256 creatorAmount = amount - protocolTax - holderTax;
        // transfer protocol tax
        (bool success, ) = protocolTaxDestination.call{value: protocolTax}("");
        require(success, "Send Protocol Tax Fail.");
        // update data
        Creator storage creator = creators[creator_];
        creator.creatorTotalAmount += creatorAmount;
        creator.holdersTotalAmount += holderTax;

        // store gift balance
        address user = msg.sender;
        _balances[user][contentId_] += amount;
        uint256 balance = _balances[user][contentId_];

        emit Gifted(
            contentId_,
            creator_,
            user,
            amount,
            balance,
            holderTax,
            protocolTax,
            creator.creatorTotalAmount,
            creator.holdersTotalAmount
        );
    }

    // Creator withdraw his gift revenue
    function withdrawGift(
        uint256 amount,
        uint256 signTime,
        bytes memory signature_
    ) external nonReentrant {
        // verify input param to make sure authorised call
        require(amount > 0);
        require(signTime > block.timestamp - 300, "Signature Expired");
        bytes32 hash = keccak256(
            abi.encodePacked(address(this), msg.sender, amount, signTime)
        );
        address recoverAddress = hash.toEthSignedMessageHash().recover(
            signature_
        );

        require(
            hasRole(OPERATOR_ROLE, recoverAddress),
            "Caller doesn't have permission of operator"
        );

        address creator_ = msg.sender;
        Creator storage creator = creators[creator_];
        uint availableAmount = creator.creatorTotalAmount -
            creator.creatorTotalPayout;
        require(availableAmount >= amount, "Not enough available amount");

        // transfer protocol tax
        creator.creatorTotalPayout += amount;
        (bool success, ) = creator_.call{value: amount}("");
        require(success, "Send Creator Gift Fail.");

        emit WidthdrawGift(creator_, amount);
    }

    ///////////////////////////
    ///////// SETTER //////////
    ///////////////////////////
    function setProtocolTaxDestination(address _destination) public onlyOwner {
        require(_destination != address(0));
        protocolTaxDestination = _destination;
    }

    function setProtocolTaxPercent(uint256 _taxPercent) public onlyOwner {
        require(
            _taxPercent <= BASE_PERCENTAGE / 3,
            "Tax Value must less than 3333"
        );
        protocolTaxPercent = _taxPercent;
    }

    function setHolderTaxDestination(address _destination) public onlyOwner {
        require(_destination != address(0));
        holderTaxDestination = _destination;
    }

    function setHolderTaxPercent(uint256 _taxPercent) public onlyOwner {
        require(
            _taxPercent <= BASE_PERCENTAGE / 3,
            "Tax Value must less than 3333"
        );
        holderTaxPercent = _taxPercent;
    }

    ///////////////////////////
    ///////// GETTER //////////
    ///////////////////////////

    function giftOf(
        address account,
        address contentId
    ) external view returns (uint256) {
        return _balances[account][contentId];
    }

    ///////////////////////////
    //////// INTERNAL /////////
    ///////////////////////////
}
