// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../test/mocks/MockTestingHypeOracle.sol";

/**
 * @title DeployMockTestingHypeOracle
 * @dev Script to deploy MockTestingHypeOracle contract

 forge script script/DeployMockTestingHypeOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 */
 
contract DeployMockTestingHypeOracle is Script {
    function run() public {
        // Get default pair ID from environment, default to HYPE (107) if not provided
        uint32 defaultPairId = uint32(vm.envOr("DEFAULT_PAIR_ID", uint256(107)));
        
        // Get default price for the default pair ID, default to 1 USD if not provided
        // Default price of 1e6 means 1 USD per token
        uint64 defaultPrice = uint64(vm.envOr("DEFAULT_PRICE", uint256(1e6)));
        
        // Log deployment information
        console.log("Deploying MockTestingHypeOracle");
        console.log("Default pair ID:", defaultPairId);
        console.log("Default price (scaled by 1e6):", defaultPrice);
        
        // Begin transaction
        vm.startBroadcast();
        
        // Deploy the oracle
        MockTestingHypeOracle oracle = new MockTestingHypeOracle(defaultPairId, defaultPrice);
        
        // Set additional pair prices if specified
        string memory additionalPairs = vm.envOr("ADDITIONAL_PAIRS", string(""));
        if (bytes(additionalPairs).length > 0) {
            console.log("Setting additional pair prices...");
            
            // Parse the additional pairs format: "pairId1:price1,pairId2:price2,..."
            string[] memory pairs = splitString(additionalPairs, ",");
            for (uint256 i = 0; i < pairs.length; i++) {
                string[] memory pairPrice = splitString(pairs[i], ":");
                if (pairPrice.length == 2) {
                    uint32 pairId = uint32(vm.parseUint(pairPrice[0]));
                    uint64 price = uint64(vm.parseUint(pairPrice[1]));
                    
                    if (pairId != defaultPairId) {
                        oracle.setPairPrice(pairId, price);
                        console.log("Set price for pair ID %s: %s", pairId, price);
                    }
                }
            }
        }
        
        // End transaction
        vm.stopBroadcast();
        
        // Log deployment address
        console.log("MockTestingHypeOracle deployed at:", address(oracle));
        
        // Test the oracle if requested
        if (vm.envOr("ENABLE_TEST", false)) {
            testOracle(oracle, defaultPairId, defaultPrice);
        }
    }
    
    function testOracle(MockTestingHypeOracle oracle, uint32 defaultPairId, uint64 defaultPrice) internal {
        console.log("\n=== Testing Mock Oracle Functionality ===");
        
        // Test default pair ID
        console.log("Testing default pair ID (%s) with price %s:", defaultPairId, defaultPrice);
        
        // Get raw price
        try oracle.getRawPrice() returns (uint64 price) {
            console.log("Raw price for default pair ID: %s", price);
            
            // Test $1 conversion
            uint256 usdAmount = 1 * 1e18; // $1
            try oracle.usdToHype(usdAmount) returns (uint256 tokenAmount) {
                console.log("$1 equals %s tokens of pair ID %s", tokenAmount, defaultPairId);
            } catch Error(string memory reason) {
                console.log("Error converting USD amount:", reason);
            } catch {
                console.log("Unknown error converting USD amount");
            }
        } catch Error(string memory reason) {
            console.log("Error getting default price:", reason);
        } catch {
            console.log("Unknown error getting default price");
        }
        
        // Test other pair IDs if specified
        string memory additionalPairs = vm.envOr("ADDITIONAL_PAIRS", string(""));
        if (bytes(additionalPairs).length > 0) {
            console.log("\nTesting additional pair IDs:");
            
            string[] memory pairs = splitString(additionalPairs, ",");
            for (uint256 i = 0; i < pairs.length; i++) {
                string[] memory pairPrice = splitString(pairs[i], ":");
                if (pairPrice.length == 2) {
                    uint32 pairId = uint32(vm.parseUint(pairPrice[0]));
                    
                    if (pairId != defaultPairId) {
                        console.log("\nTesting pair ID:", pairId);
                        testPairId(oracle, pairId);
                    }
                }
            }
        }
        
        console.log("=== Testing Complete ===");
    }
    
    function testPairId(MockTestingHypeOracle oracle, uint32 pairId) internal {
        try oracle.getRawPriceForPair(pairId) returns (uint64 price) {
            console.log("Raw price for pair ID %s: %s", pairId, price);
            
            uint256 usdAmount = 1 * 1e18; // $1
            try oracle.usdToToken(usdAmount, pairId) returns (uint256 tokenAmount) {
                console.log("$1 equals %s tokens of pair ID %s", tokenAmount, pairId);
            } catch Error(string memory reason) {
                console.log("Error converting USD amount:", reason);
            } catch {
                console.log("Unknown error converting USD amount");
            }
        } catch Error(string memory reason) {
            console.log("Error getting price for pair ID %s: %s", pairId, reason);
        } catch {
            console.log("Unknown error getting price for pair ID %s", pairId);
        }
    }
    
    // Helper function to split a string by a delimiter
    function splitString(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        // First, count the number of delimiters to determine array size
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);
        
        if (strBytes.length == 0) {
            return new string[](0);
        }
        
        uint256 count = 1;
        for (uint256 i = 0; i < strBytes.length - delimiterBytes.length + 1; i++) {
            bool m = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    m = false;
                    break;
                }
            }
            if (m) {
                count++;
                i += delimiterBytes.length - 1;
            }
        }
        
        // Create the array and split the string
        string[] memory parts = new string[](count);
        uint256 partIndex = 0;
        uint256 startIndex = 0;
        
        for (uint256 i = 0; i <= strBytes.length; i++) {
            if (i == strBytes.length || (i <= strBytes.length - delimiterBytes.length && isMatch(strBytes, delimiterBytes, i))) {
                uint256 length = i - startIndex;
                bytes memory part = new bytes(length);
                for (uint256 j = 0; j < length; j++) {
                    part[j] = strBytes[startIndex + j];
                }
                parts[partIndex] = string(part);
                partIndex++;
                
                if (i < strBytes.length) {
                    startIndex = i + delimiterBytes.length;
                    i += delimiterBytes.length - 1;
                }
            }
        }
        
        return parts;
    }
    
    // Helper function to check if there's a delimiter match at a specific position
    function isMatch(bytes memory str, bytes memory delimiter, uint256 pos) internal pure returns (bool) {
        if (pos + delimiter.length > str.length) {
            return false;
        }
        
        for (uint256 i = 0; i < delimiter.length; i++) {
            if (str[pos + i] != delimiter[i]) {
                return false;
            }
        }
        return true;
    }
}