pragma solidity 0.5.1;

contract TestHelper {

    
    // A little utility that runs a wrapped method invocation as an internal Solidity call
    // Returns true if the underlying call succeeds and false if it throws.
    function execute(string memory signature) public returns (bool){
        bytes4 sig = bytes4(keccak256(abi.encodePacked(signature)));
        address self = address(this);
        (bool success, bytes memory data) = self.call(abi.encode(sig));
        return success;
    }
}