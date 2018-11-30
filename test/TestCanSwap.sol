pragma solidity 0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/mocks/ERC20DetailedMock.sol";
import "../contracts/CanSwap.sol";
import "./helpers/TestHelper.sol";

contract TestCanSwap {
    
    CanSwap _canSwap;
    ERC20 _tkn;
    ERC20 _can;

    address private constant address_1 = address(0xdD460A903488c988f2F092fEE7c3CC22254b5264);
    address private constant address_2 = address(0x200C0dDbf0467bEF9F284d35902C8ABc9a566790);

    /**
     * Set the state for all the tests
     */
    function beforeAll() public {
        _can = new ERC20DetailedMock("CanYaCoin", "CAN", 18, address(this), 100000000 * 10**18);
        _tkn = new ERC20DetailedMock("Token", "TKN", 18, address(this), 1000000 * 10**18);
        _canSwap = new CanSwap(address(_can));
    }

    /**
     * 
     */
    function testPoolFeesApplied() public {
        uint256 initialBalanceCan = _can.balanceOf(address(this));
        uint256 initialBalanceTkn = _tkn.balanceOf(address(this));
        
        uint256 amtCan = 100 * 10**18;
        uint256 amtTkn = 1 * 10**18;

        _can.approve(address(_canSwap), amtCan);
        _tkn.approve(address(_canSwap), amtTkn);
        
        _canSwap.createPoolForToken(address(_tkn), "uri", "api", amtCan, amtTkn);
        
        Assert.equal(_can.balanceOf(address(this)) = initialBalanceCan + amtCan, "CAN must be transferred to pool");
        Assert.equal(_tkn.balanceOf(address(this)) = initialBalanceTkn + amtTkn, "TKN must be transferred to pool");

    }
}