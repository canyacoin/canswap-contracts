const {
  shouldBehaveLikeOwnable
} = require('./Ownable.behavior');

const Ownable = artifacts.require('CanSwap');

contract('CanSwap', function ([_, owner, ...otherAccounts]) {
  beforeEach(async function () {
    this.ownable = await Ownable.new({
      from: owner
    });
    await this.ownable.initialize(otherAccounts[3], {
      from: owner
    });
  });

  shouldBehaveLikeOwnable(owner, otherAccounts);
});