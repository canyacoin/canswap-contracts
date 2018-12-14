pragma solidity 0.5.1;

import "./SafeMath.sol";

library CanSwapMath {

    using SafeMath for uint256;

    /**
     * @dev Internal swap calculation
     * @param _input Amount of _from token used as deposit
     * @param _inputBal Balance of token to swap from
     * @param _outputBal Balance of token to swap to
     * @return uint256 Total output from swap
     * @return uint256 Emission from the swap
     * @return uint256 Liquidity fee to subtract from output
     */
    function calculateSwapOutput(uint256 _input, uint256 _inputBal, uint256 _outputBal)
    public
    pure
    returns (uint256 output, uint256 emission, uint256 liqFee) {        
        output = getOutput(_input, _inputBal, _outputBal);
        liqFee = getLiqFee(_input, _inputBal, _outputBal);
        emission = output.sub(liqFee);
    }
    

    /**
     * @dev Get output of swap
     * @param _input Value of input
     * @param _inputBal Balance of input in pool
     * @param _outputBal Balance of output in pool
     * @return uint256 Output of the swap
     */ 
    function getOutput(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    public 
    pure 
    returns (uint256) {
        uint256 numerator = _input.mul(_outputBal);
        uint256 denom = _input.add(_inputBal);
        return numerator.div(denom);
    }

    /**
     * @dev Get liquidity fee from swap
     * @param _input Value of input
     * @param _inputBal Balance of input in pool
     * @param _outputBal Balance of output in pool
     * @return uint256 Liquidity fee of the swap
     */
    function getLiqFee(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    public 
    pure 
    returns (uint256) {
        uint256 numerator = _input.mul(_input);
        numerator = numerator.mul(_outputBal);
        uint256 denom = _input.add(_inputBal);
        denom = denom.mul(denom);
        return numerator.div(denom);
    }
}