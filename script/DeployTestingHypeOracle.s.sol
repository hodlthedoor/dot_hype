// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../test/mocks/TestingHypeOracle.sol";

/**
 * @title DeployTestingHypeOracle
 * @dev Script to deploy TestingHypeOracle contract

 forge script script/DeployTestingHypeOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 */
contract DeployTestingHypeOracle is Script {
    function run() public {
        // Get default pair ID from environment, default to HYPE (107) if not provided
        uint32 defaultPairId = uint32(vm.envOr("DEFAULT_PAIR_ID", uint256(107)));
        
        // Log deployment information
        console.log("Deploying TestingHypeOracle");
        console.log("Default pair ID:", defaultPairId);
        
        // Begin transaction
        vm.startBroadcast();
        
        // Deploy the oracle
        TestingHypeOracle oracle = new TestingHypeOracle(defaultPairId);
        
        // End transaction
        vm.stopBroadcast();
        
        // Log deployment address
        console.log("TestingHypeOracle deployed at:", address(oracle));
        
        // Test the oracle if ENABLE_TEST environment variable is set
        if (vm.envOr("ENABLE_TEST", false)) {
            testOracle(oracle, defaultPairId);
        }
    }
    
    function testOracle(TestingHypeOracle oracle, uint32 defaultPairId) internal {
        console.log("\n=== Testing Oracle Functionality ===");
        
        // Try to get the default price
        try oracle.getRawPrice() returns (uint64 defaultPrice) {
            console.log("Raw price for default pair ID (%s): %s", defaultPairId, defaultPrice);
            
            // Test conversion
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
            console.log("This is expected if running outside of Hyperliquid testnet/mainnet");
        }
        
        // Test other pair IDs if specified
        string memory testPairIdsStr = vm.envOr("TEST_PAIR_IDS", string(""));
        if (bytes(testPairIdsStr).length > 0) {
            string[] memory pairIds = splitString(testPairIdsStr, ",");
            
            for (uint256 i = 0; i < pairIds.length; i++) {
                uint32 pairId = uint32(vm.parseUint(pairIds[i]));
                
                if (pairId != defaultPairId) {
                    console.log("\nTesting pair ID:", pairId);
                    testPairId(oracle, pairId);
                }
            }
        }
        
        console.log("=== Testing Complete ===");
    }
    
    function testPairId(TestingHypeOracle oracle, uint32 pairId) internal {
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