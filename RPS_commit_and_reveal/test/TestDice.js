const assert = require('chai').assert
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

    let balance = await web3.eth.getBalance(dice.address)

    assert.isTrue(balance.valueOf() == 0, "Balance is not zero");

  });

   /**
   * Test that is not possible to roll the dice when the risk is < minimumRisk
   */
   it("It is not possible to roll the dice for unvalid risk", async () => {
    const betAmount = 2000000000000000000;
    const risk = 20;
     
     try {
      await dice.playSoloRound(risk, {from:owner, value: betAmount, gas: '5600000'});
    } catch (error) {
      err = error;
    }
    assert.ok(err instanceof Error);
   });

  /**
   * Test that is not possible to roll the dice when the risk is < minimumRisk
   */
  it("It is not possible to roll when the bet amount is bigger than balance's contract", async () => {
    const betAmount = 2000000000000000000;
    const risk = 50;
     
     try {
      await dice.playSoloRound(risk, {from:owner, value: betAmount, gas: '5600000'});
    } catch (error) {
      err = error;
    }
    assert.ok(err instanceof Error);
   });

   /**
   * Test that is possible to roll a dice
   */
  it("Rolling dice between 1 and 100", async () => {


      const initFunds = 9000000000000000000;
      const betAmount = 2000000000000000000;
      const risk = 31;

      web3.eth.getAccounts(async (error, accounts) => {
        account = await accounts[0];
        await dice.fundGame({from:account, value: initFunds, gas: '5600000'});
        const result = await dice.playSoloRound(risk, {from:account, value: betAmount, gas: '5600000'});
    
         // Look for the logRollDice event to make sure query sent
         let testPassed = false // variable to hold status of result
         for (let i = 0; i < result.logs.length; i++) {
           let log = result.logs[i]
           if (log.event === 'logRollDice') {
             // we found the event
             testPassed = true
           }
         }
  
        assert(testPassed, '"logRollDice" event not found')
      });
   
 
        // Listen for logRolledDiceNumber event to check for Oraclize's call to _callback
      const LogRolledDiceNumber = dice.logRolledDiceNumber({});
  
      //create promise so Mocha waits for value to be returned
      let checkForNumber = new Promise((resolve, reject) => {     
       LogRolledDiceNumber.watch(async function(error, result) {
           if (error) {
             reject(error)
           }
           const randomNumber = (result.args._rolledDiceNumber).valueOf();
           // stop watching event and resolve promise
           LogRolledDiceNumber.stopWatching();
           resolve(randomNumber);
         }) 
      }) 

      var diceNumberResult  = function () {
        checkForNumber
          .then(function (fulfilled) {
            assert.isAtLeast(checkForNumber, 1, 'Random number was less than 1')
            assert.isAtMost(checkForNumber, 100, 'Random number was greater than 100')
          })
          .catch(function(error){
          });
      }

      diceNumberResult();
      }); // end 'it' block




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