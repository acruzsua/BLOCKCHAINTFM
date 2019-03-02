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
  // it("Getting the balance of the contract", async () => {

  //   let balance = await dice.getContractBalance({ from: owner });

  //   assert.isTrue(balance.valueOf() == 0, "Balance is not zero");

  // });

   /**
   * Test that is possible to roll a dice
   */
  it("Rolling dice", async () => {


      // for simplicity, we'll do both checks in this function
      const betAmount = 2000000000000000000;
      const risk = 31;
      
   
      // call the getRandomNumber function
      // make sure to send enough Ether and to set gas limit sufficiently high
      //let result;
      const result = await dice.rollDice(risk, {
        from: accounts[0],
        value: betAmount,
        gas: '5600000',
      })
  
      // Method 1 to check for events: loop through the "result" variable
  
      // look for the logRollDice event to make sure query sent
       let testPassed = false // variable to hold status of result
       for (let i = 0; i < result.logs.length; i++) {
         let log = result.logs[i]
         if (log.event === 'logRollDice') {
           // we found the event
           testPassed = true
         }
       }

    

       assert(testPassed, '"logRollDice" event not found')
  
       // Method 2 to check for events: listen for them with .watch()
  
       // listen for LogResultReceived event to check for Oraclize's call to _callback
       // define events we want to listen for
       const LogResultReceived = dice.logRolledDiceNumber()
  
       // create promise so Mocha waits for value to be returned
      //  let checkForNumber = new Promise((resolve, reject) => {
      //    // watch for our LogResultReceived event
         
      //    LogResultReceived.watch(async function(error, result) {
      //      if (error) {
      //        reject(error)
      //      }
      //      // template.randomNumber() returns a BigNumber object
      //      const bigNumber = await dice.rolledDiceNumber()
      //      // convert BigNumber to ordinary number
      //      const randomNumber = bigNumber.toNumber()
      //      // stop watching event and resolve promise
      //      LogResultReceived.stopWatching()
      //      resolve(randomNumber)
      //    }) // end LogResultReceived.watch()
      //  }) // end new Promise
  
       // call promise and wait for result
      //  const randomNumber = await checkForNumber
      //  // ensure result is within our query's min/max values
      //  assert.isAtLeast(randomNumber, 1, 'Random number was less than 1')
      //  assert.isAtMost(randomNumber, 1000, 'Random number was greater than 1000')
  
     }); // end 'it' block




   /**
   * Test that only the owner can activate the emergency stop.
   * Used try/catch to catch de error.
   */ 
  // it("Test Emergency Stop", async () => {

  //   try {
  //       await dice.enableEmergency({ from: owner });
  //   } catch (error) {
  //       err = error;
  //   }
  //   assert.ok(err instanceof Error);
  // });

});