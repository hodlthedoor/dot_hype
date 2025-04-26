// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IDotHypeRegistry
 * @dev Interface for the DotHype registry contract
 */
interface IDotHypeRegistry {
    /**
     * @dev Event emitted when a name is registered
     * @param tokenId The token ID of the registered name
     * @param owner The address that owns the name
     * @param expiry The timestamp when the registration expires
     */
    event NameRegistered(uint256 indexed tokenId, address indexed owner, uint256 expiry);

    /**
     * @dev Event emitted when a name registration is renewed
     * @param tokenId The token ID of the renewed name
     * @param expiry The new expiry timestamp
     */
    event NameRenewed(uint256 indexed tokenId, uint256 expiry);

    /**
     * @dev Registers a new name
     * @param name The name to register
     * @param owner The address that will own the name
     * @param duration The duration in seconds for the registration
     * @return tokenId The token ID of the registered name
     * @return expiry The timestamp when the registration expires
     */
    function register(string calldata name, address owner, uint256 duration) external returns (uint256 tokenId, uint256 expiry);

    /**
     * @dev Renews an existing name registration
     * @param tokenId The token ID of the name to renew
     * @param duration The additional duration in seconds
     * @return expiry The new expiry timestamp
     */
    function renew(uint256 tokenId, uint256 duration) external returns (uint256 expiry);

    /**
     * @dev Gets the expiry time of a name
     * @param tokenId The token ID of the name to query
     * @return expiry The expiry timestamp
     */
    function expiryOf(uint256 tokenId) external view returns (uint256 expiry);

    /**
     * @dev Checks if a name is available for registration
     * @param name The name to check
     * @return available True if the name is available
     */
    function available(string calldata name) external view returns (bool available);
    
    /**
     * @dev Gets the token ID for a label
     * @param label The label to query (without .hype)
     * @return tokenId The token ID
     */
    function nameToTokenId(string calldata label) external pure returns (uint256 tokenId);
    
    /**
     * @dev Gets the name for a token ID
     * @param tokenId The token ID to query
     * @return name The name
     */
    function tokenIdToName(uint256 tokenId) external view returns (string memory name);
} 