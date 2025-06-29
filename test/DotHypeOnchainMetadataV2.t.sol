// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeOnchainMetadataV2.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "../src/core/HypeOracle.sol";

contract DotHypeOnchainMetadataV2Test is Test {
    DotHypeOnchainMetadataV2 public metadata;
    DotHypeRegistry public registry;
    DotHypeController public controller;
    HypeOracle public oracle;

    address public owner = address(0x1);
    address public user1 = address(0x2);

    function setUp() public {
        // Deploy registry
        registry = new DotHypeRegistry(owner, address(this));
        
        // Deploy oracle
        oracle = new HypeOracle();
        
        // Deploy controller
        controller = new DotHypeController(
            address(registry),
            owner, // signer
            address(oracle),
            owner
        );
        
        // Deploy metadata contract
        metadata = new DotHypeOnchainMetadataV2(owner, address(registry));
        
        // Set up permissions
        vm.prank(owner);
        registry.setController(address(controller));
        vm.prank(owner);
        registry.setMetadataProvider(address(metadata));
        
        // Set up merkle root for testing (empty merkle root allows any proof)
        vm.prank(owner);
        controller.setMerkleRoot(bytes32(0));
    }

    function testGenerateSVGWithShortName() public {
        string memory svg = metadata.generateSVG("test");
        
        // Verify the SVG contains the domain name
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, "test"));
        assertTrue(_containsSubstring(svg, "Feature Text Trial"));
        assertTrue(_containsSubstring(svg, "58.4413"));
        assertTrue(_containsSubstring(svg, "text-anchor=\"end\""));
        assertTrue(_containsSubstring(svg, "x=\"520\" y=\"970\""));
    }

    function testGenerateSVGWithLongName() public {
        string memory svg = metadata.generateSVG("verylongdomainname");
        
        // Verify the SVG contains the domain name
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, "verylongdomainname"));
        assertTrue(_containsSubstring(svg, "Feature Text Trial"));
        assertTrue(_containsSubstring(svg, "58.4413"));
    }

    function testGenerateSVGWithSpecialCharacters() public {
        string memory svg = metadata.generateSVG("test-123");
        
        // Verify the SVG contains the domain name
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, "test-123"));
    }

    function testTokenURI() public {
        // Register a domain first using merkle proof
        string memory name = "testdomain";
        uint256 duration = 365 days;
        uint256 price = controller.calculatePrice(name, duration);
        
        // Create a simple merkle proof (empty array for testing)
        bytes32[] memory proof = new bytes32[](0);
        
        vm.deal(user1, price);
        vm.prank(user1);
        controller.registerWithMerkleProof{value: price}(name, duration, proof);
        uint256 tokenId = registry.nameToTokenId(name);
        
        // Generate token URI
        string memory uri = metadata.tokenURI(tokenId, name);
        
        // Verify it's a valid data URI
        assertTrue(_containsSubstring(uri, "data:application/json;base64,"));
        
        // Decode and verify JSON structure
        string memory json = _decodeBase64(_extractBase64(uri));
        assertTrue(_containsSubstring(json, "testdomain.hype"));
        assertTrue(_containsSubstring(json, "A .hype domain on the Hyperliquid network"));
        assertTrue(_containsSubstring(json, "data:image/svg+xml;base64,"));
    }

    function testGenerateJSON() public {
        string memory name = "testdomain";
        string memory encodedSVG = "test-svg-data";
        uint256 tokenId = 123;
        uint256 expiry = block.timestamp + 365 days;
        
        string memory json = metadata.generateJSON(name, encodedSVG, tokenId, expiry);
        
        // Verify JSON structure
        assertTrue(_containsSubstring(json, "testdomain.hype"));
        assertTrue(_containsSubstring(json, "A .hype domain on the Hyperliquid network"));
        assertTrue(_containsSubstring(json, "data:image/svg+xml;base64,test-svg-data"));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Name\",\"value\":\"testdomain\""));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Length\",\"value\":10"));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Token ID\",\"value\":\"123\""));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Version\",\"value\":\"V2\""));
    }

    // Helper function to check if a string contains a substring
    function _containsSubstring(string memory _string, string memory _substring) internal pure returns (bool) {
        bytes memory stringBytes = bytes(_string);
        bytes memory substringBytes = bytes(_substring);
        
        if (substringBytes.length > stringBytes.length) {
            return false;
        }
        
        for (uint i = 0; i <= stringBytes.length - substringBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < substringBytes.length; j++) {
                if (stringBytes[i + j] != substringBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }

    // Helper function to extract base64 part from data URI
    function _extractBase64(string memory _uri) internal pure returns (string memory) {
        bytes memory uriBytes = bytes(_uri);
        uint256 startIndex = 0;
        
        // Find the start of base64 data
        for (uint256 i = 0; i < uriBytes.length - 1; i++) {
            if (uriBytes[i] == ",") {
                startIndex = i + 1;
                break;
            }
        }
        
        bytes memory result = new bytes(uriBytes.length - startIndex);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = uriBytes[startIndex + i];
        }
        
        return string(result);
    }

    // Helper function to decode base64 (simplified - just returns the input for testing)
    function _decodeBase64(string memory _encoded) internal pure returns (string memory) {
        // For testing purposes, we'll just return the input
        // In a real implementation, you'd need a proper base64 decoder
        return _encoded;
    }
} 