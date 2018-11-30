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

    struct PoolBalances {
        uint128 balTKN;
        uint128 balCAN;
    }

    struct PoolFees {
        uint128 feeTKN;
        uint128 feeCAN;
    }

    ERC20 public CAN;

    uint8 public poolCount = 0;

    mapping(uint8 => address) mapIndexToPool;
    mapping(address => PoolDetails) mapPoolDetails;
    mapping(address => PoolStatus) mapPoolStatus;
    mapping(address => PoolBalances) mapPoolBalances;
    mapping(address => PoolFees) mapPoolFees; 


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
     * @dev Create a liquidity pool paired with CAN 
     * It should:
     */
    function createPoolForToken(address _token, string calldata _uri, string calldata _api, 
    uint128 _amountTkn, uint128 _amountCan) external payable {
        require(mapPoolStatus[_token].exists == false, "Pool must not exist");
        require(_amountTkn > 0, "Pool must receive initial TKN stake");
        require(_amountCan > 0, "Pool must receive initial CAN stake");
        
        // Handle ETH? ETHToken, second function, if block
        ERC20 token = ERC20(_token);                                          
        require(token.transferFrom(msg.sender, address(this), _amountTkn), "Must be able to transfer tokens from pool creator to pool");           
        require(CAN.transferFrom(msg.sender, address(this), _amountCan), "Must be able to transfer CAN from pool creator to pool");             
        
        // Handle stakes, pool share, etc

        mapIndexToPool[poolCount] = _token;
        mapPoolDetails[_token] = PoolDetails(_uri, _api);
        mapPoolBalances[_token] = PoolBalances(_amountTkn, _amountCan);
        mapPoolFees[_token] = PoolFees(0, 0);
        poolCount += 1;

    }
}