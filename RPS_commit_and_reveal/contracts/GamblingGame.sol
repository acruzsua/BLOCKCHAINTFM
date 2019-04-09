pragma solidity >=0.5;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./oraclizeAPI.sol";

/** @title RPS - RockPaperScissor P2P game, playing also for a jackpot.
  * @author rggentil
  * @notice This is just a simple game done mostly for learning solidity
            and web3 development, do not use betting real value since
            it has some known vulnerabilities.
  * @dev My first smartcontract, so probably code could be improved.
 */
contract GamblingGame is Ownable, usingOraclize {
    using SafeMath for uint;

    uint constant LOTERY_RATE = 1000;

    bool public gameRunning;

    uint public minimumBet = 0.0001 ether;

    /* Not used yet
    uint maxJackpot;
    */

    // Since we can't use decimals, represent the rate as ppm (part-per-million)
    // Used constant that saves gas, but it might be a good idea to set it as public
    // and be able to adjust the fee rate.
    // Set them as constants althoug we could make them public vars
    uint constant jackpotFeeRate = 5000;
    uint constant feeUnits = 1000000;
    uint businessFeeRate = 2 * LOTERY_RATE;
    uint public totalBusinessFee = 0;
    uint public minBusinessFeePayment = 0.01 ether;
    address payable public businessAddress = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;  // Ethereum foundation address

    uint public roundCount;

    // uint public oraclizeResult;
    uint public gameRandomRange;

    struct Player {
        uint choice;
        bytes32 secretChoice;
        address payable playerAddress;
    }

    struct OraclizeCallback {
        // bytes32 queryId;
        uint    oraclesChoice;
        uint    queryResult;
        uint    secretQueryResult;
    }

    // All oraclize calls will result in a common callback to __callback(...).
    struct Round {
        Player player1;
        Player player2;
        uint betAmount;
        address payable winner;
        bool isClosed;
        bool isSolo;
        address lotteryWinner;
        uint currentJackpot;
        uint profit;
        OraclizeCallback oraclizeCallback;
    }

    mapping (bytes32 => uint) public queryIdToRounds;
    mapping (bytes32 => uint) public secretQueryIdToRounds;

    mapping (uint => Round) rounds;

    event Payment(address paidAddress, uint amount);
    event GameStarted(string message);

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
        emit GameStarted("game started");
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

    function _setResult(bytes32 myid, uint oraclizeResult) private;

    event logRolledDiceNumber(uint _rolledDiceNumber);
    event logRolledDiceNumberBefore(uint _rolledDiceNumber);
    event logRolledDiceNumberBeforeS(uint _rolledDiceNumber);
    event logRolledDiceNumberAfter(uint _rolledDiceNumber);
    event logRoundIdIs(uint roundId);
    event logRoundIdIsS(uint roundId);

    /**
    * @notice Callback function to emit the events with the information we want.
    * @dev Get the querys using the parameter myid
    * @param myid The id of the query
    * @param result The result of the query
    */
    function __callback(bytes32 myid, string memory result)
    public
    {
        require (msg.sender == oraclize_cbAddress(), "Denied access to callback function, oracle only allowed");
        _setResult(myid, parseInt(result));

    }

    event LogGetRandomness(string message, bytes32 queryId);
    function _setRandomness(uint _range, uint _roundId) internal {
        bytes32 oraclizeSecretQueryId = oraclize_query("URL", "BDVuL2h1Al3C/zIvNr0nFUXkHv+X8Wl3whR/asB3fehTAY4VUM6gE44dMqNrCzXhzaxQUUR+ZKPT/eZ/qvf4636ieLozGlzH+d1DMa2kaKIPj+hjb+pTUKFxoWOhy621klv3W3C6yOpWPsVwMLr1TnMgHR7i6GUi1x347umiPmBGtVuxZpzhFOWPUcszJAJK6l7s3eGtRt3wivBjxEQCIgDC3fJVGo5Z+DHT+syWKw==");
        bytes32 oraclizeQueryId = oraclize_query("URL", "https://www.random.org/integers/?num=1&min=0&max=1000000000&col=1&base=10&format=plain&rnd=new");
        queryIdToRounds[oraclizeQueryId] = _roundId;
        secretQueryIdToRounds[oraclizeSecretQueryId] = _roundId;
        gameRandomRange = _range;
        emit LogGetRandomness("getting randomness", oraclizeQueryId);
    }

}