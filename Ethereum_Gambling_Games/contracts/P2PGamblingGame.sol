pragma solidity >=0.5;

import "./GamblingGame.sol";


/** @title Abstract contract that defines methods to add P2P functionality
           to Ethereum Gambling Games
  * @author Rodrigo Gómez Gentil, Antonio Cruz Suárez
  * @notice This is just a simple game for the TFM of the Master in Ethereum.
            Do not use betting real value since it may have some vulnerabilities.
            Further analysis and assurance is needed to take in production/main net.
 */
contract P2PGamblingGame is GamblingGame{

    /**
     * @notice Abstract function to create round with a commit-reveal scheme
     * @param _secretChoice Sha3 hash of the choice made by player and a secret word
     * @return Round Id of the round
     */
    function createSecretRound(bytes32 _secretChoice)
        public
        payable
        returns(uint);

    /**
     * @notice Abstract function to join to a round with a commit-reveal scheme
     * @param _choice Choice made by player
     * @param _roundId Round Id of the round
     */
    function joinSecretRound(uint _roundId, uint _choice) public payable;

    /**
     * @notice Abstract function to reveal an existing round with a commit-reveal scheme
     * @param _roundId Round Id of the round
     * @param _choice Choice made by player
     * @param _secret secret word for revealing
     */
    function revealChoice(uint _roundId, uint256 _choice, string memory _secret) public;

    /**
     * @notice Abstract function for the original creator to cancel an existing round
     *         with a commit-reveal scheme
     * @param _roundId Round Id of the round
     */
    function cancelRoundSender(uint _roundId) public {
        require(rounds[_roundId].player1.playerAddress == msg.sender, "Error trying to cancel round: the sender is not the creator of the round");
        _cancelRound(_roundId);
    }

    /**
     * @notice Abstract function to cancel an existing round providing the choice and the secret
     *         with a commit-reveal scheme
     * @param _roundId Round Id of the round
     * @param _choice original choice
     * @param _secret secret word of the round
     */
    function cancelRound(uint _roundId, uint256 _choice, string memory _secret) public {
        require(keccak256(abi.encodePacked(_choice, _secret)) == rounds[_roundId].player1.secretChoice, "Error trying to cancel round: wrong choice or secret");
        _cancelRound(_roundId);
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
}