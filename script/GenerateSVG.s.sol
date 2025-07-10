// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/DotHypeOnchainMetadataV3.sol";

/**
 * @title GenerateSVG
 * @dev Script to generate SVGs using the DotHypeOnchainMetadataV3 contract
 */
contract GenerateSVG is Script {
    function run() public {
        // Deploy the metadata contract (we don't need a real registry for SVG generation)
        DotHypeOnchainMetadataV3 metadata = new DotHypeOnchainMetadataV3(
            msg.sender, // owner
            msg.sender  // registry (mock - we won't call registry functions)
        );

        // Test domain names
        string[3] memory testDomains = [
            "sam",
            "juicyhamdogs", 
            "reallyreallyreallyreallyreallyreallylongname"
        ];

        console.log("Generating SVGs for test domains...\n");

        // Generate SVG for each domain
        for (uint256 i = 0; i < testDomains.length; i++) {
            string memory domain = testDomains[i];
            console.log("Generating SVG for:", string(abi.encodePacked(domain, ".hype")));
            
            string memory svg = metadata.generateSVG(domain);
            
            // Log the SVG content with a separator for easy extraction
            console.log("=== SVG START ===");
            console.log("FILENAME:", string(abi.encodePacked(domain, ".svg")));
            console.log("CONTENT:");
            console.log(svg);
            console.log("=== SVG END ===\n");
        }

        console.log("All SVGs generated successfully!");
    }
} 