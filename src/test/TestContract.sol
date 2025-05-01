// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title TestContract
 * @dev A simple contract for testing deployment and verification
 */
contract TestContract {
    string private greeting;
    uint256 private value;
    address public owner;

    event GreetingChanged(string newGreeting);
    event ValueChanged(uint256 newValue);

    constructor(string memory _greeting, uint256 _value) {
        greeting = _greeting;
        value = _value;
        owner = msg.sender;
    }

    function setGreeting(string memory _greeting) public {
        require(msg.sender == owner, "Not owner");
        greeting = _greeting;
        emit GreetingChanged(_greeting);
    }

    function setValue(uint256 _value) public {
        require(msg.sender == owner, "Not owner");
        value = _value;
        emit ValueChanged(_value);
    }

    function getGreeting() public view returns (string memory) {
        return greeting;
    }

    function getValue() public view returns (uint256) {
        return value;
    }
} 