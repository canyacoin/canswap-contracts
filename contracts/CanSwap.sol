pragma solidity 0.5.0;

import "./Ownable.sol";

/** @title Required standard ERC20 token interface */
contract ERC20 {
    function transferFrom (address _from, address _to, uint256 _value) public returns (bool success);
    function transfer (address _to, uint256 _value) public returns (bool success);
}

/**
 * @title CanSwap liquidity pool
 * @dev 
 */
contract CanSwap is Ownable {

    /**
     * @dev 
     */
    constructor () public {
    }
}