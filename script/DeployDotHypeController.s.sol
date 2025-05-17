// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeController.sol";
import "../src/interfaces/IPriceOracle.sol";
import "../src/core/DotHypeRegistry.sol";

/**
 * @title DeployDotHypeController
 * @dev Script to deploy the DotHypeController contract and connect it to an existing registry and oracle
 * Usage: forge script script/DeployDotHypeController.s.sol --rpc-url <your_rpc_url> --broadcast --verify
 */
contract DeployDotHypeController is Script {
    function run() public {
        // Get configuration from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address priceOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");

        console.log("Deploying DotHypeController with account:", deployer);
        console.log("Using registry address:", registryAddress);
        console.log("Using existing oracle address:", priceOracleAddress);

        // Start transaction
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the DotHypeController
        console.log("Deploying DotHypeController...");

        // Constructor parameters
        address signerAddress = deployer; // Using deployer as signer for simplicity

        DotHypeController controller =
            new DotHypeController(registryAddress, signerAddress, priceOracleAddress, deployer);

        address controllerAddress = address(controller);
        console.log("DotHypeController deployed at:", controllerAddress);

        // Set up initial pricing
        console.log("Setting up initial pricing...");
        uint256[5] memory prices = [
            type(uint256).max, // 1 character: unavailable
            type(uint256).max, // 2 characters: unavailable
            100 ether, // 3 characters: $100 per year
            10 ether, // 4 characters: $10 per year
            1 ether // 5+ characters: $1 per year
        ];

        controller.setAllAnnualPrices(prices);
        console.log("Initial pricing configured");

        // Set payment recipient (same as owner for simplicity)
        controller.setPaymentRecipient(deployer);
        console.log("Payment recipient configured to:", deployer);

        // Set the controller in the registry
        console.log("Setting controller in registry...");
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        try registry.setController(controllerAddress) {
            console.log("Controller successfully set in registry");
        } catch {
            console.log("WARNING: Failed to set controller in registry.");
            console.log("You may need to set it manually if you're not the registry owner.");
        }

        // End transaction
        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Registry:     ", registryAddress);
        console.log("Controller:   ", controllerAddress);
        console.log("Price Oracle: ", priceOracleAddress);
        console.log("\nIf the controller wasn't set automatically, run this command:");
        console.log(
            "cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY",
            registryAddress,
            "setController(address)",
            controllerAddress
        );
    }
}
