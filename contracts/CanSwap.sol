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
        uint128 balTKN;
        uint128 balCAN;
    }

    struct PoolStake {
        uint128 stakeTKN;
        uint128 stakeCAN;
    }

    struct PoolFees {
        uint128 feeTKN;
        uint128 feeCAN;
    }

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
        require(mapPoolStatus[_token].active, "Pool must be active");
        _;
    }

    /**
     * @dev Create a liquidity pool paired with CAN and perform initial stake
     */
    function createPoolForToken(address _token, string calldata _uri, string calldata _api, 
    uint128 _amountTkn, uint128 _amountCan) external payable {
        require(mapPoolStatus[_token].exists == false, "Pool must not exist");
        
        // Handle stakes, pool share, etc
        mapIndexToPool[poolCount] = _token;
        mapPoolDetails[_token] = PoolDetails(_uri, _api);
        mapPoolStatus[_token] = PoolStatus(true, true, false);
        mapPoolFees[_token] = PoolFees(0, 0);
        poolCount += 1;

        require(stakeInPool(_token, _amountTkn, _amountCan), "Stake must be successful");
    }

    /**
     * @dev Perform stake in pool
     */
    function stakeInPool(address _token, uint128 _amountTkn, uint128 _amountCan) public 
    payable
    poolIsActive(_token) 
    returns (bool success) {
        require(_amountTkn > 0, "Pool must receive initial TKN stake");
        require(_amountCan > 0, "Pool must receive initial CAN stake");
        
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
        

        return true;
    }
}