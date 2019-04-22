pragma solidity ^0.5.0;


import "./GamblingGame.sol";
import "./LotteryGame.sol";


/** @title Dice game, playing also for a jackpot.
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
  * @notice This is just a simple game for the TFM of the Master in Ethereum.
            Do not use betting real value since it may have some vulnerabilities.
            Further analysis and assurance is needed to take in production/main net.
 */
contract Dice is GamblingGame, LotteryGame {

    uint public minimumRisk = 1;
    uint public maximumRisk = 99;
    uint public feeJackpot =  5000000000000000;  // Fund to jackpot 0.005 ether as a fee

    uint constant DICE_RANDOM_RANGE = 100;

    // Events
    event GameStarted(string message);
    event logPlayerBetAccepted(address _contract, address _player, uint _risk, uint _bet);
    event logRollDice(address _contract, address _player, string _description);
    event logPlayerLose(string description, address _contract, address _player, uint _rolledDiceNumber, uint _betAmount);
    event logPlayerWins(string description, address _contract, address _winner, uint _rolledDiceNumber, uint _profit);
    event logNewOraclizeQuery(string description);
    event logContractBalance(uint _contractBalance);
    event logJackpotBalance(string description, address _ownerAddress, uint _ownerBalance);
    event logPayWinner(string description, address _playerAddress, uint _winAmount);
    event logMaxAllowedBet(string description, uint _maxAllowedBet);

    event RoundResolved(
        uint roundId,
        address winner,
        uint betAmount,
        address indexed player,
        uint choice,
        uint rolledDiceNumber,
        uint winAmount
    );


    constructor() public payable {
    }


    /** @notice Get info from rounds.
      * @dev This function is implemented mainly for debugging purpose.
             Actually getting info from front-end is managed through events.
      * @param roundId round id number that identify a round
      * @return player1Address address of player1
      * @return player1Choice secret choice of player1
      * @return betAmount amount of the bet of this round, in wei.
      * @return winner address of the winner, it's 0x0 if not finished or draw
      * @return if round is closed
    */
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

    /** @notice When we have everything ready owner can start game so anyone can play.
                Also for restarting game after having stopped it
                Call parent function and start lottery as well
    */
    function startGame() public {
        super.startGame();
        startLottery();
    }

    /** @notice Function for emergengies. Call parent function and stop lottery as well
    */
    function stopGame() public {
        super.stopGame();
        stopLottery();
    }

    /** @notice Function for calculate the profit if winning in dice game.
     * @param betAmount amount of the bet
     * @param risk risk/choice chosen by player. The higher the risk, the more profitable if winning
    */
    function calculateProfit(uint betAmount, uint risk)
    public
    view
    returns (uint)
    {
        uint jackpotFee = betAmount.mul(jackpotFeeRate) / feeUnits;
        uint businessFee = betAmount.mul(businessFeeRate) / feeUnits;

        uint riskEarnings = risk.mul(feeUnits);
        riskEarnings = riskEarnings.div(100);
        uint earningRate = (feeUnits - riskEarnings); // 0.5 * fe
        uint x = (feeUnits * feeUnits).div(earningRate);
        uint grossProfit = x.mul(betAmount);
        grossProfit = grossProfit.div(feeUnits);
        uint netProfit = grossProfit.sub(jackpotFee).sub(businessFee).sub(feeOraclize);
        return netProfit;
    }

    /**
     * @notice Test if the risk assumed by the user is the minimum accepted by the game
     * @param _risk Risk assumed by the player
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

    /**
     * @notice Function to create a round playing against the blockchain.
     * @param _choice Choice made by player
     * @return Round Id of the round
     */
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
        require(isValidBet(betAmount, minimumBet, jackpot), "Not valid bet");
        require(isValidRisk(risk, minimumRisk, maximumRisk), "Not valid risk");
        require(msg.value <= jackpot, "Bet too high");
        emit logPlayerBetAccepted(address(this), playerAddress, risk, betAmount);
        require(msg.value >= feeOraclize, "oracle cannot call me");

        // Making oraclized query to random.org.
        emit logRollDice(address(this), playerAddress, "Oraclize query to random.org was sent, standing by for the answer.");

        rounds[roundId].player1.choice = risk;
        rounds[roundId].betAmount = betAmount;
        rounds[roundId].player1.playerAddress = playerAddress;

        _setRandomness(DICE_RANDOM_RANGE, roundId);

        return roundId;
    }

    /** @notice Withdraw funds in case of an emergengy. Set jackpot to 0.
      * @param _myAddress addres to withdraw funds to
    */
    function withdrawFunds(address payable _myAddress) public {
        super.withdrawFunds(_myAddress);
        jackpot = 0;
    }

    /** @notice Resolve round, vs House 
                Pay winner if any.
      * @param _roundId id number that identify the round to resolve
     */
    function _resolveRound(uint _roundId) private {
        Round storage round = rounds[_roundId];
        uint rolledDiceNumber = round.oraclizeCallback.oraclesChoice;

        // If the number of the rolled dice is higher than the assumed risk then the player wins
        if(rolledDiceNumber > round.player1.choice) {
            round.winner = round.player1.playerAddress;
        } else {
            round.winner = address(this);
        }

        uint winAmount = _payRound(_roundId);

        emit RoundResolved(
            _roundId, round.winner,
            round.betAmount,
            round.player1.playerAddress,
            round.player1.choice,
            round.oraclizeCallback.oraclesChoice,
            winAmount
        );

        if (lotteryOn) {
            _playLottery(round.player1.playerAddress, _roundId);
            if (!round.isSolo) {
                _playLottery(round.player2.playerAddress, _roundId);
            }
        }
    }

    /** @notice Pay winner of the round resolved.
      * @param _roundId id number that identify the round to resolve
     */
    function _payRound(uint _roundId) private returns(uint) {
        Round storage round = rounds[_roundId];
        bool playerWins = round.winner == round.player1.playerAddress;
        round.isClosed = true;
        uint inititalJackpot = jackpot;
        uint initialBalance = address(this).balance;
        uint jackpotFee = round.betAmount.mul(jackpotFeeRate) / feeUnits;
        uint netProfit;

        if(playerWins) {

            // Calculate player profit
            netProfit = calculateProfit(round.betAmount, round.player1.choice);

            round.profit = netProfit;

            if(netProfit > 0) {
                require( address(this).balance >= round.betAmount, "cannot pay" );
                emit logPayWinner("Pay winner: ", round.player1.playerAddress, netProfit);
                round.player1.playerAddress.transfer(netProfit);
            }

        }
        else {
            emit logPlayerLose("Player lose: ",address(this), round.player1.playerAddress, round.oraclizeCallback.oraclesChoice, round.betAmount);
        }

        jackpot = address(this).balance;

        return netProfit;
    }

    /** @notice Play lottery for the round
      * @dev TODO: It is needed to implement a mechanism that assures that existing rounds can be paid altoudh
             someone has hit the jakpot. Curerntly if someone hits the jackpot he/she gets all value of the contract
      * @param playerAddress address of the player
      * @param _roundId id number that identify the round to resolve
      * @return if player wins the lottery or not
     */
    function _playLottery(address payable playerAddress, uint _roundId) private returns (bool) {
        Round storage myRound = rounds[_roundId];  // Pointer to round
        if ((uint(keccak256(abi.encodePacked(roundCount, playerAddress, blockhash(block.number - 1), myRound.oraclizeCallback.queryResult)))
            % lotteryRate) == 0) {
            require(myRound.lotteryWinner == address(0), "Only one loterry winner per round");
            myRound.lotteryWinner = playerAddress;
            _payLotteryWinner(playerAddress, myRound.betAmount);
            return true;
        }
        return false;
    }

}