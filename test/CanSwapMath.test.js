const CanSwapMathMock = artifacts.require("CanSwapMathMock");

const BigNumber = web3.utils.BN;

require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .should();

getBN = (val, dec) => {
  return new BigNumber((val * 10**dec).toString(16), 16);
}

contract("CanSwapMathMock", function (){

  beforeEach(async () => {
    this.canSwapMathMock = await CanSwapMathMock.new();
  });

  assertOutput = async (x, X, Y) => {
    const expectedOutput = (x.mul(Y)).div(x.add(X));
    const output = new BigNumber((await this.canSwapMathMock.getOutput(x, X, Y)).toString(2), 2);
    assert(expectedOutput.eq(output), "Output must be correct");
    return output;
  }

  assertLiqFee = async (x, X, Y) => {
    const expectedLiqFee = (x.mul(x).mul(Y)).div(x.add(X).sqr());
    const liqFee = new BigNumber((await this.canSwapMathMock.getLiqFee(x, X, Y)).toString(2), 2);
    assert(expectedLiqFee.eq(liqFee), "Liqudity fee must be correct");
    return liqFee;
  }

  describe("getOutput", () => {

    it("calculates output for standard pool", async () => {
      const input = getBN(1000, 6);       
      const inputBal = getBN(100000000, 6);  
      const outputBal = getBN(500000, 18);    
      assertOutput(input, inputBal, outputBal);
    });
    it("calculates output for pool with low input balance", async () => {
      const input = getBN(15000, 18);     
      const inputBal = getBN(500, 18);        
      const outputBal = getBN(500000, 18);   
      assertOutput(input, inputBal, outputBal);
    });
  });

  describe("getLiqFee", () => {

    it("calculates basic liquidity fee", async () => {
      const input = getBN(35252, 6);      
      const inputBal = getBN(100000000, 6); 
      const outputBal = getBN(500000, 18);   
      assertLiqFee(input, inputBal, outputBal);
    });
  });

  describe("getFinalOutput", () => {

    it("calculates emission", async () => {
      const input = getBN(1000, 6);       
      const inputBal = getBN(100000000, 6);  
      const outputBal = getBN(500000, 18);    

      var output = await assertOutput(input, inputBal, outputBal);
      var liqFee = await assertLiqFee(input, inputBal, outputBal);
      
      assert(output.gt(liqFee), "Output must be gt liqfee")
      
      const expectedEmission = output.sub(liqFee);
      
      let swapResults = await this.canSwapMathMock.calculateSwapOutput(input, inputBal, outputBal);
      let swapEmission = new BigNumber(swapResults[1].toString(16), 16);
    
      assert(expectedEmission.eq(swapEmission), "Emission must be correct")
    });
  });  
});
