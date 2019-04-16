pragma solidity >=0.5;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


/** @title Abstract contract that defines methods to add the lottery functionality
           to Ethereum Gambling Games
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
  * @notice This is just a simple game for the TFM of the Master in Ethereum.
            Do not use betting real value since it may have some vulnerabilities.
            Further analysis and assurance is needed to take in production/main net.
 */
contract LotteryGame is Ownable{

    using SafeMath for uint;

    uint public jackpot;
    bool public lotteryOn;
    uint public lotteryRate = 1000;  // TODO: same
    uint public minJackpot = 1 ether;  // TODO: probably better as a param in constructor

    event LotteryWin(address winner, uint jackpot);

    constructor() public payable {
        // We could handle games through constructor and setting variables like
        // minimum bet, max jackpot, fees, etc.
    }

    /** @notice Fallback, just in case of receiving funds, to the jackpot
    */
    function () external payable {
        jackpot = jackpot.add(msg.value);
    }

    /** @notice Stop lottery (this means stop playing for jackpot)
    */
    function stopLottery() public onlyOwner {
        lotteryOn = false;
    }

    /** @notice Start lottery (this means playing for jackpot)
    */
    function startLottery() public onlyOwner {
        require(jackpot <= address(this).balance, "Jackpot lower than SC balance");
        require((address(this).balance >= minJackpot) && (jackpot >= minJackpot), "Minimum Jackpot is needed for starting game");
        lotteryOn = true;
    }

    /** @notice Set the lottery rate in percentage, how easy is to hit the jackpot
      * @dev Mostly for testing porpuse. It should be removed in final deployment or no modifiable by anyone
      * @param newLotteryRate new lottery rate
     */
    // Mostly for testing porpuse.
    function setLotteryRate(uint newLotteryRate) public onlyOwner {
        lotteryRate = newLotteryRate;
    }

    /** @notice Pay winner of the lottery
      * @param _winnerAddress address of the winner
     */
    function _payLotteryWinner(address payable _winnerAddress, uint betAmount) internal {
        _winnerAddress.transfer(address(this).balance);
        emit LotteryWin(_winnerAddress, jackpot);
        jackpot = 0;
    }

    /** @notice Payable, to fund game by adding ethers to contract and to the jackpot
      * @dev It's just the same as fallback function.
    */
    function fundGame() public payable {
        jackpot = jackpot.add(msg.value);
    }

    function _playLottery(address payable playerAddress, uint _roundId) private returns (bool);
}