var CanSwap = artifacts.require("./CanSwap.sol");
var ERC20DetailedMock = artifacts.require("./mocks/ERC20DetailedMock.sol");
var CanSwapMath = artifacts.require("./CanSwapMath.sol");

const BigNumber = web3.utils.BN;

getBN = (val, dec) => {
  return new BigNumber((val * 10**dec).toString(16), 16);
}

module.exports = async (deployer, network, accounts) => {

  await deployer.deploy(ERC20DetailedMock, "CanYaCoin", "CAN", 18, getBN(100000000, 18), accounts[0]);
  canYaCoinDeployed = await ERC20DetailedMock.deployed();

  await deployer.deploy(CanSwapMath);
  await deployer.link(CanSwapMath, CanSwap);
  await deployer.deploy(CanSwap);
  canSwapDeployed = await CanSwap.deployed();
  await canSwapDeployed.initialize(canYaCoinDeployed.address);
};
