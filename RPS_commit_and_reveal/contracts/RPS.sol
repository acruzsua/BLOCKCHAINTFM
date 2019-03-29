pragma solidity >=0.5;

import "./P2PGamblingGame.sol";
import "./LotteryGame.sol";


/** @title RPS - RockPaperScissor P2P game, playing also for a jackpot.
  * @author rggentil
  * @notice This is just a simple game done mostly for learning solidity
            and web3 development, do not use betting real value since
            it has some known vulnerabilities.
  * @dev My first smartcontract, so probably code could be improved.
 */
contract RPS is P2PGamblingGame, LotteryGame {

    using SafeMath for uint;

    uint public roundCount;

    /* Not used yet
    uint maxJackpot;
    */

    enum Choice { Rock, Paper, Scissors }

    struct Player {
        Choice choice;
        bytes32 secretChoice;
        address payable playerAddress;
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
    }

    mapping(uint=>Round) rounds;

    // We could add another mapping to check rounds per address:
    // mapping(address=>uint[])

    modifier isChoice(uint choice) {
        require(choice <= uint(Choice.Scissors), "RPS choice not valid");
        _;
    }

    event RoundCreated(
        uint roundId,
        uint betAmount,
        address indexed player1,
        bool isSolo
    );

    event RoundResolved(
        uint roundId,
        address winner,
        uint betAmount,
        address indexed player1,
        Choice choice1,
        address player2,
        Choice choice2
    );

    event Secret(bytes32 secret);

    event BusinessPayment(address businessAddress, uint payment);

    constructor() public payable {
        // We could handle games through constructor and setting variables like
        // minimum bet, max jackpot, fees, etc.
    }

    /** @notice Get info from rounds.
                TODO: This function should be removed in final deployment because
                it facilitates getting other player's choice before betting.
      * @dev This function is implemented mainly for debugging purpose.
             Actually getting info from front-end is managed through events.
      * @param roundId round id number that identify a round
      * @return player1Address address of player1
      * @return player1Choice choice of player1
      * @return player2Address address of player2
      * @return player2Choice choice of player2
      * @return betAmount amount of the bet of this round, in wei.
      * @return winner address of the winner, it's 0x0 if not finished or draw
      TODO: THIS CAN'T BE ACCESSIBLE BECAUSE ANYAONE COULD KNOW THE CHOICES JUST
            REQUESTING THIS FUNCTION
    */
    function getRoundInfo(
        uint roundId
    )
        external
        view
        returns(
            address player1Address,
            Choice player1Choice,
            address player2Address,
            Choice player2Choice,
            uint betAmount,
            address winner,
            bool isSolo
        )
    {
        Round memory myRound = rounds[roundId];
        return (
            myRound.player1.playerAddress,
            myRound.player1.choice,
            myRound.player2.playerAddress,
            myRound.player2.choice,
            myRound.betAmount,
            myRound.winner,
            myRound.isSolo
        );
    }

    /** @notice Function called each time we want to play individually vs the house/blockchain.
                Payable function thar receives the bet amount.
      * @param _choice choose Choice enum value: ROCK, PAPER, SCISSOR
      * @return roundId id number that identify the round created
     */
    function playSoloRound(uint _choice)
        public
        gameIsOn(true)
        isChoice(_choice)
        payable
        returns(uint)
    {
        require(isValidBet(msg.value, minimumBet, 1000000 ether));
        //require(msg.value >= minimumBet, "Not enough amount bet");
        Choice choice = Choice(_choice);
        roundCount++;
        uint roundId = roundCount;
        Round storage round = rounds[roundId];
        round.player1.playerAddress = msg.sender;
        round.player1.choice = choice;
        round.betAmount = msg.value;
        round.isSolo = true;

        emit RoundCreated(
            roundCount,
            round.betAmount,
            round.player1.playerAddress,
            round.isSolo
        );

        if (round.isSolo) {
            require(isValidBet(msg.value, minimumBet, jackpot));
            //require(msg.value <= jackpot, "Bet too high");
            round.player2.playerAddress = address(this);
            round.player2.choice = getRandomChoice();
            _resolveRound(roundId);
            if (lotteryOn) {
                _playLottery(round.player1.playerAddress, roundId);
            }
        }

        return roundId;
    }

    /** @notice Function called each time we want to create a round for playing with other players.
                Payable function thar receives the bet amount.
      * @param _secretChoice bytes32 with the encrypted choice plus a secret string
      * @return roundId id number that identify the round created
     */
    function createRound(bytes32 _secretChoice)
        public
        gameIsOn(true)
        payable
        returns(uint)
    {
        require(msg.value >= minimumBet, "Not enough amount bet");

        roundCount++;
        uint roundId = roundCount;
        Round storage round = rounds[roundId];
        round.player1.playerAddress = msg.sender;
        round.player1.secretChoice = _secretChoice;
        round.betAmount = msg.value;
        round.isSolo = false;

        emit RoundCreated(
            roundCount,
            round.betAmount,
            round.player1.playerAddress,
            round.isSolo
        );

        emit Secret(_secretChoice);

        return roundId;
    }

    /** @notice Join to an existing round created by other player
                Payable function thar receives the bet amount.
      * @param _roundId id number that identify the round to join
      * @param _choice choose Choice enum value: ROCK, PAPER, SCISSOR
     */
    function joinRound(uint _roundId, uint _choice) public gameIsOn(true) isChoice(_choice) payable {
        Round storage myRound = rounds[_roundId];  // Pointer to round
        require(myRound.player1.playerAddress != address(0), "Round does not exist");
        require(myRound.player2.playerAddress == address(0) && !myRound.isClosed, "Round already finished");
        require(msg.value >= myRound.betAmount, "Send at least the same bet amount");

        // Send back the excess of the amount sent minus the real bet amount
        // Use Safe Math, althouth this should never be overflow bc substract uints is another uint
        // Using transfer should prevent from fallback reentrancy, but...
        // Also, a reentrancy would have to send more value than betAmount, I think an attack has no sense
        // but I would have to analyze it a bit more.
        msg.sender.transfer(msg.value - myRound.betAmount);  // No need to use SafeMath since this can't be negative

        myRound.player2.playerAddress = msg.sender;
        myRound.player2.choice = Choice(_choice);
    }

    /** @notice Player 1 reveals choice when other player has joined to player 1's round
     */
    function revealChoice(uint _roundId, uint256 _choice, string memory _secret) public gameIsOn(true) {
        Round storage myRound = rounds[_roundId];  // Pointer to round
        require(myRound.player2.playerAddress != address(0), "Nobody joined to the round, it can't be resolved");
        require(keccak256(abi.encodePacked(_choice, _secret)) == myRound.player1.secretChoice, "Error trying to reveal choice");
        myRound.player1.choice = Choice(_choice);
        _resolveRound(_roundId);
        if (lotteryOn) {
            _playLottery(myRound.player1.playerAddress, _roundId);
            _playLottery(myRound.player2.playerAddress, _roundId);
        }
    }

    /**  @dev For some reason, overloading that used to work fine now it fails, so I've changed the name of the funciton
              to differentiate from the other cancelRound
    */
    function cancelRoundSender(uint _roundId) public {
        require(rounds[_roundId].player1.playerAddress == msg.sender, "Error trying to cancel round: the sender is not the creator of the round");
        _cancelRound(_roundId);
    }

    function cancelRound(uint _roundId, uint256 _choice, string memory _secret) public {
        require(keccak256(abi.encodePacked(_choice, _secret)) == rounds[_roundId].player1.secretChoice, "Error trying to cancel round: wrong choice or secret");
        _cancelRound(_roundId);
    }

    function startGame() public {
        super.startGame();
        startLottery();
    }

    function stopGame() public {
        super.stopGame();
        stopLottery();
    }

    function withdrawFunds(address payable _myAddress) public {
        super.withdrawFunds(_myAddress);
        jackpot = 0;
    }

    function _cancelRound(uint _roundId) private {
        Round storage myRound = rounds[_roundId];  // Pointer to round
        require(myRound.player2.playerAddress == address(0), "Only possible to cancel round when nobody has joined");

        // Player can cancel round and receives the bet amount minus fees
        uint jackpotFee = myRound.betAmount.mul(jackpotFeeRate) / feeUnits;
        uint businessFee = myRound.betAmount.mul(businessFeeRate) / feeUnits;
        myRound.player1.playerAddress.transfer(myRound.betAmount - jackpotFee - businessFee);
        myRound.isClosed = true;
    }

    /** @notice Function that generates randomness for the game, used when playing vs House and playing
                for the jackpot. This implementation is not safe since it can be easyly attacked.
      * @dev It uses the blockhash of the last block, with two other params but it is not safe for a gambling
            platform. Change randomness in case we want it to be realistic. Probably it needs Oraclize.
      * @return Choice enum value (ROCK, PAPER, SCISSOR) chosen randomly.
    */
    function getRandomChoice() private view returns(Choice){
        return Choice(uint(keccak256(abi.encodePacked(roundCount, msg.sender, blockhash(block.number - 1)))) % 3);
    }

    /** @notice Resolve round, both vs House or vs other player.
                Pay winner if any.
      * @param _roundId id number that identify the round to resolve
     */
    function _resolveRound(uint _roundId) private {
        Round storage myRound = rounds[_roundId];  // Pointer to round
        require(!myRound.isClosed, "Round already closed");
        myRound.winner = _checkWinner(myRound.player1, myRound.player2);
        _payRound(_roundId);
        emit RoundResolved(
            _roundId,
            myRound.winner,
            myRound.betAmount,
            myRound.player1.playerAddress,
            myRound.player1.choice,
            myRound.player2.playerAddress,
            myRound.player2.choice
        );
        myRound.isSolo = true;
    }

    /** @notice Pay winner of the round resolved.
      * @param _roundId id number that identify the round to resolve
     */
    function _payRound(uint _roundId) private {
        Round storage myRound = rounds[_roundId];  // Pointer to round
        address payable winner = myRound.winner;

        // I think this is necessary to avoid possible reentrancy attacks (although we're using transfer).
        // I also think we are protected since this function is private, the one which calls this one is
        // also private and the parent you need to send value to join round.
        require(!myRound.isClosed, "Round already closed");
        myRound.isClosed = true;

        uint inititalJackpot = jackpot;
        uint initialBalance = address(this).balance;
        uint jackpotFee = myRound.betAmount.mul(jackpotFeeRate) / feeUnits;
        uint businessFee = myRound.betAmount.mul(businessFeeRate) / feeUnits;

        if(myRound.isSolo) {  // 1 player mode
            if (winner == address(0)){  // Draw, player recevies what he bet minus fees
                myRound.player1.playerAddress.transfer(myRound.betAmount - jackpotFee - businessFee);
                jackpot = jackpot.add(jackpotFee);
            } else if (winner == address(this)) {  // Player looses, bet to jackpot
                jackpot = jackpot.add(myRound.betAmount);
            } else {  // Player wins
                // SafeMath is not necessary, jackpot and betAmount are uint, and the substraction can only be uint.
                // Used to show using a Library. Consider to change it to use -, since it saves same gas.
                jackpot = jackpot.sub(myRound.betAmount);
                winner.transfer(myRound.betAmount.mul(2) - jackpotFee - businessFee);
                emit Payment(winner, myRound.betAmount - jackpotFee - businessFee);
                jackpot = jackpot.add(jackpotFee);
            }

        } else { // 2 players mode
            if (winner == address(0)){  // Draw, players receive what they bet minus jackpot and business fee
                // We might consider to study this a bit more, but I think that when playing 2 players
                // we may just charge half of business fee to each player and that's OK for avoiding
                // attacks in case of a draw.
                myRound.player1.playerAddress.transfer(myRound.betAmount - jackpotFee - businessFee / 2);
                myRound.player2.playerAddress.transfer(myRound.betAmount - jackpotFee - businessFee / 2);
                jackpot = jackpot.add(2 * jackpotFee);
            } else {  // Bet to the winner minus jackpot and business fee
                winner.transfer(myRound.betAmount.mul(2) - jackpotFee - businessFee);
                emit Payment(winner, myRound.betAmount - jackpotFee - businessFee);
                jackpot = jackpot.add(jackpotFee);
            }
        }

        // We must do the transfer of business fee to businessAddress but since they're supposed to be very small we should wait
        // till collecting a bigger amount, for avoiding paying more gas than actual money.
        totalBusinessFee += businessFee;
        if (totalBusinessFee > minBusinessFeePayment) {
            emit BusinessPayment(businessAddress, totalBusinessFee);
            businessAddress.transfer(totalBusinessFee);
            totalBusinessFee = 0;
        }


        // Additional check por security for reentrancy (kind of formal verification)
        // These additional checks may not be necessary since we are using transfer that limits gas to 2300,
        // so in the final deployment we could ommit all these additional checks in order to save same uncessary gas
        assert((jackpot >= inititalJackpot - (2 * myRound.betAmount)) && (address(this).balance >= initialBalance - (2 * myRound.betAmount)));
    }

    /** @notice Check winner of the round, both vs House or vs other player.
      * @param player1 player struct (with player's address and choice)
      * @param player2 player struct (with player's address and choice)
      * @return address of the winner
     */
    function _checkWinner(Player memory player1, Player memory player2) private pure returns(address payable) {
        if ((uint(player1.choice) + 1) % 3 == uint(player2.choice)) {
            return player2.playerAddress;
        } else if ((uint(player1.choice) + 2) % 3 == uint(player2.choice)) {
            return player1.playerAddress;
        } else {
            return address(0);
        }
    }

    /** @notice Play lottery for the round
      * @dev TODO: Current randomness is not the best way for gambling since it can be attacked by miners.
             TODO: It is needed to implement a mechanism that assures that existing rounds can be paid altoudh
             someone has hit the jakpot. Curerntly if someone hits the jackpot he/she gets all value of the contract
      * @param playerAddress address of the player
      * @param _roundId id number that identify the round to resolve
      * @return if player wins the lottery or not
     */
    function _playLottery(address payable playerAddress, uint _roundId) private returns (bool) {

        if (uint(keccak256(abi.encodePacked(roundCount, playerAddress, blockhash(block.number - 1)))) % lotteryRate == 0) {
            Round storage myRound = rounds[_roundId];  // Pointer to round
            require(myRound.lotteryWinner == address(0), "Only one loterry winner per round");
            myRound.lotteryWinner = playerAddress;
            _payLotteryWinner(playerAddress);
            return true;
        }
        return false;
    }

}
