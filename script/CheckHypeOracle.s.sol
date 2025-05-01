// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.27;

// import "forge-std/Script.sol";
// import "../src/core/HypeOracle.sol";

// contract CheckHypeOracle is Script {
//     function run() public {
//         // Deploy the HypeOracle contract (this will be simulated, not actually deployed)
//         HypeOracle oracle = new HypeOracle();
        
//         console.log("=======================================");
//         console.log("Testing with precompile address: 0x0000000000000000000000000000000000000807");
//         console.log("Testing with pair ID: 1 (BTC/USD)");
//         console.log("=======================================");
        
//         // Trying multiple encoding methods for the precompile call
//         console.log("\n=== Method 0: abi.encodePacked ===");
//         (bool success0, uint256 responseLength0, bytes memory firstBytes0) = oracle.tryPrecompileMethod(0);
//         console.log("Success:", success0);
//         console.log("Response length:", responseLength0);
//         console.log("First bytes (hex):", bytesToHexString(firstBytes0));
        
//         console.log("\n=== Method 1: abi.encode ===");
//         (bool success1, uint256 responseLength1, bytes memory firstBytes1) = oracle.tryPrecompileMethod(1);
//         console.log("Success:", success1);
//         console.log("Response length:", responseLength1);
//         console.log("First bytes (hex):", bytesToHexString(firstBytes1));
        
//         console.log("\n=== Trying debug method (tries both encodings) ===");
//         (bool success, uint256 responseLength, bytes memory firstBytes) = oracle.debugPrecompile();
//         console.log("Success:", success);
//         console.log("Response length:", responseLength);
//         console.log("First bytes (hex):", bytesToHexString(firstBytes));
        
//         // Try to get the price if possible
//         console.log("\n=== Attempting to get price ===");
//         try oracle.getRawPrice() returns (uint64 rawPrice) {
//             console.log("Successfully got raw price:", rawPrice);
//             uint256 oneUsdInHype = oracle.usdToHype(1e18); // 1 USD converted to HYPE
//             console.log("1 USD equals this many HYPE tokens:", oneUsdInHype);
//             console.log("Token Price in USD: $%s", formatUsd(uint256(rawPrice), 6));
//         } catch Error(string memory reason) {
//             console.log("Failed to get price. Reason:", reason);
//         } catch (bytes memory) {
//             console.log("Failed to get price (low-level error)");
//         }
//     }
    
//     // Helper function to convert bytes to hex string for debugging
//     function bytesToHexString(bytes memory data) internal pure returns (string memory) {
//         bytes memory alphabet = "0123456789abcdef";
//         bytes memory str = new bytes(2 + (data.length * 2));
//         str[0] = "0";
//         str[1] = "x";
//         for (uint256 i = 0; i < data.length; i++) {
//             str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
//             str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
//         }
//         return string(str);
//     }
    
//     // Helper function to format price with proper decimals
//     function formatUsd(uint256 value, uint256 decimals) internal pure returns (string memory) {
//         string memory result = vm.toString(value);
        
//         // Handle case where value is less than 10^decimals
//         if (value < 10**decimals) {
//             // Add leading zeros
//             uint256 leadingZeros = decimals - bytes(result).length;
//             string memory zeros = "";
//             for (uint256 i = 0; i < leadingZeros; i++) {
//                 zeros = string(abi.encodePacked(zeros, "0"));
//             }
            
//             return string(abi.encodePacked("0.", zeros, result));
//         }
        
//         // Insert decimal point
//         uint256 decimalIndex = bytes(result).length - decimals;
//         return string(abi.encodePacked(
//             substring(result, 0, decimalIndex),
//             ".",
//             substring(result, decimalIndex, bytes(result).length)
//         ));
//     }
    
//     // Helper function to get substring
//     function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
//         bytes memory strBytes = bytes(str);
//         require(startIndex <= endIndex && endIndex <= strBytes.length, "Invalid substring indices");
        
//         bytes memory result = new bytes(endIndex - startIndex);
//         for (uint256 i = 0; i < endIndex - startIndex; i++) {
//             result[i] = strBytes[startIndex + i];
//         }
        
//         return string(result);
//     }
// } 