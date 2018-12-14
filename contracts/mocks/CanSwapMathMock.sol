pragma solidity 0.5.1;

import "../CanSwapMath.sol";

contract CanSwapMathMock {

    function calculateSwapOutput(uint256 _input, uint256 _inputBal, uint256 _outputBal)
    public
    pure
    returns (uint256 output, uint256 emission, uint256 liqFee) {        
        return CanSwapMath.calculateSwapOutput(_input, _inputBal, _outputBal);
    }
    

    function getOutput(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    public 
    pure 
    returns (uint256) {
        return CanSwapMath.getOutput(_input, _inputBal, _outputBal);
    }

    function getLiqFee(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    public 
    pure 
    returns (uint256) {
        return CanSwapMath.getLiqFee(_input, _inputBal, _outputBal);
    }
}
