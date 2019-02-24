pragma solidity ^0.5.0;

/** 
* @title StartStopGame
* @author Antonio Cruz
* @notice You can use this contract to set a game on or off.
* @dev For more implementation details read the "design_pattern_decisions.md" document. 
*/
contract StartStopGame {
    
    bool public gameStatus;

    constructor() public {
    }

    modifier gameIsOn() {
        require(getGameStatus() == true);
        _;
    }

    modifier gameIsOff() {
        require(getGameStatus() == false);
        _;
    }

    function setGameStatus(bool _status) public {
        gameStatus = _status;
    }

    function getGameStatus() public view returns(bool) {
        return gameStatus;
    }


}