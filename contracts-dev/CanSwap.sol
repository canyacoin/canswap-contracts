pragma solidity 0.5.0;

// CanYaCoinToken Functions used in this contract
contract ERC20 {
  function transferFrom (address _from, address _to, uint256 _value) public returns (bool success);
  function transfer (address _to, uint256 _value) public returns (bool success);
}

// ERC223
interface ContractReceiver {
  function tokenFallback( address from, uint value, bytes calldata ) external;
}

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;
    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
  
}

// Owned Contract
contract Owned {
  modifier onlyOwner { require(msg.sender == owner); _; }
  address public owner = msg.sender;
  event NewOwner(address indexed old, address indexed current);
  function setOwner(address _new) onlyOwner public { emit NewOwner(owner, _new); owner = _new; }
}


// AssetSplit Contract
contract CanSwap is Owned {
    
    using SafeMath for uint256;

    // Public Variables
    address public addrCAN;
    uint256 public intPools;
    uint256 public intStakers;
    uint256 public bal_CAN;
    uint256 public fee_CAN;
  
    ERC20 public CAN20;
  
    // Arrays 
    address[] public arrayTokens;     // Array of Token Addresses in all Pools
    uint256[] public arrayCANBal;     // Array of CAN Balances in each Pool
    uint256[] public arrayTKNBal;     // Array of Token Balances in each Pool
    address[][] public nArrayStakes;  // Nested Array of Stakers for each Pool
    address[][] public nArrayPools;   // Nested Array of Pools for each Staker
  
    // Events
    event eventTokenEmitted(address indexed token, address indexed dest, uint256 valueTKN, uint256 liqFee);
    event eventTokenEmittedDouble(address indexed token1, address indexed token2, 
                                address indexed dest, uint256 TKN1, uint256 liqFee1, 
                                uint256 TKN2, uint256 liqFee2);
    event eventUpdatedPoolsBals(address indexed token, uint256 valueCAN, uint256 valueTKN);
    event eventUpdatedPoolsFees(address indexed token, uint256 valueCANFee, uint256 valueTKNFee);
    event eventCreatedPool(address indexed token, uint256 valueCAN, uint256 valueTKN); 
    event eventStake(address indexed token, uint256 valueCAN, uint256 valueTKN, uint256 stakeAve);  
    event eventWithdraw(address indexed token, uint256 valueCAN, uint256 valueTKN);  
    event eventFeesDistributed(address indexed token, uint256 totalCANFees, uint256 totalTKNFees); 
    event eventFeesDistributedTo(address indexed staker, uint256 CANFees, uint256 TKNFees); 
    
    // Mapping
    mapping(address => uint256) TKNBalances_;                   // Map TKNbalances
    mapping(address => uint256) CANBalances_;                   // Map CANbalances
    mapping(address => uint256) TKNFees_;                       // Map TKNFeebalances
    mapping(address => uint256) CANFees_;                       // Map CANFeebalances
    
    mapping(address => bool) isStaker_;                         // Map if Staking (yes/no)
    mapping(address => bool) isPool_;                           // Map if Pool (yes/no)
    mapping(address => bool) isBlacklisted_;                    // Map if TokenBlacklisted (yes/no)
    mapping(address => bool) isActivated_;                      // Map if Pool Activated (yes/no)

    mapping(uint256 => address) mapIndexPool_;                   // Returns the address for index
    mapping(address => uint256) mapPoolIndex_;                   // Returns the index for address

    mapping(uint256 => address) mapIndexStaker_;                 // Returns the staker from index
    mapping(address => uint256) mapStakerIndex_;                 // Returns the index for staker

    mapping(address => mapping(address => uint256)) mapStakerPoolShares_;   // Returns the unique Shares of a Pool for a staker
    mapping(address => mapping(address => uint256)) mapPoolStakerShares_;   // Returns the unique Shares of Stakers in each pool

    mapping(address => uint256) mapStakerStakes_;                           // Returns the number of unique pools a staker is in
    mapping(address => mapping(uint256 => address)) mapStakerStakesPool_;   // Returns the pools for each Staker
    mapping(address => uint256) mapTotalStakes_;                           // Returns the total staked for each pool

    mapping(address => uint256) mapPoolStakers_;                            // Returns the number of unique stakers in a pool
    mapping(address => mapping(uint256 => address)) mapPoolStakersStaker_;  // Returns the stakers at each index for each pool 
    mapping(address => mapping(address => bool)) mapIfStakinginPool_;       // Map if a staker is already in a pool
    
    // Mapping for token resources
    mapping(address => string) internal poolURIs_;          // Map the poolURIs to each pool
    mapping(address => string) internal poolAPIs_;          // Map the poolAPIs to each pool   
    
  
  // Construct the contract as well as the first pool (ether) 
  constructor (address _addrCAN) public {
        CAN20 = ERC20(_addrCAN);
        addrCAN = _addrCAN;
        intPools = 0;
        bal_CAN = 0;
        fee_CAN = 0;
  }
  
    // CreateEtherPool
  function createEtherPool(uint256 _c, uint256 _e) onlyOwner public payable {
        require(msg.value == _e);                                       // Enforce ether tfr = value
        require(CAN20.transferFrom(msg.sender, address(this), _c));     // TransferIn CAN
        _createThisPool(address(0), "etherLogoURL", "etherPriceAPI", _c, _e);
  }
  
    // Definition of onlyStaker modifier
    modifier onlyStaker { 
        isStaker_[msg.sender] = true;
        _; 
    }
  
  
  // Interface Functions
  // The following functions are what users interact with to write to the contract

 
  // Swap Function
  function swap(address _from, address _to, uint256 _value) public payable {
    _swapAndSend(_from, _to, _value, msg.sender);
  }
      
  // Swap and Send Function
  function swapAndSend(address _from, address _to, uint256 _value, address payable _dest) public payable {
    _swapAndSend(_from, _to, _value, _dest);
  }
 
  // Swap and Send Internal
  function _swapAndSend(address _from, address _to, uint256 _value, address payable _dest) internal {
      
          // UserInput Validations
    require(isActivated_[_from] == true);
    require(isActivated_[_to] == true);
    require(_value > 0);
    require(_dest != address(0));

        // Determine if not ether (from or to address is not 0x0)
      if(_from != address(0)){
          if(_to != address(0)){
            ERC20 token20 = ERC20(_from);                                         // Create ERC20 instance
            require(token20.transferFrom(msg.sender, address(this), _value));     // TransferIn
            _swapFunction(_from, _to, _value, _dest, false);
          }
          return;
      } else {
        require(msg.value == _value);                       // Enforce ether tfr = value
        _swapFunction(_from, _to, _value, _dest, true);
      } 
  }
 
  
    // CreatePool
  function createPool(address _token, string memory _URI, string memory _API, uint256 _c, uint256 _t) public {
      
      // User Input Validation
      require(isPool_[_token] == false);
      require(_c > 0);
      require(_t > 0);
      
      ERC20 token20 = ERC20(_token);                                          // Create ERC20 instance
      require(token20.transferFrom(msg.sender, address(this), _t));           // TransferIn tokens
      require(CAN20.transferFrom(msg.sender, address(this), _c));             // TransferIn CAN
      
      isPool_[_token] = true;
      _createThisPool(_token, _URI, _API, _c, _t);
  }
  

  
    // UpdatePool
  function updatePool(address _token, string memory _URI, string memory _API) public returns (bool success) {
      require(isPool_[_token] == true);
      _updateThisPool(_token, _URI, _API);
      return true;
  }
  
    // Stake In
  function stakePool(address _token, uint256 _c, uint256 _t) public returns (bool success) {

      require(isPool_[_token] = true);      // Only for an existing pool
      
      // It's ok to stake in with 0 on one side
      if (_t != 0){
      ERC20 token20 = ERC20(_token);                                          // Create ERC20 instance
      require(token20.transferFrom(msg.sender, address(this), _t));           // TransferIn tokens
      }
      if (_c != 0{
      require(CAN20.transferFrom(msg.sender, address(this), _c));             // TransferIn CAN
      } 
      
      _checkStakers(_token);                // Check stakers 
      _stakeInThisPool(_token, _c, _t);     // Stake
      bal_CAN += _c;                        // Add to global balance
     
      return true;
  }  
  
      // Stake Out
  function withdrawAll(address _token) public returns (bool success) {
      require(isPool_[_token] == true);
      require(mapIfStakinginPool_[_token][msg.sender] == true);      
      _withdrawAllFromThisPool(_token);
      return true;
  } 
  
    // DistributeFees
  function distributeFees(address _token) public returns (bool success) {
      require(isPool_[_token] == true);
      _distributeFeesForPool(_token);
      return true;
  } 
  
    // Owner can Settle Pool by distibuting all shares for each staker and de-activating pool 
    // Owner should then call distributeFees
  function settlePool (address _token) public onlyOwner {
      require(isPool_[_token] == true);
      isActivated_[_token] = false;
      //_settleThisPool(_token);
  } 
  
    // Any staker can blacklist a token
  function blacklistToken(address _token) public onlyStaker {
      require(isPool_[_token] == true);      
      isBlacklisted_[_token] = true;
  } 

  // Any staker can whitelist a token
  function whitelistToken(address _token) public onlyStaker {
      require(isPool_[_token] == true);
      isBlacklisted_[_token] = false;
  } 
  
  function deactivatePool(address _token) public onlyOwner{
      require(isPool_[_token] == true);
      isActivated_[_token] = false;
  }
  
  // Readonly Functions
  //
  // 
  
    // Returns Balances for Pool
    function balances() public pure returns (uint256[] memory _balances) {
     // _balances[0] = _getCANBalance(_token);
     //  _balances[1] = _getBalance(_token);       
        return _balances;
    }
  
    // Returns Pool Price (in CAN)
    function price(address _token) public view returns (uint256 _price) {
        uint256 _CAN = _getCANBalance(_token);
        uint256 _TKN = _getBalance(_token);
        _price = _CAN.div(_TKN);
        return _price;
    } 
    
    // Returns Fees for Pool
    function fees(address _token) public view returns (uint256[] memory _fees) {
       _fees[0] = _getCANFee(_token);
       _fees[1] = _getFee(_token);       
        return _fees;
    }

    // Returns Stakers Share of Pool
    function share(address _token, address _staker) public view returns (uint256 _price) {
        // TotalStaked
        return mapPoolStakerShares_[_token][_staker];
    } 
    
    // Returns the pool for a given index
    // @Dev can iterate from 0 to intPools to return all pools
    function pools(uint256 _index) public view returns (address _pool) {
        return mapIndexPool_[_index];
    } 
    
    // Returns number of pools that a staker is staking in
    // @Dev use this to return the number of pools for a staker
    function returnStakeCount(address _staker) public view returns (uint256 _stakeCount) {
        return mapStakerStakes_[_staker];
    } 
    
    // Returns the pool for a staker
    // @Dev can iterate from 0 to stakeCount above to return all pools for a staker
    function returnStakers(address _staker, uint256 _stakeIndex) public view returns (address _pool) {
        return mapStakerStakesPool_[_staker][_stakeIndex];
    } 
    
    // Returns Pool Resources
    function returnAPI(address _token) public view returns (string memory) {
    return poolAPIs_[_token];
    } 
    
    // Returns Pool Resources
    function returnURI(address _token) public view returns (string memory) {
    return poolURIs_[_token];
    } 
    
    
  // Internal Functions
  
  // Swap Function
  function _swapFunction(address _from, address _to, uint256 _x, address payable _dest, bool isEther) internal {
    
    bool Single;    
    uint256 balX;
    uint256 balY;
    uint256 feeY;
    uint256 y;
    uint256 liqFeeY;

      // Firstly determine if a Single or DoubleSwap (from or to address is CAN)
      if(_from == addrCAN){
          if(_to == addrCAN){
          }
          Single = true;
      } else {
          if(_to == addrCAN){
              Single = true;
          }
      }
     
        // Get balances and output Fee
        balX = _getBalance(_from);
        balY = _getBalance(_to);
        feeY = _getFee(_to);
        
        // Get the output and liquidity fee
        y = _getOutput(_x, balX, balY);
        liqFeeY = _getLiqFee(_x, balX, balY);
        
        // Make atomic swap
        balX = balX.add(_x);
        balY = balY.sub(y);
        feeY = feeY + liqFeeY;
        
        
     if (Single){
        _singleSwap(_from, _to, y, balX, balY, feeY, _dest, isEther);
     } else {
        _doubleSwap(_from, _to, y,  balX, balY, feeY, _dest, isEther);
     }
     
    }
    
    // SingleSwap Function
    function _singleSwap(address _from, address _to, 
    uint256 _y, uint256 _balX, uint256 _balY, uint256 _feeY, 
    address payable _dest, bool _isEther) internal{
        
        // Update mappings and balances
        _updateMappings(_from, _to, _balX, _balY, _feeY);

        // Send token
        _sendToken(_dest, _isEther, _y);
               
        // Emit the event log
        emit eventTokenEmitted(_to, _dest, _y, _feeY);
    }
    
    // DoubleSwap Function
    function _doubleSwap(address _from, address _to, 
    uint256 _y, uint256 _balX, uint256 _balY, uint256 _feeY, 
    address payable _dest, bool _isEther) internal {
        
        // Round2        
        uint256 balC = _getCANBalance(_to);
        uint256 balZ = _getBalance(_to);
        uint256 feeZ = _getFee(_to);
        
        uint256 z = _getOutput(_y, balC, balZ);
        uint256 liqFeeZ = _getLiqFee(_y, balC, balZ);     
        
        balC = balC.add(_y);
        balZ = balZ.sub(z);
        feeZ = feeZ + liqFeeZ;
        
        // Update mappings and balances - Pool1
        _updateMappings(_from, _from, _balX, _balY, _feeY);

        // Update mappings and balances - Pool2
        _updateMappings(_to, _to, balC, balZ, feeZ);

        // Send token
        _sendToken(_dest, _isEther, z);
               
        // Emit the event log
        emit eventTokenEmittedDouble(_from, _to, _dest, _y, _feeY, z, feeZ);
    }
    
    function _getOutput(uint256 x, uint256 X, uint256 Y) private pure returns (uint256 outPut){
        uint256 numerator = (x.mul(Y)).mul(X);
        uint256 denom = x.add(X);
        uint256 denominator = denom.mul(denom);
        outPut = numerator.div(denominator);
        return outPut;
    }
    
    function _getLiqFee(uint256 x, uint256 X, uint256 Y) private pure returns (uint256 liqFee){
        uint256 numerator = (x.mul(x)).mul(Y);
        uint256 denom = x.add(X);
        uint256 denominator = denom.mul(denom);
        liqFee = numerator.div(denominator);
        return liqFee;
    }

    function _getBalance(address _token) private view returns (uint256 _balance){
      if(_token == addrCAN){
        _balance = CANBalances_[_token];
      } else {
        _balance = TKNBalances_[_token];
      }
        return _balance;
    }
    
    function _getCANBalance(address _token) private view returns (uint256 _balance){
        _balance = CANBalances_[_token];
        return _balance;
    }

    function _getFee(address _token) private view returns (uint256 _fee){
      if(_token == addrCAN){
        _fee = CANFees_[_token];
      } else {
        _fee = TKNFees_[_token];
      }
        return _fee;
    }

    function _getCANFee(address _token) private view returns (uint256 _fee){
        _fee = CANFees_[_token];
        return _fee;
    }
    
    function _updateMappings(address _from, address _to, uint256 _balX, uint256 _balY, uint256 _Fee) internal{
      if(_from == addrCAN){
        CANBalances_[_from] = _balX;
        TKNBalances_[_to] = _balY;
        TKNFees_[_to] = _Fee;
      } else {
        TKNBalances_[_from] = _balX;
        CANBalances_[_to] = _balY;
        CANFees_[_to] = _Fee;
      }
    }
    
    
    function _sendToken(address payable _dest, bool _isEther, uint256 _sendValue) internal{
        if(_isEther){
            // SendEther
            _dest.transfer(_sendValue);
        }else {
            // Send the emission to the destination using ERC20 method
            ERC20 poolToken = ERC20(_dest);
            poolToken.transfer(_dest, _sendValue);
        }
    } 
    
    
    // CreatePool
  function _createThisPool(address _token, string memory _API, string memory _URI, uint256 _c, uint256 _t) internal {

    uint256 stakerInt;
    uint256 stakeCount;

    // Track Stakers
    if(isStaker_[msg.sender]=true){
        stakerInt = mapStakerIndex_[msg.sender];
        stakeCount = mapStakerStakes_[msg.sender] + 1;

    }else{
        intStakers += 1;
        stakerInt = intStakers;
        mapIndexStaker_[stakerInt] = msg.sender;
        mapStakerIndex_[msg.sender] = stakerInt;
        isStaker_[msg.sender] = true;
    }
    
      bal_CAN += _c;
      
      // Find the Pool Share - should be 100% of Stake since a brand new pool
      uint256 shareAve = _t;
      
      // Map Balances and Fees
      CANBalances_[_token] = _c;
      TKNBalances_[_token] = _t;
      CANFees_[_token] = 0;
      TKNFees_[_token] = 0;
      
      // Map new Pool
      mapIndexPool_[intPools] = _token;
      mapPoolIndex_[_token] = intPools;      
      
      // Map new Staker
      mapStakerPoolShares_[msg.sender][_token] = stakeAve;
      mapPoolStakerShares_[_token][msg.sender] = stakeAve;
      mapStakerStakes_[msg.sender] = stakeCount;
      mapPoolStakers_[_token] = 0;
      mapPoolStakersStaker_[_token][0] = msg.sender;
 
      // Map Resources
      poolURIs_[_token] = _URI;
      poolAPIs_[_token] = _API;
      
      /*
      // Add to arrays
      arrayTokens.push(_token);
      arrayTKNBal.push(_t);
      arrayCANBal.push(_c);
      */

      intPools += 1;
            
      emit eventCreatedPool(_token, _c, _t);
    }

  function _updateThisPool (address _token, string memory _URI, string memory _API) internal onlyStaker {
      poolURIs_[_token] = _URI;
      poolAPIs_[_token] = _API;
  }
  
    function _checkStakers(address _token) internal {
    
    uint256 stakerInt;
    uint256 stakeCount;
    uint256 stakerCount;

    // Track Stakers
    if(isStaker_[msg.sender]=true){
        stakerInt = mapStakerIndex_[msg.sender];
        if (mapIfStakinginPool_[_token][msg.sender] == true){
            stakeCount = mapStakerStakes_[msg.sender];
        } else {
            stakeCount = mapStakerStakes_[msg.sender] + 1;
            stakerCount = mapPoolStakers_[_token] + 1;
        }
    }else{
        intStakers += 1;
        stakerInt = intStakers;
        mapIndexStaker_[stakerInt] = msg.sender;
        mapStakerIndex_[msg.sender] = stakerInt;
        isStaker_[msg.sender] = true;
        stakerCount = mapPoolStakers_[_token] + 1;
    }
      require(stakerCount < 125);     // We don't want more than 125 stakers per pool to limit complexity
      mapStakerStakes_[msg.sender] = stakeCount;
    
      // Map the progressive count of stakers for this pool
      mapPoolStakers_[_token] = stakerCount;
      mapPoolStakersStaker_[_token][stakerCount] = msg.sender;
  }
 
  function _stakeInThisPool(address _token, uint256 _c, uint256 _t) internal {
    
      uint256 balC = _getCANBalance(_token);
      uint256 balT = _getBalance(_token);
            
      uint256 C = _c.div(_c.add(balC));             // Get share of CAN side in %
      uint256 T = _t.div(_t.add(balT));             // Get share of Token side in %
      uint256 numer = C.add(T);                     // Add
      uint256 stakeAve = numer.div(2);              // Get average between CAN and TKN side
      uint256 bal_Tot = _t.add(balT);               // Get new total of Token side
      uint256 shareAve = stakeAve.mul(bal_Tot);     // Get share of the Token side (will mirror CAN side)
      
      // Map
      CANBalances_[_token] = balC.add(_c);
      TKNBalances_[_token] = balT.add(_t);
      
      // Map Staker
      mapStakerPoolShares_[msg.sender][_token] = shareAve;
      mapPoolStakerShares_[_token][msg.sender] = shareAve;
      
      // Map new Token total
      uint256 total = mapTotalStakes_[_token];
      mapTotalStakes_[_token] = total.add(_t);         // Add the total for this pool 
  }
 
  
function _withdrawAllFromThisPool(address _token) internal onlyStaker {
      
    // Work out shares
    uint256 stakerShare = mapPoolStakerShares_[_token][msg.sender];
    uint256 balTKN = _getBalance(_token);
    uint256 balCAN = _getCANBalance(_token);
    
    uint256 shares = stakerShare.div(balTKN);
    uint256 shareCAN = shares.mul(balCAN);
    uint256 shareTKN = shares.mul(balTKN);
    
    // Transfer Shares 
    if(_token == address(0)){
    msg.sender.transfer(shareTKN);             // Send Ether
    require(CAN20.transfer(msg.sender, shareCAN));      // Send CAN  
    } else {
    ERC20 token20 = ERC20(_token);
    require(token20.transfer(msg.sender, shareTKN));    // Send Token
    require(CAN20.transfer(msg.sender, shareCAN));      // Send CAN
    }
    emit eventWithdraw(_token, shareCAN, shareTKN);
    
    // Balances
    CANBalances_[_token] = balCAN.sub(shareCAN);
    TKNBalances_[_token] = balTKN.sub(shareTKN);
    
    // Map Staker
    mapStakerPoolShares_[msg.sender][_token] = 0;
    mapPoolStakerShares_[_token][msg.sender] = 0;    
          
    // Map new Token total
    uint256 total = mapTotalStakes_[_token];
    mapTotalStakes_[_token] = total.sub(stakerShare);   // Remove the stakerShare from the total
  }
  
  function _distributeFeesForPool(address _pool) internal onlyStaker {
   
   uint256 stakeCount = mapPoolStakers_[_pool];
   
   for (uint i = 0; i < stakeCount; ++i){
       uint160 addr = uint160(mapPoolStakersStaker_[_pool][i]);
       address payable staker = address(addr);
       _iterateOverPool(_pool, staker);
   } 
   
    // Balances
    CANFees_[_pool] = 0;
    TKNFees_[_pool] = 0;
}

  function _iterateOverPool(address _token, address payable _staker) internal {
   
    // Work out shares
    uint256 stakerShare = mapPoolStakerShares_[_token][_staker];
    uint256 balTKNFee = _getFee(_token);
    uint256 balCANFee = _getCANFee(_token);
    
    uint256 shares = stakerShare.div(balTKNFee);
    uint256 shareCANFee = shares.mul(balCANFee);
    uint256 shareTKNFee = shares.mul(balTKNFee);
     
    // Transfer Shares 
    if(_token == address(0)){
    _staker.transfer(shareTKNFee);             // Send Ether
    require(CAN20.transfer(_staker, shareCANFee));      // Send CAN  
    } else {
    ERC20 token20 = ERC20(_token);
    require(token20.transfer(_staker, shareTKNFee));    // Send Token
    require(CAN20.transfer(_staker, shareCANFee));      // Send CAN
    }
    emit eventFeesDistributedTo(_token, shareCANFee, shareTKNFee);
  }

}
