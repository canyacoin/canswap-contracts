var CanSwap = artifacts.require("./CanSwap.sol");
var CanSwapMath = artifacts.require("./CanSwapMath.sol");

module.exports = function(deployer) {
  deployer.deploy(CanSwapMath);
  deployer.link(CanSwapMath, CanSwap);
  deployer.deploy(CanSwap, "0xdD460A903488c988f2F092fEE7c3CC22254b5264");
};
