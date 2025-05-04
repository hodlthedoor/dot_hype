// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/HypeOracle.sol";

/**
 * @title TestHypeOracle
 * @dev Script to test the HypeOracle functionality
 */
contract TestHypeOracle is Script {
    function run() public {
        // If HypeOracle is already deployed, load it from the environment
        // Otherwise, create a new instance for simulation
        HypeOracle oracle;

        if (vm.envOr("USE_DEPLOYED_ORACLE", false)) {
            address oracleAddress = vm.envAddress("HYPE_ORACLE_ADDRESS");
            oracle = HypeOracle(oracleAddress);
            console.log("Testing deployed HypeOracle at:", oracleAddress);
        } else {
            oracle = new HypeOracle();
            console.log("Testing with new HypeOracle instance (simulation only)");
        }

        console.log("=======================================");

        // Try to get the price using the oracle
        try oracle.getRawPrice() returns (uint64 rawPrice) {
            console.log("Successfully got raw price:", rawPrice);
            console.log("Price in USD format: $%s", formatUsd(uint256(rawPrice), 6));

            // Test different USD amounts
            testUsdConversion(oracle, 1 * 1e18, "1");
            testUsdConversion(oracle, 10 * 1e18, "10");
            testUsdConversion(oracle, 100 * 1e18, "100");
            testUsdConversion(oracle, 1000 * 1e18, "1000");
        } catch Error(string memory reason) {
            console.log("Failed to get price. Reason:", reason);
        } catch (bytes memory) {
            console.log("Failed to get price (low-level error)");
            console.log("This is expected if running outside of Hyperliquid testnet/mainnet");
        }
    }

    function testUsdConversion(HypeOracle oracle, uint256 usdAmount, string memory usdLabel) internal {
        try oracle.usdToHype(usdAmount) returns (uint256 hypeAmount) {
            console.log("$%s equals this many HYPE tokens:", usdLabel, hypeAmount);
        } catch Error(string memory reason) {
            console.log("Failed to convert $%s. Reason:", usdLabel, reason);
        } catch (bytes memory) {
            console.log("Failed to convert $%s (low-level error)", usdLabel);
        }
    }

    // Helper function to format price with proper decimals
    function formatUsd(uint256 value, uint256 decimals) internal pure returns (string memory) {
        string memory result = vm.toString(value);

        // Handle case where value is less than 10^decimals
        if (value < 10 ** decimals) {
            // Add leading zeros
            uint256 leadingZeros = decimals - bytes(result).length;
            string memory zeros = "";
            for (uint256 i = 0; i < leadingZeros; i++) {
                zeros = string(abi.encodePacked(zeros, "0"));
            }

            return string(abi.encodePacked("0.", zeros, result));
        }

        // Insert decimal point
        uint256 decimalIndex = bytes(result).length - decimals;
        return string(
            abi.encodePacked(
                substring(result, 0, decimalIndex), ".", substring(result, decimalIndex, bytes(result).length)
            )
        );
    }

    // Helper function to get substring
    function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(startIndex <= endIndex && endIndex <= strBytes.length, "Invalid substring indices");

        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = 0; i < endIndex - startIndex; i++) {
            result[i] = strBytes[startIndex + i];
        }

        return string(result);
    }
}
