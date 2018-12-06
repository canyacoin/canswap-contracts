var CanSwap = artifacts.require("./CanSwap.sol");

module.exports = function(deployer) {
  deployer.deploy(CanSwap, "0xdD460A903488c988f2F092fEE7c3CC22254b5264");
};
