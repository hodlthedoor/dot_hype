// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDotHypeMetadata.sol";

/**
 * @title DotHypeMetadata
 * @dev Implementation of the IDotHypeMetadata interface
 */
contract DotHypeMetadata is Ownable, IDotHypeMetadata {
    // Base URI for token metadata
    string private _baseTokenURI;

    /**
     * @dev Constructor
     * @param _owner Initial owner of the contract
     * @param baseURI Base URI for token metadata
     */
    constructor(address _owner, string memory baseURI) Ownable(_owner) {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Returns the metadata for a specific token ID
     * @param name The name associated with the token
     * @return The complete URI for the token metadata
     */
    function tokenURI(uint256, /*tokenId*/ string calldata name) external view override returns (string memory) {
        // Simple implementation that concatenates base URI, name, and ".json"
        return string(abi.encodePacked(_baseTokenURI, name, ".json"));
    }

    /**
     * @dev Sets the base URI for token metadata
     * @param baseURI The new base URI
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
}
