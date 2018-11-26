pragma solidity 0.4.25;

// CanYaCoinToken Functions used in this contract
contract ERC20 {
  function transferFrom (address _from, address _to, uint256 _value) public returns (bool success);
  function balanceOf(address _owner) constant public returns (uint256 balance);
  function burn(uint256 value) public returns (bool success);
  function transfer (address _to, uint256 _value) public returns (bool success);
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
    uint256 public bal_CAN;
    uint256 public fee_CAN;
    uint256 public bal_TKN;
    uint256 public fee_TKN;
  
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
    
    mapping(address => mapping(address => uint256)) poolShares_;    // Map Shares that each Staker has in each Pool
    mapping(address => mapping(address => uint256)) userPools_;     // Map Pools that each Staker has a share in
 
 
    // Test Variables
    address public addrTKNA;
    address public addrTKNB;
    ERC20 public TKNA;
    ERC20 public TKNB;
  
  
  // Construct the contract  
  constructor () public {
        addrCAN = 0x2Ad210e82e8051d184be3b723fe3bdbC57a2C3fD;
        CAN20 = ERC20(addrCAN);
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
      } else {
        require(msg.value == _value);                       // Enforce ether tfr = value
        _swapFunction(_from, _to, _value, _dest, true);
      } 
  }
  
    // CreatePool
  function createPool(address _token, string _URI, string _API, uint256 _amountCAN, uint256 _amountTKN) public returns (bool success) {
      _createThisPool(_token, _URI, _API, _amountCAN, _amountTKN);
      return true;
  }
  
    // UpdatePool
  function updatePool(address _token, string _URI, string _API) public returns (bool success) {
      _updateThisPool(_token, _URI, _API);
      return true;
  }
  
    // Stake In
  function stakePool(address _token, uint256 _amountCAN, uint256 _amountTKN) public returns (bool success) {
      _stakeInThisPool(_token, _amountCAN, _amountTKN);
      return true;
  }  
  
    // Stake Out
  function withdrawPool(address _token, uint256 _amountCAN, uint256 _amountTKN) public returns (bool success) {
      _withdrawFromThisPool(_token, _amountCAN, _amountTKN);
      return true;
  } 
  
    // DistributeFees
  function distributeFees(address _token, uint256 _amountCAN, uint256 _amountTKN) public returns (bool success) {
      _distributeFeesForPool(_token, _amountCAN, _amountTKN);
      return true;
  } 
  
    // Owner can Settle Pool by distibuting all shares for each staker and de-activating pool 
    // Owner should then call distributeFees
  function settlePool (address _token) public onlyOwner {
      isActivated_[_token] = false;
      _settleThisPool(_token);
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
       _balances(0) = _getCANBalance(_token);
       _balances(1) = _getTKNBalance(_token);       
        return _balances;
    }
  
    // Returns Pool Price
    function price(address _token) public constant returns (uint256 _price) {
        uint256 _CAN = _getCANBalance(_token);
        uint256 _TKN = _getTKNBalance(_token);
        _price = _CAN.div(_TKN);
        return _price;
    } 
    
    // Returns Fees for Pool
    function fees(address _token) public constant returns (uint256[] _fees) {
       _fees(0) = _getCANFeeBalance(_token);
       _fees(1) = _getTKNFeeBalance(_token);       
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
    function pools(address _staker) public constant returns (address[] _pools) {
        return nArrayPools[_staker];
    } 
    
    // Returns all stakers in a pool
    function pools(address _token) public constant returns (address[] _stakers) {
        return nArrayStakes[_token];
    } 
    
    // Returns Pool Resources
    function resources(address _token) public constant returns (string[] _resources) {
       _resources(0) = _getAPI(_token);
       _resources(1) = _getURI(_token);       
        return _resources;
    } 
    
    
  // Internal Functions
  
  // Swap Function
  function _swapFunction(address _from, address _to, uint256 _x, address _dest, bool isEther) private returns (bool success) {
      
    bool Single;    
    uint256 balX;
    uint256 balY;
    uint256 feeY;
    uint256 y;
    uint256 liqFeeY;
    
    // Exit if not activated
    if(!isActivated_(_from)){
        return;
    }
    if(!isActivated_(_to)){
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
        _updateBalances(_from, _to, x, y, liqFeeY);
        
        // Send token
        _sendToken(_to, isEther, y);
               
        // Emit the event log
        emit eventTokenEmitted(_to, _dest, sendValue, feeY);
        
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
        uint256 balC = getCANBalance(_to);
        uint256 balZ = getBalance(_to);
        uint256 feeZ = getFee(_to);
        
        uint256 z = getOutput(y, balC, balZ);
        uint256 liqFeeZ = getLiqFee(y, balC, balZ);     
        
        // Make atomic swap
        balX = balX.add(_x);
        balY = balY.sub(_y);
        feeY = feeY + liqFeeY;
        balC = balC.add(_y);
        balZ = balZ.sub(z);
        feeZ = feeZ + liqFeeZ;
        
        // Update mappings and balances - Pool1
        _updateMappings(_from, _from, balX, balY, feeY);
        _updateBalances(_from, _from, x, y, liqFeeY);

        // Update mappings and balances - Pool2
        _updateMappings(_to, _to, balC, balZ, feeZ);
        _updateBalances(_to, _to, y, z, liqFeeZ);
        
        // Send token
        _sendToken(_to, isEther, z);
               
        // Emit the event log
        emit eventTokenEmittedDouble(_from, _to, _dest, y, feeY, z, feeZ);
     }
        
        return true;
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
    
    function _updateMappings(address _from, address _to, uint256 _balX, uint256 _balY, uint256 _Fee){
      if(_from == addrCAN){
        CANBalances_[_from] = _balX;
        TKNBalances_[_to] = _balY;
        TKNFeeBalances_[_to] = _Fee;
      } else {
        TKNBalances_[_from] = _balX;
        CANBalances_[_to] = _balY;
        CANFeeBalances_[_to] = _Fee;
      }
    }
    
    function _updateBalances(address _from, address _to, uint256 _x, uint256 _y, uint256 _fee){
      if(_from == addrCAN){
        bal_CAN += _x;
        bal_TKN -= _y;
        fee_TKN += _fee;
      } else {
        bal_TKN += _x;
        bal_CAN -= _y;
        fee_CAN += _fee;
      }
    }
    
    function sendToken(address _dest, bool _isEther, uint256 _sendValue){
        
        if(isEther){
            // SendEther
            _dest.transfer(_sendValue);
        }else {
            // Send the emission to the destination using ERC20 method
            ERC20 poolToken = ERC20(_to);
            poolToken.transfer(_dest, sendValue);
        }
    } 
    
    
    
    
    
    // CreatePool
  function _createThisPool(address _token, string _API, string _URI, uint256 _c, uint256 _t) internal {

      intPools += 1;
      
      balC = _getCANBalance(_token);
      balT = _getTKNBalance(_token);
            
      uint256 C = _c.div(_c.add(balC));
      uint256 T = _c.div(_c.add(balC));
      uint256 numer = C.add(T);
      uint256 stakeAve = numer.div(2);
      
       bal_CAN += _c;
       bal_TKN += _t;
      
      ERC20 token = ERC20(_token);
      
      emit CreatePool(_token, _amountCAN, _amountTKN);
      
      //CAN20.transferFrom(msg.sender, address(this), _amountCAN);
      //token.transferFrom(msg.sender, address(this), _amountTKN);
      
      return true;
  }

  function _updateThisPool(_token, _URI, _API) internal {
      
  }
 
  function _stakeInThisPool(_token, _CAN, _TKN) internal {
      
  }
 
  function _withdrawFromThisPool() internal onlyStaker {
  }
  
  function _distributeFeesForPool() internal onlyStaker {
  }
  
    // Test Method
  function setCreatePool1(){
  
        addrTKNA = 0x610FfB744DA03b657b02D36BcE2f9b0D188FD015;
        TKNB = ERC20(_addrTKNA);
        
        addrTKNB = 0x9e236516c791daa9f59ce01f6908b8a3bc22078e;
        TKNB = ERC20(_addrTKNB);
        
        intPools += 1;
        
        _amountCAN = 10000;        
        _amountTKNA = 10000;
        _amountTKNB = 10000;
            
      uint256 StakeAve = (_amountTKN.add(_amountCAN)).div(2);
      
      //CANBalances_[_token] = _amountCAN;
      //TKNBalances_[_token] = _amountTKN;
      //Stakes_[msg.sender][_token] = StakeAve;
      
       bal_CAN = _amountCAN;
       bal_TKN = _amountTKN;
      
      ERC20 token = ERC20(_token);
      
      emit CreatePool(_token, _amountCAN, _amountTKN);
      
      //CAN20.transferFrom(msg.sender, address(this), _amountCAN);
      //token.transferFrom(msg.sender, address(this), _amountTKN);
      
      return true;
      
  }
  
      
 // Swap Function
  function _doubleSwap(address _from, address _to, uint256 _x, address _dest) private returns (bool success) {
      
      uint256 sendValue;
      
        uint256 balX = getTKNBalance(_from);
        uint256 balY = getCANBalance(_from);
        uint256 feeY = getCANFeeBalance(_from);
        
        uint256 y = getOutput(_value, balX, balY);
        uint256 liqFeeY = getLiqFee(_value, balX, balY);
        
        balX = balX.add(x);
        balY = balY.sub(y);
        feeY = feeY + liqFeeY;
        
        uint256 balC = getCANBalance(_to);
        uint256 balZ = getBalance(_to);
        uint256 feeZ = getFeeBalance(_to);
        
        uint256 z = getOutput(y, balC, balZ);
        uint256 liqFeeZ = getLiqFee(y, balC, balZ);     
        
        balC = balC.add(y);
        balZ = balZ.sub(z);
        feeZ = feeZ + liqFeeZ;
        
        bal_CAN = balX;
        bal_TKN = balY;
        fee_TKN = feeY;
        
        
        sendValue = z;
        
        
        
        uint256 balX = getCANBalance(_from);
        uint256 balY = getTKNBalance(_to);
        uint256 feeY = getTKNFeeBalance(_to);
        
        uint256 y = getOutput(_x, balX, balY);
        uint256 liqFeeY = getLiqFee(_x, balX, balY);
        
        balX = balX.add(_x);
        balY = balY.sub(y);
        feeY = feeY + liqFeeY;
        
        //CANBalances_[_from] = balX;
        //TKNBalances_[_to] = balY;
        //TKNFeeBalances_[_to] = feeY;
        
        bal_CAN = balX;
        bal_TKN = balY;
        fee_TKN = feeY;
     
        sendValue = y;
      
        ERC20 poolToken = ERC20(_to);
        //poolToken.transfer(_dest, sendValue);
        
        emit tokenOutput(_to, _dest, sendValue);
        
        return true;
    }
  

}
