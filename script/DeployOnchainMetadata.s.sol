// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeOnchainMetadata.sol";

/**
 * @title DeployOnchainMetadata
 * @dev Script to deploy the DotHypeOnchainMetadata contract and update the registry
 *
 * To run this script:
 * forge script script/DeployOnchainMetadata.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast --verify --etherscan-api-key <ETHERSCAN_API_KEY>
 */
contract DeployOnchainMetadata is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");

        // Derive deployer address from private key
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n===== DEPLOYING ONCHAIN METADATA CONTRACT =====\n");
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);

        // Verify registry exists at the specified address
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(registryAddress)
        }

        require(codeSize > 0, "No contract deployed at registry address");
        console.log("Registry contract verified at address");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the OnchainMetadata contract
        console.log("\nDeploying DotHypeOnchainMetadata...");
        DotHypeOnchainMetadata onchainMetadata = new DotHypeOnchainMetadata(deployer, registryAddress);
        console.log("DotHypeOnchainMetadata deployed at:", address(onchainMetadata));

        // Get reference to the registry contract
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);

        // Set the new metadata provider in the registry
        console.log("\nUpdating metadata provider in registry...");
        registry.setMetadataProvider(address(onchainMetadata));
        console.log("Metadata provider updated successfully!");

        vm.stopBroadcast();

        // Display verification instructions
        console.log("\n===== DEPLOYMENT SUMMARY =====");
        console.log("DotHypeOnchainMetadata:", address(onchainMetadata));
    }
}
