pragma solidity ^0.5.0;

/** 
 * @title Dice Library
 * @author Antonio Cruz
 * @dev Set of functions used to allow playihng Dice game
 */
library DiceLib {

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

}