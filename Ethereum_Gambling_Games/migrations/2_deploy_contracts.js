var RPS = artifacts.require("./RPS.sol");
var Dice = artifacts.require("./Dice.sol");

module.exports = function(deployer) {
  deployer.deploy(RPS);
  deployer.deploy(Dice);
};