pragma solidity >=0.5;

import "./GamblingGame.sol";


contract P2PGamblingGame is GamblingGame{

    function createRound(bytes32 _secretChoice)
        public
        payable
        returns(uint);

    function joinRound(uint _roundId, uint _choice) public payable;

    function revealChoice(uint _roundId, uint256 _choice, string memory _secret) public;

    function cancelRoundSender(uint _roundId) public;

    function cancelRound(uint _roundId, uint256 _choice, string memory _secret) public;

    function _cancelRound(uint _roundId) private;
}