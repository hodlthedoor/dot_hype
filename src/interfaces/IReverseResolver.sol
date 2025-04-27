// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IReverseResolver
 * @dev Interface for reverse resolution - resolving from addresses to names
 */
interface IReverseResolver {
    /**
     * @dev Event emitted when a reverse resolution is set
     * @param addr The address for which the reverse record was set
     * @param node The namehash of the domain the address points to
     */
    event ReverseResolutionSet(address indexed addr, bytes32 indexed node);

    /**
     * @dev Event emitted when a reverse resolution is cleared
     * @param addr The address for which the reverse record was cleared
     */
    event ReverseResolutionCleared(address indexed addr);

    /**
     * @dev Gets the domain node that an address points to
     * @param addr The address to lookup
     * @return The domain node the address is associated with
     */
    function getNode(address addr) external view returns (bytes32);

    /**
     * @dev Sets the domain node for an address (reverse resolution)
     * Can only be called by the owner of the domain
     * @param node The node to associate with the sender's address
     */
    function setReverseRecord(bytes32 node) external;

    /**
     * @dev Clears the reverse record for the sender's address
     */
    function clearReverseRecord() external;

    /**
     * @dev Gets the domain name for an address through reverse resolution
     * @param addr The address to lookup
     * @return The domain name associated with the address, or empty string if not set
     */
    function reverseLookup(address addr) external view returns (string memory);

    /**
     * @dev Gets the domain name for an address through reverse resolution
     * This is an alias for reverseLookup for compatibility with other systems
     * @param addr The address to lookup
     * @return The domain name associated with the address, or empty string if not set
     */
    function getName(address addr) external view returns (string memory);

    /**
     * @dev Gets a specific value for an address through reverse resolution
     * This retrieves a text record from the domain pointed to by the address's reverse record
     * @param addr The address to lookup
     * @param key The text record key to retrieve
     * @return The text record value associated with the key for the address's domain
     */
    function getValue(address addr, string calldata key) external view returns (string memory);

    /**
     * @dev Checks if an address has a reverse record
     * @param addr The address to check
     * @return True if the address has a valid, non-expired reverse record
     */
    function hasRecord(address addr) external view returns (bool);
}
