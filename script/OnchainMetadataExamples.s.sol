// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/DotHypeOnchainMetadata.sol";

/**
 * @title OnchainMetadataExamples
 * @dev Script to output examples of the onchain metadata for different domain names
 */
contract OnchainMetadataExamples is Script {
    function run() external {
        console.log("\n===== ONCHAIN METADATA EXAMPLES =====\n");
        
        // Local deployment (not broadcast to chain)
        DotHypeOnchainMetadata metadata = new DotHypeOnchainMetadata(address(this));
        
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