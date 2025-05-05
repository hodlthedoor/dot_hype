// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/DotHypeOnchainMetadata.sol";
import "../src/interfaces/IDotHypeRegistry.sol";

// Mock registry implementation for testing
contract MockRegistry is IDotHypeRegistry {
    function register(string calldata, address, uint256) external pure returns (uint256, uint256) { return (0, 0); }
    function renew(uint256, uint256) external pure returns (uint256) { return 0; }
    function expiryOf(uint256) external view returns (uint256) { return block.timestamp + 365 days; }
    function available(string calldata) external pure returns (bool) { return true; }
    function nameToTokenId(string calldata label) external pure returns (uint256) { return uint256(keccak256(abi.encodePacked(label))); }
    function tokenIdToName(uint256) external pure returns (string memory) { return ""; }
}

/**
 * @title OnchainMetadataExamples
 * @dev Script to output examples of the onchain metadata for different domain names
 */
contract OnchainMetadataExamples is Script {
    function run() external {
        console.log("\n===== ONCHAIN METADATA EXAMPLES =====\n");
        
        // Deploy mock registry
        MockRegistry mockRegistry = new MockRegistry();
        
        // Local deployment (not broadcast to chain)
        DotHypeOnchainMetadata metadata = new DotHypeOnchainMetadata(address(this), address(mockRegistry));
        
        // Example domain names with different lengths
        string[5] memory domains = [
            "abc",          // 3 characters
            "hype",         // 4 characters
            "domain",       // 6 characters
            "hyperliquid",  // 11 characters
            "testing123"    // 10 characters
        ];
        
        // Output base64 encoded example for the first domain
        string memory exampleName = domains[0];
        uint256 exampleTokenId = uint256(keccak256(abi.encodePacked(exampleName)));
        
        // Get the actual tokenURI as it would appear on-chain
        string memory tokenURI = metadata.tokenURI(exampleTokenId, exampleName);
        
        console.log("\n=== ACTUAL DATA URI OUTPUT FOR %s.hype ===\n", exampleName);
        console.log(tokenURI);
        console.log("\n===========================================\n");
    }
} 