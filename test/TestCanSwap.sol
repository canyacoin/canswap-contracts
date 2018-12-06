pragma solidity 0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/mocks/ERC20DetailedMock.sol";
import "../contracts/CanSwap.sol";
import "./helpers/TestHelper.sol";

contract TestCanSwap {
    
    using SafeMath for uint256;

    CanSwap _canSwap;
    ERC20DetailedMock _tkn;
    ERC20DetailedMock _can;

    address private constant address_1 = address(0xdD460A903488c988f2F092fEE7c3CC22254b5264);
    address private constant address_2 = address(0x200C0dDbf0467bEF9F284d35902C8ABc9a566790);

    /**
     * Set the state for all the tests
     */
    function beforeAll() public {
        _can = new ERC20DetailedMock("CanYaCoin", "CAN", 18, 100000000 * 10**18, address(this));
        _tkn = new ERC20DetailedMock("Token", "TKN", 18, 1000000 * 10**18, address(this));
        _canSwap = new CanSwap(address(_can));
    }

    /**
     * 
     */
    function testPoolFeesApplied() public {
        uint256 initialBalanceTkn = _tkn.balanceOf(address(_canSwap));
        uint256 initialBalanceCan = _can.balanceOf(address(_canSwap));
        
        uint256 amtTkn = 1 * 10**18;
        uint256 amtCan = 100 * 10**18;

        _tkn.approve(address(_canSwap), amtTkn);
        _can.approve(address(_canSwap), amtCan);
        
        _canSwap.createPoolForToken(address(_tkn), "uri", "api", amtTkn, amtCan);
        
        Assert.equal(_tkn.balanceOf(address(_canSwap)), initialBalanceTkn.add(amtTkn), "TKN must be transferred to pool");
        Assert.equal(_can.balanceOf(address(_canSwap)), initialBalanceCan.add(amtCan), "CAN must be transferred to pool");
    }
}