pragma solidity ^0.5.0;


import "./GamblingGame.sol";
import "./oraclizeAPI.sol";
import "./LotteryGame.sol";
//import "./StartStopGame.sol";


/** @title Dice - Dice game
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
 */

contract Dice is usingOraclize, GamblingGame, LotteryGame {

    using SafeMath for uint;

    // uint public minimumBet = 0.0001 ether;
    uint public minimumRisk = 30;
    uint public maximumRisk = 95;
    uint public feeJackpot =  5000000000000000;  // Fund to jackpot 0.005 ether as a fee

    uint public jackpot = 0;

    struct Player {
        uint choice;
        bytes32 secretChoice;
        address payable playerAddress;
    }

    struct Round {
        Player player1;
        Player player2;
        uint betAmount;
        address payable winner;
        bool isClosed;
        address lotteryWinner;
    }

    // All oraclize calls will result in a common callback to __callback(...).
    struct oraclizeCallback {
        address payable player;
        bytes32 queryId;
        uint    risk;
        uint    betAmount;
        uint    rolledDiceNumber;
        uint    profit;
    }

     mapping (bytes32 => oraclizeCallback) public oraclizeCallbacks;

    // Events
    event logPlayerBetAccepted(address _contract, address _player, uint _risk, uint _bet);
    event logRollDice(address _contract, address _player, string _description);
    event logRolledDiceNumber(address _contract, bytes32 _oraclizeQueryId, uint _risk, uint _rolledDiceNumber);
    event logPlayerLose(string description, address _contract, address _player, uint _rolledDiceNumber, uint _betAmount);
    event logPlayerWins(string description, address _contract, address _winner, uint _rolledDiceNumber, uint _profit);
    event logNewOraclizeQuery(string description);
    event logContractBalance(uint _contractBalance);
    event logJackpotBalance(string description, address _ownerAddress, uint _ownerBalance);
    event logPayWinner(string description, address _playerAddress, uint _winAmount);
    event logMaxAllowedBet(string description, uint _maxAllowedBet);


    constructor()
    public
    {
        // Replace the next line with your version:
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        // set Oraclize proof type
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        gameRunning = true;
    }

    /**
    * @notice Callback function to emit the events with the information we want.
    * @dev Get the querys using the parameter myid
    * @param myid The id of the query
    * @param result The result of the query
    */
    function __callback(bytes32 myid, string memory result, bytes memory proof) 
    public
    {
        

        bool playerWins = false;     
          

        require (msg.sender == oraclize_cbAddress());
        
        address payable player = oraclizeCallbacks[myid].player;       
        uint rolledDiceNumber = parseInt(result); 
        oraclizeCallbacks[myid].rolledDiceNumber = rolledDiceNumber;   
        uint risk = oraclizeCallbacks[myid].risk;
        uint betAmount = oraclizeCallbacks[myid].betAmount;     
        emit logRolledDiceNumber(address(this), myid, risk, rolledDiceNumber);


         // If the number of the rolled dice is higher than the assumed risk then the player wins
         if(rolledDiceNumber > risk) {
             playerWins = true;
        }
           
        if(playerWins) {
            
            // Calculate player profit    
            uint netProfit = calculateProfit(betAmount, risk);
 
            oraclizeCallbacks[myid].profit = netProfit;  
            emit logPlayerWins("Player wins: ", address(this), player, rolledDiceNumber, netProfit);

            // Increase jackpot
            // balances[owner()] = balances[owner()].add(feeJackpot);
            // emit logJackpotBalance("Balance owner: ", owner(), balances[owner()]);            

             if(netProfit > 0) {             
                 payWinner(player, betAmount, netProfit);          
             }
            
         }

         if(playerWins==false) {
             emit logPlayerLose("Player lose: ",address(this), player, rolledDiceNumber, betAmount);
        }

    }

    // /**
    //  * @notice sendMoney function is equivalent to fallback function
    //  * The sender's money is transferred to contract
    //  */
    // function sendMoney() public payable{ 
    // }

    function calculateProfit(uint betAmount, uint risk)
    private
    view
    returns (uint)
    {
        uint grossProfit;
        uint netProfit;
        uint riskPercentage;
        uint feeUnits = 1000000000000000000;
        uint feeOraclize = 4000000000000000; // Oraclize service charges 0.004 Ether as a fee for querying random.org

        riskPercentage = feeUnits.mul(risk); 
        riskPercentage = riskPercentage.div(100);
        grossProfit = betAmount.mul(riskPercentage);
        grossProfit = grossProfit.div(feeUnits);               
        netProfit = grossProfit.sub(feeJackpot);
        netProfit = netProfit.sub(feeOraclize);

        return (netProfit);

    }

    function payWinner(address payable _player, uint _betAmount, uint _netProfit) 
    private
    {
        uint winAmount = _betAmount.add(_netProfit);
        require( address(this).balance >= winAmount );
        emit logPayWinner("Pay winner: ", _player, winAmount);            
        _player.transfer(winAmount);
    }

    /**
     * @notice Test if the risk assumed by the user is the minimum accepted by the game
     * @param _risk : Risk assumed by the player
     * @param _minimumRisk Indicates the minimum risk accepted to play the game
     * @return True if the risk is over 30, False otherwise.
     */
    function isValidRisk (uint _risk, uint _minimumRisk, uint _maximumRisk)
        internal
        pure
        returns (bool)
    {
        return ((_risk > _minimumRisk) && (_risk <= _maximumRisk));
    }

    function playSoloRound(uint _choice) public payable gameIsOn(true) returns(uint) {
        uint risk = _choice;
        bytes32 oraclizeQueryId;
        address payable player = msg.sender;

        uint betAmount = msg.value;
        uint netPossibleProfit = calculateProfit(betAmount, risk);
        uint maximumBet = address(this).balance.sub(netPossibleProfit).div(2);

        emit logMaxAllowedBet("Maximum bet accepted: ", maximumBet);

        require(betAmount < address(this).balance);
        require(isValidBet(betAmount, minimumBet, maximumBet));
        require(isValidRisk(risk, minimumRisk, maximumRisk));
        emit logPlayerBetAccepted(address(this), player, risk, betAmount);

        // Making oraclized query to random.org.
        emit logRollDice(address(this), player, "Oraclize query to random.org was sent, standing by for the answer.");
        // oraclizeQueryId = oraclize_query("URL", "https://www.random.org/integers/?num=1&min=1&max=100&col=1&base=10&format=plain&rnd=new");
        oraclizeQueryId = oraclize_query("URL", "BA7vPyUltcy7z2vcvEA/BRCsjT1HicOkfyGReC7pcm+a+l0eTzv+gs7igzBF5LNGZG8LuOCfKKQY3hfRRWZ4VesMwWu7IrFrvHSeVI/ToLIxg62H9uujPvwcHqprCBM2vmtATUWmOExfnbe8Lbywedvh/R8mHfE83KMitNz5WC7/bIZRctSufbtGF+uLaoEiLJejjqT5CUl8XKQ2+KG2YCjJine1Sod0");

        // Saving the struct
        oraclizeCallbacks[oraclizeQueryId].queryId = oraclizeQueryId;
        oraclizeCallbacks[oraclizeQueryId].player = player;
        oraclizeCallbacks[oraclizeQueryId].risk = risk;
        oraclizeCallbacks[oraclizeQueryId].betAmount = betAmount;

        return 1;
    }

    function _resolveRound(uint _roundId) private {
        uint i = 9;
    }

    function _payRound(uint _roundId) private {
        uint i = 9;
    }

    function _playLottery(address payable playerAddress, uint _roundId) private returns (bool) {
        return false;
    }


}