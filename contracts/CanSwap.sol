pragma solidity 0.5.0;

import "./Ownable.sol";
import "./SafeMath.sol";

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

    using SafeMath for uint256;

    struct PoolDetails {
        string uri;
        string api;
    }

    struct PoolStatus {
        bool exists;
        bool active;
        bool blacklisted;
    }

    struct PoolBalance {
        uint256 balTKN;
        uint256 balCAN;
    }

    struct PoolStake {
        uint256 stakeTKN;
        uint256 stakeCAN;
    }
    
    struct PoolStakeRewards {
        uint256 rewardTKN;
        uint256 rewardCAN;
    }

    struct PoolFees {
        uint256 feeTKN;
        uint256 feeCAN;
    }

    event eventCreatedPool(address indexed token, string uri, string api); 
    event eventStake(address indexed token, uint256 amountTkn, uint256 amountCan);  
    

    ERC20 public CAN;

    uint16 public poolCount = 0;
    mapping(uint16 => address) mapIndexToPool;

    mapping(address => PoolDetails) mapPoolDetails;
    mapping(address => PoolStatus) mapPoolStatus;
    mapping(address => PoolBalance) mapPoolBalances;
    mapping(address => PoolFees) mapPoolFees; 

    mapping(address => uint16) mapPoolStakerCount;
    mapping(address => mapping(uint16 => address)) mapPoolStakerAddress;
    mapping(address => mapping(address => PoolStake)) mapPoolStakes;
    mapping(address => mapping(address => PoolStakeRewards)) mapPoolStakeRewards;


    constructor (address _canToken) public {
        CAN = ERC20(_canToken);
    }

    /** 
      * @dev Modifier - requires pool to exist
      */
    modifier poolExists(address _token) {
        require(mapPoolStatus[_token].exists, "Pool must exist");
        _;
    }

    /** 
      * @dev Modifier - requires pool to be active
      */
    modifier poolIsActive(address _token) {
        require(mapPoolStatus[_token].active || _token == address(CAN), "Pool must be active");
        _;
    }

    /** 
      * @dev Modifier - requires user to be a staker in the pool
      */
    modifier onlyStaker(address _pool) {
        require(mapPoolStakes[_pool][msg.sender].stakeTKN > 0 || mapPoolStakes[_pool][msg.sender].stakeCAN > 0, "User must be staker in pool");
        _;
    }

    /** 
      * @dev Modifier - requires user to be creator of a pool
      */
    modifier onlyCreator(address _pool) {
        require(mapPoolStakerAddress[_pool][0] == msg.sender, "User must be creator of the pool");
        _;
    }

    /**
     * @dev Create a liquidity pool paired with CAN and perform initial stake
     */
    function createPoolForToken(address _token, string calldata _uri, string calldata _api, 
    uint256 _amountTkn, uint256 _amountCan) 
    external 
    payable {
        require(mapPoolStatus[_token].exists == false, "Pool must not exist");
        
        mapIndexToPool[poolCount] = _token;
        mapPoolDetails[_token] = PoolDetails(_uri, _api);
        mapPoolStatus[_token] = PoolStatus(true, true, false);
        poolCount += 1;
        emit eventCreatedPool(_token, _uri, _api);

        require(stakeInPool(_token, _amountTkn, _amountCan), "Stake must be successful");
    }

    /**
     * @dev Perform stake in pool
     */
    function stakeInPool(address _token, uint256 _amountTkn, uint256 _amountCan) 
    public
    payable
    poolIsActive(_token) 
    returns (bool success) {
        require(_amountTkn > 0, "Pool must receive initial TKN stake");
        require(_amountCan > 0, "Pool must receive initial CAN stake");

        /** TODO
            Implement pool staker upper limit (due to gas cost of allocateFees)
         */ 
        
        if(_token == address(0)){
            require(msg.value == _amountTkn, "Pool creator must send ETH stake");
        } else {
            ERC20 token = ERC20(_token);                                          
            require(token.transferFrom(msg.sender, address(this), _amountTkn), "Must be able to transfer tokens from pool creator to pool");    
        }
        require(CAN.transferFrom(msg.sender, address(this), _amountCan), "Must be able to transfer CAN from pool creator to pool");             
        
        PoolBalance memory currentBalance = mapPoolBalances[_token];
        mapPoolBalances[_token] = PoolBalance(currentBalance.balTKN += _amountTkn, currentBalance.balCAN += _amountCan);
        
        mapPoolStakerAddress[_token][mapPoolStakerCount[_token]] = msg.sender;
        mapPoolStakerCount[_token] += 1;
        mapPoolStakes[_token][msg.sender] = PoolStake(_amountTkn, _amountCan);
        
        emit eventStake(_token, _amountTkn, _amountCan);
        return true;
    }

    /**
     * @dev Allocates fees accumulated in a pool to the stakers based on their pool share
     */
    function allocateFees(address _pool) 
    public
    poolIsActive(_pool) {

        /** TODO
            If we need to optimise this (allocate per token), we should also change 
            architecture to individual mappings to avoid SLOAD costs
         */

        require(_pool != address(CAN), "Ambiguous pool address");

        PoolFees memory initialPoolFees = mapPoolFees[_pool];
        require(initialPoolFees.feeTKN > 0 || initialPoolFees.feeCAN > 0, "Pool must have some recorded fees");
        mapPoolFees[_pool] = PoolFees(0, 0);

        PoolBalance memory poolBalance = mapPoolBalances[_pool];        

        uint16 stakerCount = mapPoolStakerCount[_pool];
        for (uint16 i = 0; i < stakerCount; i++) {
            address staker = mapPoolStakerAddress[_pool][i];
            PoolStake memory stake = mapPoolStakes[_pool][staker];
            if(stake.stakeTKN > 0 || stake.stakeCAN > 0){
                uint256 poolShareTKN = stake.stakeTKN.div(poolBalance.balTKN);
                uint256 poolShareCAN = stake.stakeCAN.div(poolBalance.balCAN);
                uint256 poolShareAVG = (poolShareTKN.add(poolShareCAN)).div(2);
                uint256 feeShareTKN = poolShareAVG * initialPoolFees.feeTKN;
                uint256 feeShareCAN = poolShareAVG * initialPoolFees.feeCAN;
            
                PoolStakeRewards storage stakerRewards = mapPoolStakeRewards[_pool][staker];
                stakerRewards.rewardTKN += feeShareTKN;
                stakerRewards.rewardCAN += feeShareCAN;
            }
        }
    }

    /**
     * @dev Withdraws a staker completely from the pool
     */
    function withdrawFromPool(address _pool) 
    external
    poolIsActive(_pool)
    onlyStaker(_pool) {
        PoolStakeRewards memory stakerRewards = mapPoolStakeRewards[_pool][msg.sender];
        mapPoolStakeRewards[_pool][msg.sender] = PoolStakeRewards(0, 0);

        PoolStake memory stakerBalance = mapPoolStakes[_pool][msg.sender];
        mapPoolStakes[_pool][msg.sender] = PoolStake(0, 0);
        
        uint256 totalTKN = stakerRewards.rewardTKN.add(stakerBalance.stakeTKN);
        uint256 totalCAN = stakerRewards.rewardCAN.add(stakerBalance.stakeCAN);

        if(_pool == address(0)){
            require(address(this).balance >= totalTKN, "Pool has insufficient ETH balance to transfer to user");
            (msg.sender).transfer(totalTKN);
        } else {
            ERC20 token = ERC20(_pool);                                          
            require(token.transfer(msg.sender, totalTKN), "Pool has insufficient TKN balance to transfer to user");    
        }

        require(CAN.transfer(msg.sender, totalCAN), "Pool has insufficient CAN to transfer to staker");
    }

    /**
     * @dev Withdraws a stakers accumulated fees for a particular pool
     */
    function withdrawFees(address _pool) 
    external
    poolIsActive(_pool)
    onlyStaker(_pool) {
        PoolStakeRewards memory stakerRewards = mapPoolStakeRewards[_pool][msg.sender];
        require(stakerRewards.rewardTKN > 0 || stakerRewards.rewardCAN > 0, "Pool must contain rewards for the staker");
        mapPoolStakeRewards[_pool][msg.sender] = PoolStakeRewards(0, 0);
        
        if(_pool == address(0)){
            require(address(this).balance >= stakerRewards.rewardTKN, "Pool has insufficient ETH balance to transfer to user");
            (msg.sender).transfer(stakerRewards.rewardTKN);
        } else {
            ERC20 token = ERC20(_pool);                                          
            require(token.transfer(msg.sender, stakerRewards.rewardTKN), "Pool has insufficient TKN balance to transfer to user");    
        }

        require(CAN.transfer(msg.sender, stakerRewards.rewardCAN), "Pool has insufficient CAN to transfer to staker");
    }

    /**
     * @dev Perform swap and return funds to sender
     */
    function swap(address _from, address _to, uint256 _value) 
    public 
    payable {
        _swapAndSend(_from, _to, _value, msg.sender);
    }
        
    /**
     * @dev Perform swap and return funds to recipient
     */
    function swapAndSend(address _from, address _to, uint256 _value, address payable _recipient) 
    public 
    payable {
        require(_recipient != address(0), "Recipient must be non empty address");
        _swapAndSend(_from, _to, _value, _recipient);
    }
    
    /**
     * @dev Internal swap and transfer function
     */
    function _swapAndSend(address _from, address _to, uint256 _value, address payable _recipient) 
    private
    poolIsActive(_from)
    poolIsActive(_to)
    returns (bool success) {        
        require(_value > 0, "Must be attempting to swap a non zero amount of tokens");

        if(_from == address(0)){
            require(msg.value == _value);                    
        } else {
            ERC20 token = ERC20(_from);                                        
            require(token.transferFrom(msg.sender, address(this), _value));
        }

        uint256 swapOutput;

        if(_from == address(CAN) || _to == address(CAN)){
            swapOutput = _executeSwap(_from, _to, _value);
        } else {
            uint256 initialSwapOutput = _executeSwap(_from, address(CAN), _value);
            swapOutput = _executeSwap(address(CAN), _to, initialSwapOutput);
        }

        require(swapOutput > 0, "Must be some swap output");

        if(_to == address(0)) {
            require(address(this).balance >= swapOutput, "Contract must have enough ETH to pay recipient");
            _recipient.transfer(swapOutput);
        }else {
            ERC20 outputToken = ERC20(_to);
            require(outputToken.transfer(_recipient, swapOutput), "Contract must release tokens to recipient");
        }

        return true;
    }

    /**
     * @dev Internal swap execution
     */
    function _executeSwap(address _from, address _to, uint256 _value)
    private
    returns (uint256 tokensToEmit)
    {
        bool fromCan = _from == address(CAN);
        address poolId = fromCan ? _to : _from;
        if(fromCan){
            require(mapPoolBalances[poolId].balCAN > _value, "Pool must have adequate CAN liquidity");
        } else {
            require(mapPoolBalances[poolId].balTKN > _value, "Pool must have adequate TKN liquidity");
        }

        uint256 balFrom = _getPoolBalance(_from, fromCan);
        uint256 balTo = _getPoolBalance(_to, !fromCan);
        
        uint256 output = _getOutput(_value, balFrom, balTo);
        uint256 liqFee = _getLiqFee(_value, balFrom, balTo);

        if(fromCan){
            mapPoolBalances[poolId].balCAN = mapPoolBalances[poolId].balCAN.add(_value);
            mapPoolBalances[poolId].balTKN = mapPoolBalances[poolId].balTKN.sub(output);
            mapPoolFees[poolId].feeTKN = mapPoolFees[poolId].feeTKN.add(liqFee);
        } else {
            mapPoolBalances[poolId].balTKN = mapPoolBalances[poolId].balTKN.add(_value);
            mapPoolBalances[poolId].balCAN = mapPoolBalances[poolId].balCAN.sub(output);
            mapPoolFees[poolId].feeCAN = mapPoolFees[poolId].feeCAN.add(liqFee);
        }
        
        return output.sub(liqFee);
    }

    /**
     * @dev Get output of swap
     */
    function _getOutput(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    private 
    pure 
    returns (uint256 outPut){
        uint256 numerator = (_input.mul(_outputBal)).mul(_inputBal);
        uint256 denom = _input.add(_inputBal);
        denom = denom.mul(denom);
        return numerator.div(denom);
    }

    /**
     * @dev Get liquidity fee from swap
     */
    function _getLiqFee(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    private 
    pure 
    returns (uint256 liqFee){
        uint256 numerator = (_input.mul(_input)).mul(_outputBal);
        uint256 denom = _input.add(_inputBal);
        denom = denom.mul(denom);
        return numerator.div(denom);
    }

    /**
     * @dev Get balance of pool
     */
    function _getPoolBalance(address _pool, bool _base)
    private
    view
    returns (uint256 _balance)
    {
        return _base ? mapPoolBalances[_pool].balCAN : mapPoolBalances[_pool].balTKN;
    }
}
