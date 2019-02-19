pragma solidity ^0.5.0;

/** 
* @title Ownability
* @author Antonio Cruz
* @notice You can use this contract to assign ownership.
* @dev For more implementation details read the "design_pattern_decisions.md" document. 
*/
contract Ownable {
    
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns(bool) {
        return msg.sender == owner;
    }
}