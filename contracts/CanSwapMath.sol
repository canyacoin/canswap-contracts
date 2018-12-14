pragma solidity 0.5.1;

import "./SafeMath.sol";

library CanSwapMath {

    using SafeMath for uint256;

    /**
     * @dev Internal swap calculation
     * @param _balFrom Balance of token to swap from
     * @param _balTo Balance of token to swap to
     * @param _value Amount of _from token used as deposit
     * @return uint256 Total output from swap
     * @return uint256 Emission from the swap
     * @return uint256 Liquidity fee to subtract from output
     */
    function calculateSwapOutput(uint256 _balFrom, uint256 _balTo, uint256 _value)
    public
    pure
    returns (uint256 output, uint256 emission, uint256 liqFee) {        
        output = getOutput(_value, _balFrom, _balTo);
        liqFee = getLiqFee(_value, _balFrom, _balTo);
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
        uint256 numerator = (_input.mul(_input)).mul(_outputBal);
        uint256 denom = _input.add(_inputBal);
        denom = denom.mul(denom);
        return numerator.div(denom);
    }
}