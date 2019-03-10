pragma solidity >=0.5;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/** @title RPS - RockPaperScissor P2P game, playing also for a jackpot.
  * @author rggentil
  * @notice This is just a simple game done mostly for learning solidity
            and web3 development, do not use betting real value since
            it has some known vulnerabilities.
  * @dev My first smartcontract, so probably code could be improved.
 */
contract GamblingGame is Ownable {
    using SafeMath for uint;

    uint public jackpot;
    bool public gameRunning;
    bool public lotteryOn;
    uint public minJackpot = 1 ether;  // TODO: probably better as a param in constructor
    uint public lotteryRate = 1000;  // TODO: same
    uint public minimumBet = 0.0001 ether;

    // Since we can't use decimals, represent the rate as ppm (part-per-million)
    // Used constant that saves gas, but it might be a good idea to set it as public
    // and be able to adjust the fee rate.
    // Set them as constnts althoug we could make them public vars
    uint constant jackpotFeeRate = 5000;
    uint constant feeUnits = 1000000;
    uint businessFeeRate = 2 * lotteryRate;
    uint public totalBusinessFee = 0;
    uint public minBusinessFeePayment = 0.01 ether;
    address payable public businessAddress = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;  // Ethereum foundation address

    event Payment(address paidAddress, uint amount);
    event LotteryWin(address winner, uint jackpot);

    /** @dev Modifier for functions available only when game is running
      * @param _isRunning bool to check is we need the game is running or not
    */
    modifier gameIsRunning(bool _isRunning) {
        require(gameRunning == _isRunning, "Function available only when game is running");
        _;
    }

    constructor() public payable {
        // We could handle games through constructor and setting variables like
        // minimum bet, max jackpot, fees, etc.
    }

    /** @notice Fallback, just in case of receiving funds, to the jackpot
    */
    function () external payable {
        jackpot = jackpot.add(msg.value);
    }

    /** @notice Payable, to fund game by adding ethers to contract and to the jackpot
      * @dev It's just the same as fallback function.
    */
    function fundGame() public payable {
        jackpot = jackpot.add(msg.value);
    }

    /** @notice When we have everything ready owner can start game so anyone can play. Also it starts lottery.
                Also for restarting game after having stopped it
    */
    function startGame() public onlyOwner gameIsRunning(false){
        require(jackpot <= address(this).balance, "Jackpot lower than SC balance");
        require((address(this).balance >= minJackpot) && (jackpot >= minJackpot), "Minimum Jackpot is needed for starting game");
        gameRunning = true;
        lotteryOn = true;
    }

    /** @notice Function for emergengies. Also it stops lottery.
    */
    function stopGame() public onlyOwner gameIsRunning(true){
        gameRunning = false;
        lotteryOn = false;
    }

    /** @notice Stop lottery (this means stop playing for jackpot)
    */
    function stopLottery() public onlyOwner {
        lotteryOn = false;
    }

    /** @notice Start lottery (this means playing for jackpot)
    */
    function startLottery() public onlyOwner {
        lotteryOn = true;
    }

    /** @notice Withdraw funds in case of an emergengy. Set jackpot to 0.
      * @param _myAddress addres to withdraw funds to
    */
    function withdrawFunds(address payable _myAddress) public onlyOwner gameIsRunning(false) {
        _myAddress.transfer(address(this).balance);
        jackpot = 0;
    }

    function _payRound(uint _roundId) private;

    // function _checkWinner(Player memory player1, Player memory player2) private pure returns(address payable);

    /** @notice Set the lottery rate in percentage, how easy is to hit the jackpot
      * @dev Mostly for testing porpuse. It should be removed in final deployment or no modifiable by anyone
      * @param newLotteryRate new lottery rate
     */
    // Mostly for testing porpuse.
    function setLotteryRate(uint newLotteryRate) public onlyOwner {
        lotteryRate = newLotteryRate;
    }

    /** @notice Set the minimum amount of ETH to be transfered when collecting business fees
      * @dev Mostly for testing porpuse. It should be removed in final deployment or no modifiable by anyone
      * @param newMinBusinessFeePayment new min amount of ETH to transfer to business
     */
    // Mostly for testing porpuse.
    function setminBusinessFeePayment(uint newMinBusinessFeePayment) public onlyOwner {
        minBusinessFeePayment = newMinBusinessFeePayment;
    }

    function _playLottery(address payable playerAddress, uint _roundId) private returns (bool);

    /** @notice Pay winner of the lottery
      * @param _winnerAddress address of the winner
     */
    function _payLotteryWinner(address payable _winnerAddress) internal {
        require(jackpot <= address(this).balance, "Jackpot is higher than contract balance");

        // I think we dont need to avoid reentrancy since no problem using transfer.
        _winnerAddress.transfer(jackpot);
        emit LotteryWin(_winnerAddress, jackpot);
        emit Payment(_winnerAddress, jackpot);
        jackpot = 0;
    }

}