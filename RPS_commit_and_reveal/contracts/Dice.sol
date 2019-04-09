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

    uint constant DICE_RANDOM_RANGE = 100;

    event GameStarted(string message);

    // Events
    event logPlayerBetAccepted(address _contract, address _player, uint _risk, uint _bet);
    event logRollDice(address _contract, address _player, string _description);

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
        OAR = OraclizeAddrResolverI(0x18C0cAb11428daf78bF6Fcc0fcb8Dea742ab715D);
        // set Oraclize proof type
        //oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }

    function startGame() public {
        super.startGame();
        startLottery();
    }

    function stopGame() public {
        super.stopGame();
        stopLottery();
    }

    function getRoundInfo(
        uint roundId
    )
        external
        view
        returns(
            address playerAddress,
            uint risk,
            uint betAmount,
            uint rolledDiceNumber,
            address payable winner,
            bool isClosed
        )
    {
        Round memory myRound = rounds[roundId];
        return (
            myRound.player1.playerAddress,
            myRound.player1.choice,
            myRound.betAmount,
            myRound.oraclizeCallback.oraclesChoice,
            myRound.winner,
            myRound.isClosed
        );
    }

    function calculateProfit(uint betAmount, uint risk)
    private
    view
    returns (uint)
    {
        uint feeOraclize = 0.004 ether; // Oraclize service charges 0.004 Ether as a fee for querying random.org

        uint grossProfit = betAmount.mul(risk).div(100);

        uint jackpotFee = betAmount.mul(jackpotFeeRate) / feeUnits;
        uint businessFee = betAmount.mul(businessFeeRate) / feeUnits;

        uint netProfit = grossProfit.sub(jackpotFee).sub(businessFee).sub(feeOraclize);
        return (netProfit);

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

        roundCount++;
        uint roundId = roundCount;

        uint risk = _choice;
        // bytes32 oraclizeQueryId;
        address payable playerAddress = msg.sender;

        uint betAmount = msg.value;
        uint netPossibleProfit = calculateProfit(betAmount, risk);
        uint maximumBet = address(this).balance.sub(netPossibleProfit).div(2);

        emit logMaxAllowedBet("Maximum bet accepted: ", maximumBet);

        require(betAmount < address(this).balance, "Not enough balance for this bet");
        require(isValidBet(betAmount, minimumBet, maximumBet), "Not valid bet");
        require(isValidRisk(risk, minimumRisk, maximumRisk), "Not valid risk");
        emit logPlayerBetAccepted(address(this), playerAddress, risk, betAmount);
        require(msg.value >= 0.004 ether, "oracle cannot call me");

        // Making oraclized query to random.org.
        emit logRollDice(address(this), playerAddress, "Oraclize query to random.org was sent, standing by for the answer.");

        // rounds[roundId].risk = risk;
        rounds[roundId].player1.choice = risk;
        rounds[roundId].betAmount = betAmount;
        rounds[roundId].player1.playerAddress = playerAddress;

        _setRandomness(DICE_RANDOM_RANGE, roundId);

        return roundId;
    }

    function _resolveRound(uint _roundId) private {
        Round storage round = rounds[_roundId];
        uint rolledDiceNumber = round.oraclizeCallback.oraclesChoice;

        // If the number of the rolled dice is higher than the assumed risk then the player wins
        if(rolledDiceNumber > round.player1.choice) {
            round.winner = round.player1.playerAddress;
        } else {
            round.winner = address(this);
        }

        _payRound(_roundId);
    }

    function _checkWinner(Player memory player1, Player memory player2) private pure returns(address payable) {
        if ((uint(player1.choice) + 1) % 3 == uint(player2.choice)) {
            return player2.playerAddress;
        } else if ((uint(player1.choice) + 2) % 3 == uint(player2.choice)) {
            return player1.playerAddress;
        } else {
            return address(0);
        }
    }

    function _payRound(uint _roundId) private {
        Round storage round = rounds[_roundId];
        bool playerWins = round.winner == round.player1.playerAddress;
        round.isClosed = true;
        if(playerWins) {

            // Calculate player profit
            uint netProfit = calculateProfit(round.betAmount, round.player1.choice);

            round.profit = netProfit;
            //emit logPlayerWins("Player wins: ", address(this), round.player1.playerAddress, round.rolledDiceNumber, netProfit);

            if(netProfit > 0) {
                // payWinner(round.player1.playerAddress, round.betAmount, netProfit);
                uint winAmount = round.betAmount.add(netProfit);
                require( address(this).balance >= round.betAmount, "cannot pay" );
                emit logPayWinner("Pay winner: ", round.player1.playerAddress, round.betAmount);
                round.player1.playerAddress.transfer(winAmount);
            }

         }

         if(playerWins==false) {
             emit logPlayerLose("Player lose: ",address(this), round.player1.playerAddress, round.oraclizeCallback.oraclesChoice, round.betAmount);
        }
    }

    function _playLottery(address payable playerAddress, uint _roundId) private returns (bool) {
        return false;
    }


    function _setResult(bytes32 myid, uint oraclizeResult) private
    {
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

        // emit logRolledDiceNumber(oraclizeResult);
        // emit logRolledDiceNumberBefore(round.queryResult);
        // emit logRolledDiceNumberBeforeS(round.secretQueryResult);
        // emit logRoundIdIs(queryIdToRounds[myid]);
        // emit logRoundIdIsS(secretQueryIdToRounds[myid]);

        if (round.oraclizeCallback.queryResult != 0 && round.oraclizeCallback.secretQueryResult != 0) {
            uint rolledDiceNumber = (round.oraclizeCallback.queryResult ^ round.oraclizeCallback.secretQueryResult) % gameRandomRange;
            round.oraclizeCallback.oraclesChoice = rolledDiceNumber;
            _resolveRound(roundId);
            emit logRolledDiceNumberAfter(rolledDiceNumber);
        }
    }
}