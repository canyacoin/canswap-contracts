
const Migrations = artifacts.require("Migrations");

/**
 * Sample test for Migration
 */
contract("Migrations", accounts => {
  const firstAccount = accounts[0];

  /**
   * Basic owner setting
   */
  it("sets an owner", async () => {
    const contract = await Migrations.deployed();
    assert.equal(await contract.owner(), firstAccount);
  });
});