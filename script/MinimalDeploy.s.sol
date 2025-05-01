// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/interfaces/IPriceOracle.sol";
import "../src/core/HypeOracle.sol";

/**
 * @title MockOracle
 * @dev Mock implementation of the HypeOracle with a fixed conversion rate
 * 1 HYPE = $5000 as requested
 */
contract MockOracle is IPriceOracle {
    // Fixed price: 1 HYPE = $5000
    // In the precompile format (scaled by 1e6), this would be 5000 * 1e6 = 5,000,000,000
    uint64 private constant MOCK_PRICE = 5_000_000_000;

    /**
     * @dev Converts a USD amount to HYPE tokens
     * @param usdAmount 18-decimal USD amount (e.g. 1e18 = $1)
     * @return hypeAmount 18-decimal HYPE amount
     */
    function usdToHype(uint256 usdAmount) external pure override returns (uint256 hypeAmount) {
        // Convert using fixed rate: 1 HYPE = $5000
        // Scaled by 1e6 as per the interface
        hypeAmount = (usdAmount * 1e6) / MOCK_PRICE;
    }

    /**
     * @dev Gets the raw price from the precompile
     * @return price Raw price in the precompile format (scaled by 1e6)
     */
    function getRawPrice() public pure override returns (uint64 price) {
        return MOCK_PRICE;
    }
}

/**
 * @title MinimalDeployMockOracle
 * @dev Deploys just the MockOracle with minimal overhead
 */
contract MinimalDeployMockOracle is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockOracle oracle = new MockOracle();
        console.log("MockOracle deployed at:", address(oracle));
        vm.stopBroadcast();
    }
}

/**
 * @title MinimalDeployHypeOracle
 * @dev Deploys just the HypeOracle with minimal overhead
 */
contract MinimalDeployHypeOracle is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        HypeOracle oracle = new HypeOracle();
        console.log("HypeOracle deployed at:", address(oracle));
        vm.stopBroadcast();
    }
}

/**
 * @title MinimalDeployRegistry
 * @dev Deploys just the Registry with minimal overhead
 */
contract MinimalDeployRegistry is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        DotHypeRegistry registry = new DotHypeRegistry(deployer, deployer);
        console.log("Registry deployed at:", address(registry));
        vm.stopBroadcast();
    }
}

/**
 * @title MinimalDeployController
 * @dev Deploys just the Controller with minimal overhead
 */
contract MinimalDeployController is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get addresses from environment
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address mockOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        DotHypeController controller = new DotHypeController(
            registryAddress,
            deployer, // signer is deployer
            mockOracleAddress,
            deployer
        );
        console.log("Controller deployed at:", address(controller));
        vm.stopBroadcast();
    }
}

/**
 * @title MinimalDeployResolver
 * @dev Deploys just the Resolver with minimal overhead
 */
contract MinimalDeployResolver is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get registry address from environment
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);
        console.log("Resolver deployed at:", address(resolver));
        vm.stopBroadcast();
    }
}

/**
 * @title SetController
 * @dev Updates the Registry's controller reference
 */
contract SetController is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get addresses from environment
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        registry.setController(controllerAddress);
        console.log("Registry controller updated to:", controllerAddress);
        vm.stopBroadcast();
    }
}

/**
 * @title SetPricing
 * @dev Sets pricing in the Controller
 */
contract SetPricing is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get controller address from environment
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        
        vm.startBroadcast(deployerPrivateKey);
        DotHypeController controller = DotHypeController(controllerAddress);
        
        controller.setAnnualPrice(1, type(uint256).max); // 1-char - unavailable
        controller.setAnnualPrice(2, type(uint256).max); // 2-char - unavailable
        controller.setAnnualPrice(3, 1000 * 1e18);       // 3-char - $1000/year
        controller.setAnnualPrice(4, 100 * 1e18);        // 4-char - $100/year
        controller.setAnnualPrice(5, 20 * 1e18);         // 5+ char - $20/year
        
        console.log("Pricing configured");
        vm.stopBroadcast();
    }
} 