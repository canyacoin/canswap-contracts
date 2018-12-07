pragma solidity 0.5.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";

/**
 * @title CanSwap liqudity pools
 * @dev Continuous liquidity pools to allow on-chain conversions of
 * tokens and ether into and out of CAN. The continuous liquidity pools are permissionless; anyone
 * can add or remove liquidity and anyone can use the pools to convert between assets
 * Satisfies requirements outlined in WhitePaper, with a number of technical compromises
 * - https://github.com/canyaio/canswap-contracts/blob/master/resources/Whitepaper.pdf
 */
contract CanSwap is Ownable {

    using SafeMath for uint256;

    /** @dev Pool meta data */
    struct PoolDetails {
        string uri;
        string api;
    }
    /** @dev Pool status */
    struct PoolStatus {
        bool exists;
        bool active;
    }
    /** @dev Current pool balance */
    struct PoolBalance {
        uint256 balTKN;
        uint256 balCAN;
    }
    /** @dev Current accrued, unallocated pool fees */
    struct PoolFees {
        uint256 feeTKN;
        uint256 feeCAN;
    }
    /** @dev A stakers stake in a pool */
    struct PoolStake {
        uint256 stakeTKN;
        uint256 stakeCAN;
    }    
    /** @dev A stakers allocated fees in a pool 
      * Rewards default to and are reset to 1 after withdrawal
      * This lets us keep the gas costs for `allocateFees` lower and consistent
      */
    struct PoolStakeRewards {
        uint256 rewardTKN;
        uint256 rewardCAN;
    }

    /** @dev Events to emit */
    event eventPoolCreated(address indexed pool, string uri, string api); 
    event eventPoolDetailsUpdated(address indexed pool, string uri, string api);
    event eventPoolMinimumStakeUpdated(address indexed pool, uint8 threshold);
    event eventPoolActivationChanged(address indexed pool, bool activated);
    event eventStakerAddedToPool(address indexed pool, address indexed staker);  
    event eventStakeAdded(address indexed pool, address indexed staker, uint256 amountTkn, uint256 amountCan);
    event eventPoolFeesDistributed(address indexed pool);
    event eventStakerWithdrawnFromPool(address indexed pool, address indexed staker);
    event eventStakerWithdrawnFeesFromPool(address indexed pool, address indexed staker);
    event eventSwapExecuted(address indexed fromToken, address indexed toToken, address swapper, address recipient, uint256 fromValue, uint256 toValue);

    /** @dev Base currency to be used across all pools */
    IERC20 public CAN;

    /** @dev Track all existing pools for use client side */
    uint16 public poolCount = 0;
    mapping(uint16 => address) mapIndexToPool;

    /** @dev Track the pool details, fees and status */
    mapping(address => PoolDetails) mapPoolDetails;
    mapping(address => PoolStatus) mapPoolStatus;
    mapping(address => PoolBalance) mapPoolBalances;
    mapping(address => PoolFees) mapPoolFees; 
    mapping(address => uint8) mapPoolMinimumStake; 

    /** @dev Track staking activity accross the pools */
    mapping(address => uint16) mapPoolStakerCount;
    mapping(address => mapping(uint16 => address payable)) mapPoolStakerAddress;
    mapping(address => mapping(address => PoolStake)) mapPoolStakes;
    mapping(address => mapping(address => PoolStakeRewards)) mapPoolStakeRewards;

    /** @dev Track individual stakers activity */
    mapping(address => uint16) mapStakerPoolCount;
    mapping(address => mapping(uint16 => address)) mapStakerPools;
    mapping(address => mapping(address => bool)) mapStakerHasStakedInPool;

    /** 
      * @dev Constructor
      * @param _canToken Address of the base token to be used across all pools
      */
    constructor (address _canToken) public {
        CAN = IERC20(_canToken);
    }

    /** 
      * @dev Modifier - requires pool to exist
      * @param _token Token address used in the pool
      */
    modifier poolExists(address _token) {
        require(mapPoolStatus[_token].exists, "Pool must exist");
        _;
    }

    /** 
      * @dev Modifier - requires pool to be active or base currency
      * @param _token Token address used in the pool
      */
    modifier poolIsActiveOrBase(address _token) {
        require(mapPoolStatus[_token].active || _token == address(CAN), "Pool must be active");
        _;
    }

    /** 
      * @dev Modifier - requires user to be a staker in the pool
      * @param _pool Token address of the pool
      * @param _staker Address of potential staker
      */
    modifier onlyActiveStaker(address _pool, address _staker) {
        require(_hasStakeInPool(_pool, _staker), "User must be staker in pool");
        _;
    }

    /** 
      * @dev Bool is staker in pool with active stakes, internal
      * @param _pool Token address of the pool
      * @param _staker Address of potential staker
      * @return bool IsStaker
      */
    function _hasStakeInPool(address _pool, address _staker)
    internal 
    view
    returns (bool) {
        return mapPoolStakes[_pool][_staker].stakeTKN > 0 || mapPoolStakes[_pool][_staker].stakeCAN > 0;
    }

    /** 
      * @dev Modifier - requires user to be creator of a pool
      * @param _pool Token address of the pool
      */
    modifier onlyCreatorOrOwner(address _pool) {
        require(mapPoolStakerAddress[_pool][0] == msg.sender || isOwner(), "User must be creator of the pool");
        _;
    }

    /**
     * @dev Create a liquidity pool paired with CAN and perform initial stake. Requires transfer approval
     * @param _token Token from which to create pool
     * @param _uri URI to associate with the token pool
     * @param _api API to associate with the token pool
     * @param _amountTkn Initial token stake
     * @param _amountCan Initial CanYaCoin stake
     */
    function createPoolForToken(address _token, string calldata _uri, string calldata _api, uint256 _amountTkn, uint256 _amountCan) 
    external 
    payable {
        require(mapPoolStatus[_token].exists == false, "Pool must not exist");
        require(_amountTkn > 0, "Must include an initial TKN stake");
        require(_amountCan > 0, "Must include an initial CAN stake");
        
        mapIndexToPool[poolCount] = _token;
        mapPoolDetails[_token] = PoolDetails(_uri, _api);
        mapPoolStatus[_token] = PoolStatus(true, true);
        mapPoolMinimumStake[_token] = 10;
        poolCount += 1;

        emit eventPoolCreated(_token, _uri, _api);

        require(stakeInPool(_token, _amountTkn, _amountCan), "Stake must be successful");
    }

    /**
     * @dev Update meta properties for a pool
     * @param _uri Updated URI to associate with the token pool
     * @param _api Updated API to associate with the token pool
     */
    function updatePoolDetails(address _pool, string calldata _uri, string calldata _api) 
    external
    poolExists(_pool)
    onlyCreatorOrOwner(_pool) {
        mapPoolDetails[_pool] = PoolDetails(_uri, _api);
        emit eventPoolDetailsUpdated(_pool, _uri, _api);
    }

    /**
     * @dev Set minimum staking threshold
     * @param _threshold Percent of prospective pool that must be staked in order to gain access
     */
    function updateMinimumStakeThreshold(address _pool, uint8 _threshold) 
    external
    poolExists(_pool)
    onlyCreatorOrOwner(_pool) {
        require(_threshold >= 0 && _threshold < 100, "Threshold must be >= 0 && < 100");
        mapPoolMinimumStake[_pool] = _threshold;
        emit eventPoolMinimumStakeUpdated(_pool, _threshold);
    }

    /**
     * @dev Activate the pool. Executed by contract owner
     * @param _pool Address of token for pool
     */
    function activatePool(address _pool) 
    external
    onlyOwner() {
        PoolStatus storage pool = mapPoolStatus[_pool];
        require(pool.exists && pool.active == false, "Pool must be inactive");
        pool.active = true;
        emit eventPoolActivationChanged(_pool, true);
    }

    /**
     * @dev De-activate the pool. Executed by contract owner
     * @param _pool Address of token for pool
     */
    function deactivatePool(address _pool) 
    external
    onlyOwner() {
        PoolStatus storage pool = mapPoolStatus[_pool];
        require(pool.exists && pool.active, "Pool must be active");
        pool.active = false;
        emit eventPoolActivationChanged(_pool, false);
    }


    /**
     * @dev Perform stake in pool. Requires transfer approval. New or returning stakers must run allocate fees
     * @param _pool Address of token for pool
     * @param _amountTkn Amount of tokens to stake
     * @param _amountCan Address of CanYaCoins to stake
     */
    function stakeInPool(address _pool, uint256 _amountTkn, uint256 _amountCan) 
    public
    payable
    poolIsActiveOrBase(_pool) 
    returns (bool success) {
        require(_amountTkn > 0 || _amountCan > 0, "Must include an actual stake");
        require(_hasStakeInPool(_pool, msg.sender) == false, "User cannot already be a staker");
        
        PoolStake memory stake = PoolStake(_amountTkn, _amountCan);
        PoolBalance memory existingBalance = mapPoolBalances[_pool];

        if(existingBalance.balTKN > 0 || existingBalance.balCAN > 0){
            PoolBalance memory prospectiveBalance = PoolBalance(existingBalance.balTKN.add(_amountTkn), existingBalance.balCAN.add(_amountCan));
            uint256 prospectivePoolShare = _calculatePoolShare(prospectiveBalance, stake);
            require(prospectivePoolShare >= mapPoolMinimumStake[_pool], "Prospective pool share must be greater than minimum threshold");
        }

        _allocateFees(_pool);
        
        _depositStakeAndUpdateBalance(_pool, _amountTkn, _amountCan);

        if(mapStakerHasStakedInPool[msg.sender][_pool] == false){
            mapPoolStakerAddress[_pool][mapPoolStakerCount[_pool]] = msg.sender;
            mapPoolStakerCount[_pool] += 1;

            mapStakerHasStakedInPool[msg.sender][_pool] = true;
            
            mapStakerPools[msg.sender][mapStakerPoolCount[msg.sender]] = _pool;
            mapStakerPoolCount[msg.sender] += 1;

            emit eventStakerAddedToPool(_pool, msg.sender);
        }

        mapPoolStakes[_pool][msg.sender] = stake;

        emit eventStakeAdded(_pool, msg.sender, _amountTkn, _amountCan);
        return true;
    }

    /**
     * @dev Add an additional stake to a pool you stake in. Requires transfer approval
     * @param _pool Address of token for pool
     * @param _amountTkn Amount of tokens to add to stake
     * @param _amountCan Address of CanYaCoins to add to stake
     * @return bool success - Success of function execution
     */
    function addStakeInPool(address _pool, uint256 _amountTkn, uint256 _amountCan) 
    public
    payable
    poolIsActiveOrBase(_pool)
    onlyActiveStaker(_pool, msg.sender) 
    returns (bool success) {
        require(_amountTkn > 0 || _amountCan > 0, "Must include an actual stake");

        _depositStakeAndUpdateBalance(_pool, _amountTkn, _amountCan);

        PoolStake storage stake = mapPoolStakes[_pool][msg.sender];
        stake.stakeTKN = stake.stakeTKN.add(_amountTkn);
        stake.stakeCAN = stake.stakeCAN.add(_amountCan);

        emit eventStakeAdded(_pool, msg.sender, _amountTkn, _amountCan);
        return true;
    }

    /**
     * @dev Execute value transfers and internally assign the stake deposits
     * @param _pool Address of token for pool
     * @param _amountTkn Amount of tokens to deposit into pool
     * @param _amountCan Address of CanYaCoins to deposit into pool
     */
    function _depositStakeAndUpdateBalance(address _pool, uint256 _amountTkn, uint256 _amountCan) 
    internal {
        if(_pool == address(0)){
            require(msg.value == _amountTkn, "Staker must send ETH stake");
        } else {
            IERC20 token = IERC20(_pool);                                          
            require(token.transferFrom(msg.sender, address(this), _amountTkn), "Must be able to transfer tokens from pool creator to pool");    
        }
        require(CAN.transferFrom(msg.sender, address(this), _amountCan), "Must be able to transfer CAN from pool creator to pool");             
        
        PoolBalance memory currentBalance = mapPoolBalances[_pool];
        mapPoolBalances[_pool] = PoolBalance(currentBalance.balTKN.add(_amountTkn), currentBalance.balCAN.add(_amountCan));
    }

    /**
     * @dev Calculate the reward msg.sender can expect from re allocating the fees
     * @param _pool Token address of the pool
     * @return uint256 rewardTKN - How much of the accumulated TKN fees the staker will get
     * @return uint256 rewardCAN - How much of the accumulated CAN fees the staker will get 
     */
    function getAllocationReward(address _pool)
    external
    view
    poolExists(_pool) 
    onlyActiveStaker(_pool, msg.sender)
    returns (uint256 rewardTKN, uint256 rewardCAN) {
        PoolFees memory poolFees = mapPoolFees[_pool];
        require(poolFees.feeTKN > 0 || poolFees.feeCAN > 0, "Pool must have some recorded fees");

        PoolBalance memory poolBalance = mapPoolBalances[_pool];   
        PoolStake memory stake = mapPoolStakes[_pool][msg.sender];
        
        return _calculateFeeShare(poolFees, poolBalance, stake);
    }

    /**
     * @dev Allocates fees accumulated in a pool to the stakers based on their pool share
     * @param _pool Token address of the pool
     */
    function allocateFees(address _pool)
    external
    poolExists(_pool) {
        PoolFees memory poolFees = mapPoolFees[_pool];
        require(poolFees.feeTKN > 0 || poolFees.feeCAN > 0, "Pool must have some recorded fees");
        PoolBalance memory poolBalance = mapPoolBalances[_pool];
        require(poolBalance.balTKN > 0 || poolBalance.balCAN > 0, "Pool must have some stakes");
        _allocateFees(_pool);
    }

    /**
     * @dev Allocates fees accumulated in a pool to the stakers based on their pool share
     * @param _pool Token address of the pool
     */
    function _allocateFees(address _pool) 
    internal
    poolExists(_pool) {

        /** TODO
            If we need to optimise this (allocate per token), we should: 
            - switch to individual mappings to avoid SLOAD costs
            - pack the structs via bitwise ops (+ optimise to uint128)
         */ 

        PoolFees memory initialPoolFees = mapPoolFees[_pool];
        mapPoolFees[_pool] = PoolFees(0, 0);

        PoolBalance memory poolBalance = mapPoolBalances[_pool];

        uint16 stakerCount = mapPoolStakerCount[_pool];
        for (uint16 i = 0; i < stakerCount; i++) {
            address staker = mapPoolStakerAddress[_pool][i];
            PoolStake memory stake = mapPoolStakes[_pool][staker];
            if(stake.stakeTKN > 0 || stake.stakeCAN > 0){
                (uint256 feeShareTKN, uint256 feeShareCAN) = _calculateFeeShare(initialPoolFees, poolBalance, stake);
                PoolStakeRewards storage stakerRewards = mapPoolStakeRewards[_pool][staker];
                uint256 rewardTKN = stakerRewards.rewardTKN.add(feeShareTKN);
                stakerRewards.rewardTKN = rewardTKN == 0 ? 1 : rewardTKN;
                uint256 rewardCAN = stakerRewards.rewardCAN.add(feeShareCAN);
                stakerRewards.rewardCAN = rewardCAN == 0 ? 1 : rewardCAN;
            }
        }

        emit eventPoolFeesDistributed(_pool);
    }

    /**
     * @dev Internally calculate the share of fees for a particular staker
     * @param _poolFees Total fees in the pool
     * @param _poolBalance Total balance of the pool
     * @param _stake Stakers portion of the pool balance
     * @return uint256 feeShareTKN - How much of the accumulated TKN fees the staker will get
     * @return uint256 feeShareCAN - How much of the accumulated CAN fees the staker will get
     */
    function _calculateFeeShare(PoolFees memory _poolFees, PoolBalance memory _poolBalance, PoolStake memory _stake)
    private
    pure
    returns (uint256 feeShareTKN, uint256 feeShareCAN) {
        uint256 poolShareAVG = _calculatePoolShare(_poolBalance, _stake);
        if(poolShareAVG == 0){
            return (0, 0);
        }

        if(_poolFees.feeTKN == 0){
            feeShareTKN = 0;
        } else {
            feeShareTKN = poolShareAVG.mul(_poolFees.feeTKN).div(100);
        }

        if(_poolFees.feeCAN == 0){
            feeShareCAN = 0;
        } else {
            feeShareCAN = poolShareAVG.mul(_poolFees.feeCAN).div(100);
        }
        return (feeShareTKN, feeShareCAN);
    }

    /**
     * @dev Internally calculate the pool share from stake
     * @param _poolBalance Total balance of the pool
     * @param _stake Stakers portion of the pool balance
     * @return uint256 - Pool share based on stake
     */
    function _calculatePoolShare(PoolBalance memory _poolBalance, PoolStake memory _stake)
    private
    pure
    returns (uint256) {
        (uint256 poolShareTKN, uint256 poolShareCAN) = (0, 0);

        if(_stake.stakeTKN >= _poolBalance.balTKN){
            poolShareTKN = 100;
        } else if(_stake.stakeTKN > 0){
            poolShareTKN = _stake.stakeTKN.mul(100).div(_poolBalance.balTKN);
        }

        if(_stake.stakeCAN >= _poolBalance.balCAN){
            poolShareCAN = 100;
        } else if(_stake.stakeCAN > 0){
            poolShareCAN = _stake.stakeCAN.mul(100).div(_poolBalance.balCAN);
        }
        return (poolShareTKN.add(poolShareCAN)).div(2);
    }

    /**
     * @dev Withdraw my stake and fees from the pool
     * @param _pool Token address of the pool
     */
    function withdrawFromPool(address _pool)
    external {
        _withdrawFromPool(_pool, msg.sender);
    }

    /**
     * @dev Withdraws a staker completely from the pool, transferring funds and resetting balances
     * @param _pool Token address of the pool
     * @param _staker Address of the staker to withd raw from pool
     */
    function _withdrawFromPool(address _pool, address payable _staker) 
    internal
    poolExists(_pool)
    onlyActiveStaker(_pool, _staker) {
        PoolStakeRewards memory stakerRewards = mapPoolStakeRewards[_pool][_staker];
        mapPoolStakeRewards[_pool][_staker] = PoolStakeRewards(1, 1);

        PoolStake memory stakerBalance = mapPoolStakes[_pool][_staker];
        mapPoolStakes[_pool][_staker] = PoolStake(0, 0);

        PoolBalance memory currentPoolBalance = mapPoolBalances[_pool];
        mapPoolBalances[_pool] = PoolBalance(currentPoolBalance.balTKN.sub(stakerBalance.stakeTKN), currentPoolBalance.balCAN.sub(stakerBalance.stakeCAN));

        uint256 totalTKN = stakerRewards.rewardTKN.add(stakerBalance.stakeTKN);
        uint256 totalCAN = stakerRewards.rewardCAN.add(stakerBalance.stakeCAN);

        _executeWithdrawal(_pool, _staker, totalTKN, totalCAN);

        emit eventStakerWithdrawnFromPool(_pool, _staker);
    }

    /**
     * @dev Withdraws an active stakers accumulated fees for a particular pool
     * @param _pool Token address of the pool
     */
    function withdrawFees(address _pool) 
    external
    poolExists(_pool)
    onlyActiveStaker(_pool, msg.sender) {
        PoolStakeRewards memory stakerRewards = mapPoolStakeRewards[_pool][msg.sender];
        require(stakerRewards.rewardTKN > 0 || stakerRewards.rewardCAN > 0, "Pool must contain rewards for the staker");
        mapPoolStakeRewards[_pool][msg.sender] = PoolStakeRewards(1, 1);
        
        _executeWithdrawal(_pool, msg.sender, stakerRewards.rewardTKN, stakerRewards.rewardCAN);

        emit eventStakerWithdrawnFeesFromPool(_pool, msg.sender);
    }

    /**
     * @dev Internal execution of releasing funds to the staker
     * @param _pool Token address of the pool
     * @param _recipient Address to which to send the funds
     * @param _amountTKN Token amount to be sent
     * @param _amountCAN CAN amount to be sent
     */
    function _executeWithdrawal(address _pool, address payable _recipient, uint256 _amountTKN, uint256 _amountCAN)
    private {
        if(_amountTKN > 0){  
            if(_pool == address(0)){
                require(address(this).balance >= _amountTKN, "Pool has insufficient ETH balance to transfer to user");
                (_recipient).transfer(_amountTKN);
            } else {
                IERC20 token = IERC20(_pool);                                          
                require(token.transfer(_recipient, _amountTKN), "Pool has insufficient TKN balance to transfer to user");    
            }
        }

        if(_amountCAN > 0){
            require(CAN.transfer(_recipient, _amountCAN), "Pool has insufficient CAN to transfer to staker");
        }
    }

    /**
     * @dev Perform swap and return funds to sender
     * @param _from Token to swap from
     * @param _to Token the user will receive as output
     * @param _value Amount of _from token used as deposit
     */
    function swap(address _from, address _to, uint256 _value) 
    public 
    payable {
        _swapAndSend(_from, _to, _value, msg.sender);
    }
        
    /**
     * @dev Perform swap and return funds to recipient
     * @param _from Token to swap from
     * @param _to Token the user will receive as output
     * @param _value Amount of _from token used as deposit
     * @param _recipient Address that the output funds will be sent to
     */
    function swapAndSend(address _from, address _to, uint256 _value, address payable _recipient) 
    public 
    payable {
        require(_recipient != address(0), "Recipient must be non empty address");
        _swapAndSend(_from, _to, _value, _recipient);
    }
    
    /**
     * @dev Internal swap and transfer function
     * @param _from Token to swap from
     * @param _to Token the user will receive as output
     * @param _value Amount of _from token used as deposit
     * @param _recipient Address that the output funds will be sent to
     * @return bool Success of the swap
     */
    function _swapAndSend(address _from, address _to, uint256 _value, address payable _recipient) 
    private
    poolIsActiveOrBase(_from)
    poolIsActiveOrBase(_to) {        
        require(_value > 0, "Must be attempting to swap a non zero amount of tokens");

        if(_from == address(0)){
            require(msg.value == _value, "Sender must send ETH as payment");
        } else {
            IERC20 token = IERC20(_from);                                        
            require(token.transferFrom(msg.sender, address(this), _value), "Sender must have approved the TKN transfer");
        }

        uint256 swapEmission;

        if(_from == address(CAN) || _to == address(CAN)){
            swapEmission = _executeSwap(_from, _to, _value);
        } else {
            uint256 initialswapEmission = _executeSwap(_from, address(CAN), _value);
            swapEmission = _executeSwap(address(CAN), _to, initialswapEmission);
        }

        require(swapEmission > 0, "Must be some swap output");

        if(_to == address(0)) {
            require(address(this).balance >= swapEmission, "Contract must have enough ETH to pay recipient");
            _recipient.transfer(swapEmission);
        }else {
            IERC20 outputToken = IERC20(_to);
            require(outputToken.transfer(_recipient, swapEmission), "Contract must release tokens to recipient");
        }

        emit eventSwapExecuted(_from, _to, msg.sender, _recipient, _value, swapEmission);
    }

    /**
     * @dev Internal swap execution
     * @param _from Token to swap from
     * @param _to Token the user will receive as output
     * @param _value Amount of _from token used as deposit
     * @return uint256 Amount of tokens to emit from the swap
     */
    function _executeSwap(address _from, address _to, uint256 _value)
    private
    returns (uint256 tokensToEmit) {
        bool fromCan = _from == address(CAN);
        address poolId = fromCan ? _to : _from;

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
     * @param _input Value of input
     * @param _inputBal Balance of input in pool
     * @param _outputBal Balance of output in pool
     * @return uint256 Output of the swap
     */
    function _getOutput(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    private 
    pure 
    returns (uint256 outPut) {
        uint256 numerator = (_input.mul(_outputBal)).mul(_inputBal);
        uint256 denom = _input.add(_inputBal);
        denom = denom.mul(denom);
        return numerator.div(denom);
    }

    /**
     * @dev Get liquidity fee from swap
     * @param _input Value of input
     * @param _inputBal Balance of input in pool
     * @param _outputBal Balance of output in pool
     * @return uint256 Liquidity fee of the swap
     */
    function _getLiqFee(uint256 _input, uint256 _inputBal, uint256 _outputBal) 
    private 
    pure 
    returns (uint256 liqFee) {
        uint256 numerator = (_input.mul(_input)).mul(_outputBal);
        uint256 denom = _input.add(_inputBal);
        denom = denom.mul(denom);
        return numerator.div(denom);
    }

    /**
     * @dev Internal func to get balance of one side of pool
     * @param _pool Token address of the pool
     * @param _base Bool - get base currency balance (CAN)?
     * @return uint256 Balance on this side of the pool
     */
    function _getPoolBalance(address _pool, bool _base)
    private
    view
    returns (uint256 _balance) {
        return _base ? mapPoolBalances[_pool].balCAN : mapPoolBalances[_pool].balTKN;
    }


    /**
     * @dev Get pool details for use on client
     * @param _pool Token address of the pool
     * @return string uri - Pool URI
     * @return string api - Pool API
     * @return bool active - Is pool currently active? 
     * @return uint256 balTKN - Balance on TKN side of pool
     * @return uint256 balCAN - Balance on CAN side of pool
     * @return uint256 feeTKN - Unallocated fees on TKN side 
     * @return uint256 feeCAN - Unallocated fees on CAN side
     */
    function getPool(address _pool)
    external
    view
    poolExists(_pool)
    returns (
        string memory uri,
        string memory api,
        bool active,
        uint256 balTKN,
        uint256 balCAN,
        uint256 feeTKN,
        uint256 feeCAN
    ) {
        PoolDetails memory details = mapPoolDetails[_pool];
        PoolStatus memory status = mapPoolStatus[_pool];
        PoolBalance memory balance = mapPoolBalances[_pool];
        PoolFees memory fees = mapPoolFees[_pool];
        return (details.uri, details.api, status.active, balance.balTKN, balance.balCAN, fees.feeTKN, fees.feeCAN); 
    }

    /**
     * @dev Get a list of pools the staker is associated with
     * @param _staker Staker address
     * @return address[] Pool addresses
     */
    function getStakersPools(address _staker)
    external
    view
    returns (address[] memory pools) {
        uint16 stakerPoolCount = mapStakerPoolCount[_staker];
        pools = new address[](stakerPoolCount);
        for(uint16 i = 0; i < stakerPoolCount; i++){
            pools[i] = mapStakerPools[_staker][i];
        }
        return pools;
    }

    /**
     * @dev Get stakers stake in a particular pool
     * @param _pool Token address of the pool
     * @param _staker Staker address
     * @return uint256 Stake in TKN side of pool
     * @return uint256 Stake in CAN side of pool
     * @return uint256 Rewards allocated in TKN side of pool
     * @return uint256 Rewards allocated in CAN side of pool
     */
    function getStakersStake(address _pool, address _staker)
    external
    view
    onlyActiveStaker(_pool, _staker)
    returns (
        uint256 stakeTKN,
        uint256 stakeCAN,
        uint256 rewardTKN,
        uint256 rewardCAN
    ) {
        PoolStake memory stake = mapPoolStakes[_pool][_staker];
        PoolStakeRewards memory rewards = mapPoolStakeRewards[_pool][_staker];
        if(rewards.rewardTKN >= 1) {
            rewards.rewardTKN.sub(1);
        }
        if(rewards.rewardCAN >= 1){
            rewards.rewardCAN.sub(1);
        }
        return (stake.stakeTKN, stake.stakeCAN, rewards.rewardTKN, rewards.rewardCAN);
    }
}

