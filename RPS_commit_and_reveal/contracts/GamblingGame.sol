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

    uint constant LOTERY_RATE = 1000;

    bool public gameRunning;

    uint public minimumBet = 0.0001 ether;

    // Since we can't use decimals, represent the rate as ppm (part-per-million)
    // Used constant that saves gas, but it might be a good idea to set it as public
    // and be able to adjust the fee rate.
    // Set them as constnts althoug we could make them public vars
    uint constant jackpotFeeRate = 5000;
    uint constant feeUnits = 1000000;
    uint businessFeeRate = 2 * LOTERY_RATE;
    uint public totalBusinessFee = 0;
    uint public minBusinessFeePayment = 0.01 ether;
    address payable public businessAddress = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;  // Ethereum foundation address

    event Payment(address paidAddress, uint amount);

    /** @dev Modifier for functions available only when game is running
      * @param _isRunning bool to check is we need the game is running or not
    */
    modifier gameIsOn(bool _isRunning) {
        require(gameRunning == _isRunning, "Function available only when game is running");
        _;
    }

    constructor() public payable {
        // We could handle games through constructor and setting variables like
        // minimum bet, max jackpot, fees, etc.
    }

    /** @notice When we have everything ready owner can start game so anyone can play. Also it starts lottery.
                Also for restarting game after having stopped it
    */
    function startGame() public onlyOwner gameIsOn(false){
        gameRunning = true;
    }

    /** @notice Function for emergengies. Also it stops lottery.
    */
    function stopGame() public onlyOwner gameIsOn(true){
        gameRunning = false;
    }

    /** @notice Withdraw funds in case of an emergengy. Set jackpot to 0.
      * @param _myAddress addres to withdraw funds to
    */
    function withdrawFunds(address payable _myAddress) public onlyOwner gameIsOn(false) {
        _myAddress.transfer(address(this).balance);
    }

    function _resolveRound(uint _roundId) private;

    function _payRound(uint _roundId) private;

    /**
     * @notice Test if the player's bet is at least the minium required for playing
     * @param _bet Indicates the bet risked by the user
     * @param _minimumBet Indicates the minimum bet accepted to play the game
     * @return True if player's bet is at least equal to the minimum expected to allow the game, False otherwise.
     */
    function isValidBet (uint _bet, uint _minimumBet, uint _maximumBet)
        internal
        pure
        returns (bool)
    {
        return ((_bet >= _minimumBet) && (_bet < _maximumBet) );
    }

    // function _checkWinner(Player memory player1, Player memory player2) private pure returns(address payable);

    /** @notice Set the minimum amount of ETH to be transfered when collecting business fees
      * @dev Mostly for testing porpuse. It should be removed in final deployment or no modifiable by anyone
      * @param newMinBusinessFeePayment new min amount of ETH to transfer to business
     */
    // Mostly for testing porpuse.
    function setminBusinessFeePayment(uint newMinBusinessFeePayment) public onlyOwner {
        minBusinessFeePayment = newMinBusinessFeePayment;
    }

    function playSoloRound(uint _choice) public payable returns(uint);

    //function playSoloRound(uint _choice1, uint _choice2) public payable returns(uint);

}