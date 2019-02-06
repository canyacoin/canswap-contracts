pragma solidity ^0.5.1;

import "./ERC20.sol";

contract ERC20DetailedMock is ERC20, ERC20Detailed {
    constructor (string memory name, string memory symbol, uint8 decimals, uint256 initialBalance, address initialOwner) 
    ERC20Detailed(name, symbol, decimals) public {
        _mint(initialOwner, initialBalance);
    }
}
