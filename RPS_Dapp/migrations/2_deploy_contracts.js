var RPS = artifacts.require("./RPS.sol");
var dice = artifacts.require('./Dice.sol');
var ownable = artifacts.require('./Ownable.sol');
var safe = artifacts.require('./SafeMath.sol');

module.exports = function(deployer) {
  deployer.deploy(RPS);
  deployer.deploy(dice);
  deployer.deploy(ownable);
  deployer.deploy(safe);
};