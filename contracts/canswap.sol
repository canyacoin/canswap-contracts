pragma solidity 0.4.25;

// CanYaCoinToken Functions used in this contract
contract ERC20 {
  function transferFrom (address _from, address _to, uint256 _value) public returns (bool success);
  function balanceOf(address _owner) constant public returns (uint256 balance);
  function burn(uint256 value) public returns (bool success);
  function transfer (address _to, uint256 _value) public returns (bool success);
  uint256 public totalSupply;
  uint256 public decimals;
}

// ERC223
interface ContractReceiver {
  function tokenFallback( address from, uint value, bytes data ) external;
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

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
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
    mapping(address => uint256) TKNFees_;                // Map TKNFeebalances
    mapping(address => uint256) CANFees_;                // Map CANFeebalances
    
    mapping(address => bool) isStaker_;                         // Map if Staking (yes/no)
    mapping(address => bool) isPool_;                           // Map if Pool (yes/no)
    mapping(address => bool) isBlacklisted_;                    // Map if TokenBlacklisted (yes/no)
    mapping(address => bool) isActivated_;                      // Map if Pool Activated (yes/no)

    mapping(address => uint256) Stakers_;                           // Map Stakers (who is who)  
    mapping(address => uint256) Pools_;                             // Map Pools (which pool is what)
    mapping(address => mapping(address => uint256)) poolShares_;    // Map Shares that each Staker has in each Pool
    mapping(address => mapping(address => uint256)) userPools_;     // Map Pools that each Staker has a share in

    mapping(uint256 => address) mapTokens_;
    mapping(uint256 => uint256) mapCANBalances_;  
    mapping(uint256 => uint256) mapTKNBalances_;  
    mapping(uint256 => mapping(address => address)) mapPools_;      // Map Stakers that each Pool has
    mapping(uint256 => mapping(address => address)) mapStakers_;    // Map Pools that each Staker has a share in

    
    // Optional mapping for token resources
    mapping(uint256 => string) internal poolURIs_;
    mapping(uint256 => string) internal poolAPIs_;    
  
  // Construct the contract as well as the first pool (ether) 
  constructor (address _addrCAN) public {
        CAN20 = ERC20(_addrCAN);
        addrCAN = _addrCAN;
        intPools = 0;
        bal_CAN = 0;
        fee_CAN = 0;
  }
  
    // CreateEtherPool
  function createEtherPool(uint256 _c, uint256 _e) onlyOwner payable {
        require(msg.value == _e);                                       // Enforce ether tfr = value
        require(CAN20.transferFrom(msg.sender, address(this), _c));     // TransferIn CAN
        _createThisPool(0x0, "etherLogoURL", "etherPriceAPI", _c, _e);
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
      // Determine if not ether (from or to address is not 0x0)
      if(_from != 0){
          if(_to != 0){
              ERC20 token20 = ERC20(_from);                                         // Create ERC20 instance
              require(token20.transferFrom(msg.sender, address(this), _value));     // TransferIn
              _swapFunction(_from, _to, _value, msg.sender, false);                 // Swap!
          }
          return;
      } else {
        require(msg.value == _value);                                               // Enforce ether tfr = value
        _swapFunction(_from, _to, _value, msg.sender, true);                        // Swap!
      } 
  }
      
  // Swap and Send Function
  function swapAndSend(address _from, address _to, uint256 _value, address _dest) public payable {
      // Determine if not ether (from or to address is not 0x0)
      if(_from != 0){
          if(_to != 0){
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
  function createPool(address _token, string _URI, string _API, uint256 _c, uint256 _t) public {
    ERC20 token20 = ERC20(_token);                                         // Create ERC20 instance
    require(token20.transferFrom(msg.sender, address(this), _t));     // TransferIn tokens
    require(CAN20.transferFrom(msg.sender, address(this), _c));     // TransferIn CAN
    _createThisPool(_token, _URI, _API, _c, _t);
  }
  

  
    // UpdatePool
  function updatePool(address _token, string _URI, string _API) public returns (bool success) {
      _updateThisPool(_token, _URI, _API);
      return true;
  }
  
    // Stake In
  function stakePool(address _token, uint256 _c, uint256 _t) public returns (bool success) {
      _stakeInThisPool(_token, _c, _t);
      return true;
  }  
  
    // Stake Out
  function withdraw(address _token, uint256 _c, uint256 _t) public returns (bool success) {
      _withdrawFromThisPool(_token, _c, _t);
      return true;
  } 
  
      // Stake Out
  function withdrawAll(address _token) public returns (bool success) {
      _withdrawAllFromThisPool(_token);
      return true;
  } 
  
    // DistributeFees
  function distributeFees(address _token) public returns (bool success) {
      _distributeFeesForPool(_token);
      return true;
  } 
  
    // Owner can Settle Pool by distibuting all shares for each staker and de-activating pool 
    // Owner should then call distributeFees
  function settlePool (address _token) public onlyOwner {
      isActivated_[_token] = false;
      //_settleThisPool(_token);
  } 
  
    // Any staker can blacklist a token
  function blacklistToken(address _token) public onlyStaker {
      isBlacklisted_[_token] = true;
  } 

  // Any staker can whitelist a token
  function whitelistToken(address _token) public onlyStaker {
      isBlacklisted_[_token] = false;
  } 
  
  // Readonly Functions
  //
  // 
  
    // Returns Balances for Pool
    function balances(address _token) public constant returns (uint256[] _balances) {
       _balances[0] = _getCANBalance(_token);
       _balances[1] = _getBalance(_token);       
        return _balances;
    }
  
    // Returns Pool Price
    function price(address _token) public constant returns (uint256 _price) {
        uint256 _CAN = _getCANBalance(_token);
        uint256 _TKN = _getBalance(_token);
        _price = _CAN.div(_TKN);
        return _price;
    } 
    
    // Returns Fees for Pool
    function fees(address _token) public constant returns (uint256[] _fees) {
       _fees[0] = _getCANFee(_token);
       _fees[1] = _getFee(_token);       
        return _fees;
    }

    // Returns Stakers Share of Pool
    function share(address _token, address _staker) public constant returns (uint256 _price) {
        return poolShares_[_token][_staker];
    } 
    
    // Returns all pools
    function pools() public constant returns (address[] _pools) {
        return arrayTokens;
    } 
    
    // Returns all pools that a staker is staking in
    function returnPools(address _staker) public constant returns (address[] _pools) {
        // return nArrayPools[_staker];
    } 
    
    // Returns all stakers in a pool
    function returnStakers(address _token) public constant returns (address[] _stakers) {
        // return nArrayStakes[_token];
    } 
    
    // Returns Pool Resources
    function returnAPI(address _token) public constant returns (string) {
    //return poolAPIs_[_token];
    } 
    
    
  // Internal Functions
  
  // Swap Function
  function _swapFunction(address _from, address _to, uint256 _x, address _dest, bool isEther) internal {
      
    bool Single;    
    uint256 balX;
    uint256 balY;
    uint256 feeY;
    uint256 y;
    uint256 liqFeeY;
    
    // Exit if not activated
    if(isActivated_[_from] == false){
        return;
    }
    if(isActivated_[_to] == false){
        return;
    }
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
     
     // If Single swap
     if (Single){
        
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
        
        // Update mappings and balances
        _updateMappings(_from, _to, balX, balY, feeY);
        //_updateBalances(_from, _to, _x, y, liqFeeY);
        
        // Send token
        _sendToken(_to, isEther, y);
               
        // Emit the event log
        emit eventTokenEmitted(_to, _dest, y, feeY);
        
     } else {
        // DoubleSwap
         
        // Get balances and output Fee
        balX = _getBalance(_from);
        balY = _getCANBalance(_from);
        feeY = _getFee(_to);
        
        // Get the output and liquidity fee
        y = _getOutput(_x, balX, balY);
        liqFeeY = _getLiqFee(_x, balX, balY);
        
        // Round2        
        uint256 balC = _getCANBalance(_to);
        uint256 balZ = _getBalance(_to);
        uint256 feeZ = _getFee(_to);
        
        uint256 z = _getOutput(y, balC, balZ);
        uint256 liqFeeZ = _getLiqFee(y, balC, balZ);     
        
        // Make atomic swap
        balX = balX.add(_x);
        balY = balY.sub(y);
        feeY = feeY + liqFeeY;
        balC = balC.add(y);
        balZ = balZ.sub(z);
        feeZ = feeZ + liqFeeZ;
        
        // Update mappings and balances - Pool1
        _updateMappings(_from, _from, balX, balY, feeY);
        //_updateBalances(_from, _from, _x, y, liqFeeY);

        // Update mappings and balances - Pool2
        _updateMappings(_to, _to, balC, balZ, feeZ);
        //_updateBalances(_to, _to, y, z, liqFeeZ);
        
        // Send token
        _sendToken(_to, isEther, z);
               
        // Emit the event log
        emit eventTokenEmittedDouble(_from, _to, _dest, y, feeY, z, feeZ);
     }
    }
    
    function _getOutput(uint256 x, uint256 X, uint256 Y) private returns (uint256 outPut){
        uint256 numerator = (x.mul(Y)).mul(X);
        uint256 denom = x.add(X);
        uint256 denominator = denom.mul(denom);
        outPut = numerator.div(denominator);
        return outPut;
    }
    
    function _getLiqFee(uint256 x, uint256 X, uint256 Y) private returns (uint256 liqFee){
        uint256 numerator = (x.mul(x)).mul(Y);
        uint256 denom = x.add(X);
        uint256 denominator = denom.mul(denom);
        liqFee = numerator.div(denominator);
        return liqFee;
    }

    function _getBalance(address _token) private returns (uint256 _balance){
      if(_token == addrCAN){
        _balance = CANBalances_[_token];
      } else {
        _balance = TKNBalances_[_token];
      }
        return _balance;
    }
    
    function _getCANBalance(address _token) private returns (uint256 _balance){
        _balance = CANBalances_[_token];
        return _balance;
    }

    function _getFee(address _token) private returns (uint256 _fee){
      if(_token == addrCAN){
        _fee = CANFees_[_token];
      } else {
        _fee = TKNFees_[_token];
      }
        return _fee;
    }

    function _getCANFee(address _token) private returns (uint256 _fee){
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
    
    
    function _sendToken(address _dest, bool _isEther, uint256 _sendValue) internal{
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
  function _createThisPool(address _token, string _API, string _URI, uint256 _c, uint256 _t) internal {
      
      // Bail if it has already been added
      if(isPool_[_token]){
          return;
      }

    ERC20 token20 = ERC20(_token);
    bool isERC20 = false;
    uint256 StakerInt;
    
    // Find if it matches ERC20 standard, some flexibility
    /*
    if(token20.totalSupply >= 0){
        isERC20 = true;
    } else if (token20.decimals >= 0){
        isERC20 = true;
    }
    */
    
    // Bail if not an ERC20 
    if(isERC20 = false){
        return;
    }
    
    // Track Stakers
    if(isStaker_[msg.sender]=true){
        StakerInt = Stakers_[msg.sender];
    }else{
        StakerInt = intStakers + 1;
        intStakers += 1;
    }
    
      intPools += 1;
      bal_CAN += _c;
      
      // Find the average Stake
      uint256 numer = _c.add(_t);
      uint256 stakeAve = numer.div(2);
      
      // Map
      CANBalances_[_token] = _c;
      TKNBalances_[_token] = _t;
      poolShares_[_token][msg.sender] = stakeAve;
      userPools_[msg.sender][_token] = stakeAve;
      
      // Map 
      mapStakers_[StakerInt][intPools] = _token;
      mapPools_[intPools][StakerInt] = msg.sender;
      mapCANBalances_[intPools] = _c;
      mapTKNBalances_[intPools] = _t;
      mapTokens_[intPools] = _token;

      poolURIs_[intPools] = _URI;
      poolAPIs_[intPools] = _API;
      
      // Add to arrays
      arrayTokens.push(_token);
      arrayTKNBal.push(_t);
      arrayCANBal.push(_c);
      

      
      emit eventCreatedPool(_token, _c, _t);
    }



  function _updateThisPool (address _token, string _URI, string _API) internal onlyStaker {
      require(isPool_[_token]);
      poolURIs_[intPools] = _URI;
      poolAPIs_[intPools] = _API;
  }
 
  function _stakeInThisPool(address _token, uint256 _c, uint256 _t) internal {
      
    uint256 StakerInt;

          // Track Stakers
    if(isStaker_[msg.sender]=true){
        StakerInt = Stakers_[msg.sender];
    }else{
        StakerInt = intStakers + 1;
        intStakers += 1;
    }
    
      uint256 balC = _getCANBalance(_token);
      uint256 balT = _getBalance(_token);
            
      uint256 C = _c.div(_c.add(balC));
      uint256 T = _c.div(_c.add(balC));
      uint256 numer = C.add(T);
      uint256 stakeAve = numer.div(2);
      
       bal_CAN += _c;
       
      // Map
      CANBalances_[_token] = balC.add(_c);
      TKNBalances_[_token] = balT.add(_t);
      poolShares_[_token][msg.sender] = stakeAve;
      userPools_[msg.sender][_token] = stakeAve;
      
      // Map 
      mapStakers_[StakerInt][intPools] = _token;
      mapPools_[intPools][StakerInt] = msg.sender;
      mapCANBalances_[intPools] = balC.add(_c);
      mapTKNBalances_[intPools] = balT.add(_t);
       
       
  }
 
  function _withdrawFromThisPool(address _token, uint256 _c, uint256 _t) internal onlyStaker {
      
    // Work out shares
    uint256 StakerInt = Stakers_[msg.sender];
    uint256 stakerShare = poolShares_[_token][msg.sender];
    uint256 balTKN = _getBalance(_token).sub(_t);
    uint256 balCAN = _getCANBalance(_token).sub(_c);
    
    uint256 shares = stakerShare.div(balTKN);
    uint256 shareCAN = share.mul(balCAN);
    uint256 shareTKN = share.mul(balTKN);
    
    // Transfer Shares 
    if(_token == 0x0){
    require(msg.sender.transfer(shareTKN));             // Send Ether
    require(CAN20.transfer(msg.sender, shareCAN));      // Send CAN  
    } else {
    ERC20 token20 = ERC20(_token);
    require(token20.transfer(msg.sender, shareTKN));    // Send Token
    require(CAN20.transfer(msg.sender, shareCAN));      // Send CAN
    }
    emit eventWithdraw(_token, shareCAN, shareTKN);
  }
  
function _withdrawAllFromThisPool(address _token) internal onlyStaker {
      
    // Work out shares
    uint256 StakerInt = Stakers_[msg.sender];
    uint256 stakerShare = poolShares_[_token][msg.sender];
    uint256 balTKN = _getBalance(_token);
    uint256 balCAN = _getCANBalance(_token);
    
    uint256 shares = stakerShare.div(balTKN);
    uint256 shareCAN = share.mul(balCAN);
    uint256 shareTKN = share.mul(balTKN);
    
    // Transfer Shares 
    if(_token == 0x0){
    require(msg.sender.transfer(shareTKN));             // Send Ether
    require(CAN20.transfer(msg.sender, shareCAN));      // Send CAN  
    } else {
    ERC20 token20 = ERC20(_token);
    require(token20.transfer(msg.sender, shareTKN));    // Send Token
    require(CAN20.transfer(msg.sender, shareCAN));      // Send CAN
    }
    emit eventWithdraw(_token, shareCAN, shareTKN);
  }
  
  function _distributeFeesForPool(address _token) internal onlyStaker {
          // Work out shares
    uint256 StakerInt = Stakers_[msg.sender];
    uint256 stakerShare = poolShares_[_token][msg.sender];
    uint256 balTKNFee = _getFee(_token);
    uint256 balCANFee = _getCANFee(_token);
    
    uint256 shares = stakerShare.div(balTKNFee);
    uint256 shareCANFee = share.mul(balCANFee);
    uint256 shareTKNFee = share.mul(balTKNFee);
     
    // Transfer Shares 
    if(_token == 0x0){
    require(msg.sender.transfer(shareTKNFee));             // Send Ether
    require(CAN20.transfer(msg.sender, shareCANFee));      // Send CAN  
    } else {
    ERC20 token20 = ERC20(_token);
    require(token20.transfer(msg.sender, shareTKNFee));    // Send Token
    require(CAN20.transfer(msg.sender, shareCANFee));      // Send CAN
    }
    emit eventWithdraw(_token, shareCANFee, shareTKNFee);
  }


}
