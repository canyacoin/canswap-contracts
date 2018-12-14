pragma solidity 0.5.0;

import "../CanSwapMath.sol";

contract CanSwapMathMock {

    function calculateSwapOutput(uint256 _balFrom, uint256 _balTo, uint256 _value)
    public
    pure
    returns (uint256 output, uint256 emission, uint256 liqFee) {        
        return CanSwapMath.calculateSwapOutput(_balFrom, _balTo, _value);
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
