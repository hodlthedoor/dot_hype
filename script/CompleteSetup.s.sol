// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/core/DotHypeMetadata.sol";
import "../src/interfaces/IPriceOracle.sol";

/**
 * @title CompleteSetup
 * @dev Completes the deployment of DotHype by setting up all the remaining contracts and configurations
 */
contract CompleteSetup is Script {
    function run() public {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address mockOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");

        // Display deployment info
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);
        console.log("MockOracle address:", mockOracleAddress);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Reference to the registry
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);

        // 1. Deploy Controller
        console.log("Deploying Controller...");
        DotHypeController controller = new DotHypeController(
            registryAddress,
            deployer, // signer is deployer
            mockOracleAddress,
            deployer
        );
        console.log("Controller deployed at:", address(controller));

        // 2. Deploy Metadata (with base URI parameter)
        console.log("Deploying Metadata...");
        string memory baseURI = "https://metadata.dothype.xyz/";
        DotHypeMetadata metadata = new DotHypeMetadata(deployer, baseURI);
        console.log("Metadata deployed at:", address(metadata));

        // 3. Deploy Resolver
        console.log("Deploying Resolver...");
        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);
        console.log("Resolver deployed at:", address(resolver));

        // 4. Update Controller on Registry
        console.log("Setting Controller in Registry...");
        registry.setController(address(controller));
        console.log("Controller set in Registry");

        // 5. Update Metadata on Registry
        console.log("Setting Metadata provider in Registry...");
        registry.setMetadataProvider(address(metadata));
        console.log("Metadata provider set in Registry");

        // 6. Configure pricing
        console.log("Configuring pricing...");
        controller.setAnnualPrice(1, type(uint256).max); // 1-char - unavailable
        controller.setAnnualPrice(2, type(uint256).max); // 2-char - unavailable
        controller.setAnnualPrice(3, 1000 * 1e18); // 3-char - $1000/year
        controller.setAnnualPrice(4, 100 * 1e18); // 4-char - $100/year
        controller.setAnnualPrice(5, 20 * 1e18); // 5+ char - $20/year
        console.log("Pricing configured");

        vm.stopBroadcast();

        // Display summary
        console.log("");
        console.log("===== DEPLOYMENT SUMMARY =====");
        console.log("Registry:", registryAddress);
        console.log("Controller:", address(controller));
        console.log("Metadata:", address(metadata));
        console.log("Resolver:", address(resolver));
        console.log("MockOracle:", mockOracleAddress);
        console.log("");
        console.log("Next steps:");
        console.log("1. Set these addresses in your .env file");
        console.log(
            "2. Verify the contracts using: forge verify-contract --chain-id 998 --verifier sourcify <address> <contract>"
        );
    }
}
