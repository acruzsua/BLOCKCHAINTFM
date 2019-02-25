var RPS = artifacts.require("./RPS.sol");
var dice = artifacts.require('./Dice.sol');
var ownable = artifacts.require('./Ownable.sol');
var safe = artifacts.require('./SafeMath.sol');
var diceLib = artifacts.require("./DiceLib.sol");
var startstopGame = artifacts.require("./StartStopGame.sol");

module.exports = function(deployer) {
  deployer.deploy(RPS);
  deployer.deploy(dice);
  deployer.deploy(diceLib);
  deployer.link(diceLib,dice);
  deployer.deploy(ownable);
  deployer.deploy(safe);
  deployer.deploy(startstopGame);

};