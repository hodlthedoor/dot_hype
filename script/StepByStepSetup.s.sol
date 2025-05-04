// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/core/DotHypeMetadata.sol";
import "../src/interfaces/IPriceOracle.sol";

/**
 * @title DeployController
 * @dev Deploys only the Controller contract
 */
contract DeployController is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address mockOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");

        console.log("Deploying Controller...");
        console.log("Registry:", registryAddress);
        console.log("MockOracle:", mockOracleAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeController controller = new DotHypeController(registryAddress, deployer, mockOracleAddress, deployer);

        console.log("Controller deployed at:", address(controller));

        vm.stopBroadcast();
    }
}

/**
 * @title DeployMetadata
 * @dev Deploys only the Metadata contract
 */
contract DeployMetadata is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Metadata...");

        // Default base URI for metadata
        string memory baseURI = "https://metadata.dothype.xyz/";

        vm.startBroadcast(deployerPrivateKey);

        DotHypeMetadata metadata = new DotHypeMetadata(deployer, baseURI);

        console.log("Metadata deployed at:", address(metadata));
        console.log("Base URI set to:", baseURI);

        vm.stopBroadcast();
    }
}

/**
 * @title DeployResolver
 * @dev Deploys only the Resolver contract
 */
contract DeployResolver is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");

        console.log("Deploying Resolver...");
        console.log("Registry:", registryAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);

        console.log("Resolver deployed at:", address(resolver));

        vm.stopBroadcast();
    }
}

/**
 * @title SetupRegistry
 * @dev Updates controller and metadata on the Registry
 */
contract SetupRegistry is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        address metadataAddress = vm.envAddress("METADATA_ADDRESS");

        console.log("Setting up Registry...");
        console.log("Registry:", registryAddress);
        console.log("Controller:", controllerAddress);
        console.log("Metadata:", metadataAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeRegistry registry = DotHypeRegistry(registryAddress);

        // Set Controller
        registry.setController(controllerAddress);
        console.log("Controller set in Registry");

        // Set Metadata
        registry.setMetadataProvider(metadataAddress);
        console.log("Metadata provider set in Registry");

        vm.stopBroadcast();
    }
}

/**
 * @title SetupPricing
 * @dev Configures pricing in the Controller
 */
contract SetupPricing is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Use payable address for controller
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));

        console.log("Setting up pricing...");
        console.log("Controller:", controllerAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeController controller = DotHypeController(controllerAddress);

        controller.setAnnualPrice(1, type(uint256).max); // 1-char - unavailable
        controller.setAnnualPrice(2, type(uint256).max); // 2-char - unavailable
        controller.setAnnualPrice(3, 1000 * 1e18); // 3-char - $1000/year
        controller.setAnnualPrice(4, 100 * 1e18); // 4-char - $100/year
        controller.setAnnualPrice(5, 20 * 1e18); // 5+ char - $20/year

        console.log("Pricing configured");

        vm.stopBroadcast();
    }
}
