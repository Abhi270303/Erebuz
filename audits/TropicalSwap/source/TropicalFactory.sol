// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.5.16;

import './interfaces/ITropicalFactory.sol';
import './TropicalPair.sol';

contract TropicalFactory is ITropicalFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(TropicalPair).creationCode));

    uint256 public constant MAX_TROPICAL_FEE = 15; // 0.15%
    uint256 public tropicalFee;

    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        tropicalFee = 15; // 0.15%
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Tropical: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Tropical: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Tropical: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(TropicalPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ITropicalPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Tropical: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Tropical: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function updateTropicalFee(uint256 _tropicalFee) external {
        require(msg.sender == feeToSetter, 'Tropical: FORBIDDEN');
        require(_tropicalFee <= MAX_TROPICAL_FEE, 'Tropical: FEE_TOO_HIGH');
        tropicalFee = _tropicalFee;
    }
}
