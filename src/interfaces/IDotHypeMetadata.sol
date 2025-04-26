// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IDotHypeMetadata
 * @dev Interface for the DotHype metadata provider
 */
interface IDotHypeMetadata {
    /**
     * @dev Returns the metadata for a specific token ID
     * @param tokenId The token ID to get metadata for
     * @param name The name associated with the token
     * @return The complete URI for the token metadata
     */
    function tokenURI(uint256 tokenId, string calldata name) external view returns (string memory);
} 