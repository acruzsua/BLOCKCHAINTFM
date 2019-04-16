pragma solidity >=0.5;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./oraclizeAPI.sol";


/** @title Abstract contract Gambling that define the structure for building
           gambling games on Ethereum
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
  * @notice This is just a simple game for the TFM of the Master in Ethereum.
            Do not use betting real value since it may have some vulnerabilities.
            Further analysis and assurance is needed to take in production/main net.
 */
contract GamblingGame is Ownable, usingOraclize {
    using SafeMath for uint;


    uint constant lotteryRate = 1000;

    bool public gameRunning = false;
    uint public minimumBet = 0.0001 ether;

    // Oraclize service charges 0.004 Ether as a fee for querying random.org, two queries
    uint feeOraclize = 0.008 ether;

    /* Not used yet
    uint maxJackpot;
    */

    // Since we can't use decimals, represent the rate as ppm (part-per-million)
    // Used constant that saves gas, but it might be a good idea to set it as public
    // and be able to adjust the fee rate.
    // Set them as constants althoug we could make them public vars
    uint constant jackpotFeeRate = 5000;
    uint constant feeUnits = 1000000;
    uint businessFeeRate = 2 * lotteryRate;
    uint public totalBusinessFee = 0;
    uint public minBusinessFeePayment = 0.01 ether;
    address payable public businessAddress = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;  // Ethereum foundation address

    uint public roundCount;
    uint public gameRandomRange;

    struct Player {
        uint choice;
        bytes32 secretChoice;
        address payable playerAddress;
    }

    struct OraclizeCallback {
        uint    oraclesChoice;
        uint    queryResult;
        uint    secretQueryResult;
    }

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
    event LogGetRandomness(string message, bytes32 queryId);
    event LogGameRandomValue(uint _rolledDiceNumber);

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
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }

    /** @notice When we have everything ready owner can start game so anyone can play.
                Also for restarting game after having stopped it
    */
    function startGame() public onlyOwner gameIsOn(false){
        gameRunning = true;
        emit GameStarted("game started");
    }

    /** @notice Function for emergengies.
    */
    function stopGame() public onlyOwner gameIsOn(true){
        gameRunning = false;
    }

    /** @notice Withdraw funds in case of an emergengy.
      * @param _myAddress addres to withdraw funds to
    */
    function withdrawFunds(address payable _myAddress) public onlyOwner gameIsOn(false) {
        _myAddress.transfer(address(this).balance);
    }

    /** @notice Set the minimum amount of ETH to be transfered when collecting business fees
      * @dev Mostly for testing porpuse. It should be removed in final deployment or no modifiable by anyone
      * @param newMinBusinessFeePayment new min amount of ETH to transfer to business
     */
    // Mostly for testing porpuse.
    function setminBusinessFeePayment(uint newMinBusinessFeePayment) public onlyOwner {
        minBusinessFeePayment = newMinBusinessFeePayment;
    }

    /**
     * @notice Abstract function to create a round playing against the blockchain.
     *         Each game would have a different implementation
     * @param _choice Choice made by player
     * @return Round Id of the round
     */
    function playSoloRound(uint _choice) public payable returns(uint);

    /**
     * @notice Abstract method to resolve round. Each game would have a different implementation
     * @param _roundId Round id of the round to resolve
     */
    function _resolveRound(uint _roundId) private;

    /**
     * @notice Abstract method for doing the payment. Each game would have a different implementation
     * @param _roundId Round id of the round to resolve
     * @return Amount to pay
     */
    function _payRound(uint _roundId) private returns (uint);

    /**
     * @notice Method to set the result from the Oracle.
     * @param myid Id that identifies the oraclize call
     * @param oraclizeResult Result for the oraclize's call
     */
    function _setResult(bytes32 myid, uint oraclizeResult) private{
        uint roundId = 0;

        if (queryIdToRounds[myid] != 0) {
            roundId = queryIdToRounds[myid];
        } else if (secretQueryIdToRounds[myid] != 0) {
            roundId = secretQueryIdToRounds[myid];
        }

        Round storage round = rounds[roundId];

        if (queryIdToRounds[myid] != 0) {
            round.oraclizeCallback.queryResult = oraclizeResult;
        } else if (secretQueryIdToRounds[myid] != 0) {
            round.oraclizeCallback.secretQueryResult = oraclizeResult;
        }

        if (round.oraclizeCallback.queryResult != 0 && round.oraclizeCallback.secretQueryResult != 0) {
            uint gameValue = (round.oraclizeCallback.queryResult ^ round.oraclizeCallback.secretQueryResult) % gameRandomRange;
            round.oraclizeCallback.oraclesChoice = gameValue;
            round.player2.choice = gameValue;
            _resolveRound(roundId);
            emit LogGameRandomValue(gameValue);
        }
    }

    /**
    * @notice Callback function to emit the events with the information we want.
    * @dev Get the querys using the parameter myid
    * @param myid The id of the query
    * @param result The result of the query
    * @param proof Necessary for validating Oraclize's call
    */
    function __callback(bytes32 myid, string memory result, bytes memory proof)
    public
    {
        require (msg.sender == oraclize_cbAddress(), "Denied access to callback function, oracle only allowed");
        _setResult(myid, parseInt(result));

    }

    /**
     * @notice Test if the player's bet is at least the minium required for playing
     * @param _bet Indicates the bet risked by the user
     * @param _minimumBet Indicates the minimum bet accepted to play the game
     * @param _maximumBet Indicates the maximum bet accepted to play the game
     * @return True if player's bet is at least equal to the minimum expected to allow the game, False otherwise.
     */
    function isValidBet (uint _bet, uint _minimumBet, uint _maximumBet)
        internal
        pure
        returns (bool)
    {
        return ((_bet >= _minimumBet) && (_bet < _maximumBet) );
    }

    /**
     * @notice Function to define the randomness by calling Oraclize.
     * @param _range Range of the final random number desired
     * @param _roundId Round id of the round to resolve
     * @dev Two calls to Oraclize. One public and the other secret for gaingin security, and at the same time
            assuring real randomness.
     */
    function _setRandomness(uint _range, uint _roundId) internal {
        bytes32 oraclizeSecretQueryId = oraclize_query("URL", "BDVuL2h1Al3C/zIvNr0nFUXkHv+X8Wl3whR/asB3fehTAY4VUM6gE44dMqNrCzXhzaxQUUR+ZKPT/eZ/qvf4636ieLozGlzH+d1DMa2kaKIPj+hjb+pTUKFxoWOhy621klv3W3C6yOpWPsVwMLr1TnMgHR7i6GUi1x347umiPmBGtVuxZpzhFOWPUcszJAJK6l7s3eGtRt3wivBjxEQCIgDC3fJVGo5Z+DHT+syWKw==");
        bytes32 oraclizeQueryId = oraclize_query("URL", "https://www.random.org/integers/?num=1&min=0&max=1000000000&col=1&base=10&format=plain&rnd=new");
        queryIdToRounds[oraclizeQueryId] = _roundId;
        secretQueryIdToRounds[oraclizeSecretQueryId] = _roundId;
        gameRandomRange = _range;
        emit LogGetRandomness("getting randomness", oraclizeQueryId);
    }

}