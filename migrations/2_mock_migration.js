var SafeMath = artifacts.require("./SafeMath.sol");
var CanSwapMath = artifacts.require("./CanSwapMath.sol");
var CanSwapMathMock = artifacts.require("./CanSwapMathMock.sol");

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, CanSwapMath);
  deployer.deploy(CanSwapMath);
  deployer.link(CanSwapMath, CanSwapMathMock);
  deployer.deploy(CanSwapMathMock);
};
