pragma solidity ^0.5.0;

import "./Ownable.sol";
import "./oraclizeAPI.sol";
import "./SafeMath.sol";


/** @title Dice - Dice game
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
 */

contract Dice is usingOraclize, Ownable {

    uint minimumBet;
    string public RANDOMNUMBER;


    // The oraclize callback structure: we use several oraclize calls.
    // All oraclize calls will result in a common callback to __callback(...).
    // To keep track of the different queries we the struct callback struct in place.

    struct oraclizeCallback {
        address player;
        bytes32 queryId;
        uint    risk;
        uint    betAmount;
        uint    rolledDiceNumber;
        uint    winAmount;
    }

     mapping (bytes32 => oraclizeCallback) public oraclizeCallbacks;

    // Events
    event logPlayerBetAccepted(address _contract, address _player, uint _risk, uint _bet);
    event logRollDice(address _contract, address _player, string _description);
    event logNumberGeneratorQuery(address _contract, address _player, bytes32 _randomOrgQueryId);
    event logAwaitingRandomOrgCallback(address _contract, bytes32 _randomOrgQueryId);
    event logRandomOrgCallback(address _contract, bytes32 _oraclizeQueryId);
    event logNumberGeneratorResponse(address _contract, address _player, bytes32 _oraclizeQueryId, string _oraclizeResponse);
    event logRolledDiceNumber(address _contract, bytes32 _oraclizeQueryId, uint _risk, uint _rolledDiceNumber);
    event logDidNotWin(address _contract, uint _rolledDiceNumber, uint _risk);
    event logPlayerWins(address _contract, address _winner, uint _rolledDiceNumber, uint _winAmount);
    event logPlayerCashout(address _contract, address _winner, uint _rolledDiceNumber, uint _winAmount);
    event logGameFinalized(address _contract);
    event logNewOraclizeQuery(string description);

    constructor() 
        public
    {
        // Replace the next line with your version:
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        minimumBet = 0.0001 ether;
    }


    function rollDice(uint risk) 
        public 
        payable
        returns (bool success)
    {
        
        bytes32 oraclizeQueryId;
        
        address player = msg.sender;                
        uint betAmount = msg.value;
        
        require(betAmount >= minimumBet);

        emit logPlayerBetAccepted(address(this), player, risk, betAmount);
        emit logRollDice(address(this), player, "Query to random.org was sent, standing by for the answer.");


        if(risk > 20 ) {

            // Making oraclized query to random.org.
            if (oraclize_getPrice("URL") > address(this).balance) {
              emit logNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            } else{
              emit logNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
              oraclizeQueryId = oraclize_query("URL", "https://www.random.org/integers/?num=1&min=1&max=100&col=1&base=10&format=plain&rnd=new");
            }


            // Saving the struct
            
            oraclizeCallbacks[oraclizeQueryId].queryId = oraclizeQueryId;
            oraclizeCallbacks[oraclizeQueryId].player = player;
            oraclizeCallbacks[oraclizeQueryId].risk = risk;
            oraclizeCallbacks[oraclizeQueryId].betAmount = betAmount;

            emit logNumberGeneratorQuery(address(this), player, oraclizeQueryId);
 
 
        } else {
            
            // revert the money to the player  if the risk is < 20
            msg.sender.transfer(msg.value);

        }
      
        emit logAwaitingRandomOrgCallback(address(this), oraclizeQueryId);
        return true;
    }


   /**
    * @notice Callback function to emit the events with the information we want.
    * @dev Get the querys using the parameter myid
    * @param myid The id of the query
    * @param result The result of the query
    */

    function __callback(bytes32 myid, string memory result) 
        public
    {
        

        bool playerWins = false;       
        uint winAmount;
    
        emit logRandomOrgCallback(address(this), myid);
        require (msg.sender == oraclize_cbAddress());
        
        address player = oraclizeCallbacks[myid].player;


        emit logNumberGeneratorResponse(address(this), msg.sender, myid, result);
        
        uint rolledDiceNumber = parseInt(result); 
        oraclizeCallbacks[myid].rolledDiceNumber = rolledDiceNumber;   
        uint risk = oraclizeCallbacks[myid].risk;
        uint betAmount = oraclizeCallbacks[myid].betAmount;     
        emit logRolledDiceNumber(address(this), myid, risk, rolledDiceNumber);


        if(rolledDiceNumber > risk) {
            playerWins = true;
        }
    
        
        if(playerWins) {
            
            // Calculate player profit

    //        if(risk > 20 && risk < 30) {
    //                winAmount = betAmount.mul(107);
    //                winAmount = winAmount.div(100);
    //        }
            if(risk > 30 && risk < 40) {
                    winAmount = (betAmount * 142) / 100;
            }
            if(risk > 40 && risk < 50) {
                    winAmount = (betAmount * 195) / 100;
            }
            if(risk > 50 && risk < 60) {
                    winAmount = (betAmount * 293) / 100;
            }
            if(risk > 60 ) {
                    winAmount = (betAmount * 589) / 100;
            }

            emit logPlayerWins(address(this), player, rolledDiceNumber, winAmount);

            if(winAmount > 0) {

                // Substract the casino edge 4% and pay the winner..
                
                uint casino_edge = (winAmount / 100) * 4;
                uint oraclize_fee = 4000000000000000; // Oraclize service charges us a fee of 0.004 Ether for querying random.org on the blockchain
                
                winAmount = winAmount - casino_edge;
                winAmount = winAmount - oraclize_fee;

                (msg.sender).transfer(winAmount);

                oraclizeCallbacks[myid].winAmount = winAmount;

                emit logPlayerCashout(address(this), player, rolledDiceNumber, winAmount);
            
            }
            
        }

        if(playerWins==false) {

            emit logDidNotWin(address(this), rolledDiceNumber, risk);
            emit logGameFinalized(address(this));
            //address(this).balance = (address(this).balance).sub(msg.value);
        }

    }

    function gameStatus(bytes32 oraclizeQueryId)
        public
        view
        returns (address, uint, uint, uint, uint)
    {

        address player = oraclizeCallbacks[oraclizeQueryId].player;
        uint risk = oraclizeCallbacks[oraclizeQueryId].risk;
        uint rolledDiceNumber = oraclizeCallbacks[oraclizeQueryId].rolledDiceNumber;
        uint betAmount = oraclizeCallbacks[oraclizeQueryId].betAmount;
        uint winAmount = oraclizeCallbacks[oraclizeQueryId].winAmount;

        return (player, risk, rolledDiceNumber, betAmount, winAmount);
    }


    function getContractBalance()
        public
        view
        returns (uint)
    {
        return (address(this).balance);
    }

}