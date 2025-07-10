// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/core/DotHypeOnchainMetadataV3.sol";
import "../src/core/DotHypeController.sol";

contract DeployAndUpdateRegistry is Script {
    // Configuration
    address payable constant CONTROLLER_ADDRESS = payable(0xCd0A58e078c57B69A3Da6703213aa69085E2AC65);

    // Deployed contract addresses (will be set during deployment)
    address public registryAddress;
    address public resolverAddress;
    address public metadataAddress;

    function run() external {
        console.log("Starting DotHype Registry Deployment and Update Script");
        console.log("========================================================");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Controller Address:", CONTROLLER_ADDRESS);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy DotHypeRegistry
        console.log("1. Deploying DotHypeRegistry...");
        DotHypeRegistry registry = new DotHypeRegistry(deployer, CONTROLLER_ADDRESS);
        registryAddress = address(registry);
        console.log("   Registry deployed at:", registryAddress);

        // 2. Deploy DotHypeResolver
        console.log("2. Deploying DotHypeResolver...");
        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);
        resolverAddress = address(resolver);
        console.log("   Resolver deployed at:", resolverAddress);

        // 3. Deploy DotHypeOnchainMetadataV3
        console.log("3. Deploying DotHypeOnchainMetadataV3...");
        DotHypeOnchainMetadataV3 metadata = new DotHypeOnchainMetadataV3(deployer, registryAddress);
        metadataAddress = address(metadata);
        console.log("   Metadata deployed at:", metadataAddress);

        // 4. Configure Registry
        console.log("4. Configuring Registry...");
        registry.setDefaultResolver(resolverAddress);
        console.log("   Default resolver set to:", resolverAddress);

        registry.setMetadataProvider(metadataAddress);
        console.log("   Metadata provider set to:", metadataAddress);

        // 5. Update Controller (this might fail if we're not the controller owner)
        console.log("5. Updating Controller...");
        console.log("   Attempting to update controller registry address...");

        DotHypeController controller = DotHypeController(CONTROLLER_ADDRESS);
        controller.setRegistry(registryAddress);
        console.log("   Controller updated successfully!");

        vm.stopBroadcast();

        // 6. Verification
        console.log("");
        console.log("Deployment Summary:");
        console.log("==================");
        console.log("Registry:        ", registryAddress);
        console.log("Resolver:        ", resolverAddress);
        console.log("Metadata:        ", metadataAddress);
        console.log("Controller:      ", CONTROLLER_ADDRESS);
        console.log("");
        console.log("Configuration:");
        console.log("- Registry default resolver:", registry.defaultResolver());
        console.log("- Registry metadata provider:", address(registry.metadataProvider()));
        console.log("- Controller registry:", address(controller.registry()));
        console.log("");
        console.log("Deployment completed successfully!");
    }
}
