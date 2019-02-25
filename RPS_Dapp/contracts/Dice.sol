pragma solidity ^0.5.0;

import "./Ownable.sol";
import "./oraclizeAPI.sol";
import "./SafeMath.sol";
import "./DiceLib.sol";
import "./StartStopGame.sol";


/** @title Dice - Dice game
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
 */

contract Dice is usingOraclize, Ownable, StartStopGame {

    using SafeMath for uint;

    bool public emergencyStop;
    
    modifier noEmergency 
    { 
        if (!emergencyStop) 
        _;
    }
    
    modifier inEmergency 
    {
        if (emergencyStop) 
        _;
    }

    uint public minimumBet = 0.0001 ether;
    uint public minimumRisk = 30;
    uint public maximumRisk = 95;    
    uint public jackpot = 0;
    
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
     mapping (address => uint) private balances;

    // Events
    event logPlayerBetAccepted(address _contract, address _player, uint _risk, uint _bet);
    event logRollDice(address _contract, address _player, string _description);
    event logRolledDiceNumber(address _contract, bytes32 _oraclizeQueryId, uint _risk, uint _rolledDiceNumber);
    event logPlayerLose(string description, address _contract, address _player, uint _rolledDiceNumber, uint _betAmount);
    event logPlayerWins(string description, address _contract, address _winner, uint _rolledDiceNumber, uint _profit, uint _riskPer, uint _grossP);
    event logGameStatus(bool _status);
    event logNewOraclizeQuery(string description);
    event logContractBalance(uint _contractBalance);
    event logJackpotBalance(string description, address _ownerAddress, uint _ownerBalance);
    event logPayWinner(string description, address _playerAddress, uint _winAmount);


    constructor() 
    public
    {
        // Replace the next line with your version:
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        setGameStatus(true);
        emit logGameStatus(getGameStatus());

    }

    function rollDice(uint risk) 
        public 
        noEmergency
        gameIsOn
        payable
        returns (bool success)
    {
        
        bytes32 oraclizeQueryId;        
        address payable player = msg.sender;                

        uint betAmount = msg.value;        
        require(DiceLib.isValidBet(betAmount, minimumBet));
        require(DiceLib.isValidRisk(risk, minimumRisk, maximumRisk));
        emit logPlayerBetAccepted(address(this), player, risk, betAmount);

        // Making oraclized query to random.org.
        emit logRollDice(address(this), player, "Oraclize query to random.org was sent, standing by for the answer.");
        oraclizeQueryId = oraclize_query("URL", "https://www.random.org/integers/?num=1&min=1&max=100&col=1&base=10&format=plain&rnd=new");

        // Saving the struct        
        oraclizeCallbacks[oraclizeQueryId].queryId = oraclizeQueryId;
        oraclizeCallbacks[oraclizeQueryId].player = player;
        oraclizeCallbacks[oraclizeQueryId].risk = risk;
        oraclizeCallbacks[oraclizeQueryId].betAmount = betAmount;

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
        uint grossProfit;
        uint netProfit;
        uint riskPercentage;
        uint feeUnits = 1000000000000000000;
        uint feeJackpot =  5000000000000000;  // Fund to jackpot 0.005 ether as a fee
        uint feeOraclize = 4000000000000000; // Oraclize service charges 0.004 Ether as a fee for querying random.org

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
            riskPercentage = feeUnits.mul(risk); 
            riskPercentage = riskPercentage.div(100);
            grossProfit = betAmount.mul(riskPercentage);
            grossProfit = grossProfit.div(feeUnits);               
            netProfit = grossProfit.sub(feeJackpot);
            netProfit = netProfit.sub(feeOraclize);

            oraclizeCallbacks[myid].profit = netProfit;  
            emit logPlayerWins("Player wins: ", address(this), player, rolledDiceNumber, netProfit, riskPercentage, grossProfit );

            // Increase jackpot
            balances[owner] = balances[owner].add(feeJackpot);
            emit logJackpotBalance("Balance owner: ", owner, balances[owner]);            

             if(netProfit > 0) {             
                 payWinner(player, betAmount, netProfit);          
             }
            
         }

         if(playerWins==false) {
             emit logPlayerLose("Player lose: ",address(this), player, rolledDiceNumber, betAmount);
        }

    }

  
    function getContractBalance()
        public
        view
        returns (uint)
    {
        return (address(this).balance);
    }

 
    /** 
     * @notice Fallback function - Called if other functions don't match call or sent ether without data
     * Typically, called when invalid data is sent
     * Added so ether sent to this contract is reverted if the contract fails. Otherwise, the sender's money is transferred to contract
     */
    function () external payable{ 
        revert();        
    }

    function payWinner(address payable _player, uint _betAmount, uint _netProfit) 
    private 
    {
        uint winAmount = _betAmount.add(_netProfit);
        require( address(this).balance >= winAmount );
        emit logPayWinner("Pay winner: ", _player, winAmount);            
        _player.transfer(winAmount);
    }

}