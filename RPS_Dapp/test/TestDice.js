var Dice = artifacts.require('./Dice.sol');

/**
 * @author Antonio Cruz
 * @Test for Dice.sol
 * Declaration of variables that will be useful to test the functions and attributes values.
 */

contract('Dice', async (accounts) => {

  const owner = web3.eth.accounts[0];

  let dice;
  let err = null;

  
  beforeEach('setup contract for each test', async () => {
     dice = await Dice.deployed();
  });

  
  /**
   * Test that is possible to get the balance of the contract.
   */
  it("Getting the balance of the contract", async () => {

    let balance = await dice.getContractBalance({ from: owner });

    assert.isTrue(balance.valueOf() == 0, "Balance is not zero");

  });

   /**
   * Test that is possible to roll a dice
   */
  it("Rolling dice", async () => {

    const betAmount = 2000000000000000000;
    const risk = 31;



    ///////

        const account = await accounts[0];
        await dice.rollDice(risk, {from: account, value: betAmount});
          
        var LogPlayerBetAccepted = dice.logPlayerBetAccepted();
        await LogPlayerBetAccepted.watch((err, result) => {
           assert.equal(betAmount, (result.args._bet).valueOf());
           assert.equal(risk(result.args._risk).valueOf());   
        });

    //////////

    assert.isTrue(result.valueOf() > 0, "dice result");

  });


   /**
   * Test that only the owner can activate the emergency stop.
   * Used try/catch to catch de error.
   */ 
  it("Test Emergency Stop", async () => {

    try {
        await dice.enableEmergency({ from: owner });
    } catch (error) {
        err = error;
    }
    assert.ok(err instanceof Error);
  });

});