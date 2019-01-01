var CanSwap = artifacts.require("./CanSwap.sol");
var CanSwapMath = artifacts.require("./CanSwapMath.sol");

module.exports = async (deployer) => {
  await deployer.deploy(CanSwapMath);
  await deployer.link(CanSwapMath, CanSwap);
  await deployer.deploy(CanSwap);
  canSwapDeployed = await CanSwap.deployed();
  await canSwapDeployed.initialize("0xe05d0af11a8dd899a1e2a766d3f4d50c0396effc");
};
