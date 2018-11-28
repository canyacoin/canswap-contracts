const CanSwap = artifacts.require("CanSwap");

/**
 * Sample test for Migration
 */
contract("CanSwap", accounts => {
  const firstAccount = accounts[0];

  /**
   * Basic owner setting
   */
  it("sets an owner", async () => {
    const contract = await CanSwap.deployed();
    assert.equal(await contract.owner(), firstAccount);
  });
});