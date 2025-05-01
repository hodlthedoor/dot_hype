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
 * @title DeployBase
 * @dev Base contract for step-by-step deployment scripts
 */
contract DeployBase is Script {
    // To store addresses between steps
    struct DeployedAddresses {
        address mockOracle;
        address hypeOracle;
        address registry;
        address payable controller;
        address resolver;
    }
    
    // Storage for addresses
    // These need to be accessible to child contracts
    address public mockOracleAddress;
    address public hypeOracleAddress;
    address public registryAddress;
    address payable public controllerAddress;
    address public resolverAddress;
    
    // Check if an address is zero
    function isZeroAddress(address addr) internal pure returns (bool) {
        return addr == address(0);
    }
}

/**
 * @title DeployOracles
 * @dev Deploys both the mock oracle and HypeOracle
 */
contract DeployOracles is DeployBase {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Oracles ======");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MockOracle
        MockOracle mockOracle = new MockOracle();
        mockOracleAddress = address(mockOracle);
        console.log("MockOracle deployed at:", mockOracleAddress);
        
        uint256 oneUsd = 1e18; // $1 with 18 decimals
        uint256 oneUsdInHype = mockOracle.usdToHype(oneUsd);
        console.log("Mock rate: 1 HYPE = $5000, $1 =", oneUsdInHype, "HYPE");
        
        // Deploy HypeOracle
        HypeOracle hypeOracle = new HypeOracle();
        hypeOracleAddress = address(hypeOracle);
        console.log("HypeOracle deployed at:", hypeOracleAddress);
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Oracles deployment complete");
        console.log("-------------------------------------------------------");
        console.log("IMPORTANT: Set these environment variables for next steps:");
        console.log("export MOCK_ORACLE_ADDRESS=", mockOracleAddress);
        console.log("export HYPE_ORACLE_ADDRESS=", hypeOracleAddress);
        console.log("-------------------------------------------------------");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:DeployRegistry --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title DeployRegistry
 * @dev Deploys the registry contract
 */
contract DeployRegistry is DeployBase {
    function run() public {
        // Get addresses from environment variables
        mockOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");
        require(mockOracleAddress != address(0), "MockOracle address not set. Run DeployOracles first and export the address.");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Registry ======");
        console.log("Deployer address:", deployer);
        console.log("Using MockOracle at:", mockOracleAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Registry
        DotHypeRegistry registry = new DotHypeRegistry(deployer, deployer);
        registryAddress = address(registry);
        console.log("DotHypeRegistry deployed at:", registryAddress);
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Registry deployment complete");
        console.log("-------------------------------------------------------");
        console.log("IMPORTANT: Set this environment variable for next steps:");
        console.log("export REGISTRY_ADDRESS=", registryAddress);
        console.log("-------------------------------------------------------");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:DeployController --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title DeployController
 * @dev Deploys the controller contract and links it to the registry
 */
contract DeployController is DeployBase {
    function run() public {
        // Get addresses from environment variables
        mockOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");
        hypeOracleAddress = vm.envAddress("HYPE_ORACLE_ADDRESS");
        registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        
        require(mockOracleAddress != address(0), "MockOracle address not set.");
        require(registryAddress != address(0), "Registry address not set.");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Controller ======");
        console.log("Deployer address:", deployer);
        console.log("Using Registry at:", registryAddress);
        console.log("Using MockOracle at:", mockOracleAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Controller
        address signer = deployer; // Using deployer as signer for simplicity
        DotHypeController controller = new DotHypeController(
            registryAddress,
            signer,
            mockOracleAddress, // Initially connect to MockOracle
            deployer
        );
        controllerAddress = payable(address(controller));
        console.log("DotHypeController deployed at:", controllerAddress);
        
        // Update Registry's controller
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        registry.setController(controllerAddress);
        console.log("Registry controller updated to:", controllerAddress);
        
        // Set up pricing
        console.log("Setting up pricing...");
        controller.setAnnualPrice(1, type(uint256).max); // 1-char - unavailable
        controller.setAnnualPrice(2, type(uint256).max); // 2-char - unavailable
        controller.setAnnualPrice(3, 1000 * 1e18);       // 3-char - $1000/year
        controller.setAnnualPrice(4, 100 * 1e18);        // 4-char - $100/year
        controller.setAnnualPrice(5, 20 * 1e18);         // 5+ char - $20/year
        console.log("Pricing configured");
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Controller deployment complete");
        console.log("-------------------------------------------------------");
        console.log("IMPORTANT: Set this environment variable for next steps:");
        console.log("export CONTROLLER_ADDRESS=", controllerAddress);
        console.log("-------------------------------------------------------");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:DeployResolver --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title DeployResolver
 * @dev Deploys the resolver contract
 */
contract DeployResolver is DeployBase {
    function run() public {
        // Get addresses from environment variables
        registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        require(registryAddress != address(0), "Registry address not set.");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Resolver ======");
        console.log("Deployer address:", deployer);
        console.log("Using Registry at:", registryAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Resolver
        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);
        resolverAddress = address(resolver);
        console.log("DotHypeResolver deployed at:", resolverAddress);
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Resolver deployment complete");
        console.log("-------------------------------------------------------");
        console.log("IMPORTANT: Set this environment variable for next steps:");
        console.log("export RESOLVER_ADDRESS=", resolverAddress);
        console.log("-------------------------------------------------------");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:ReserveTestDomains --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title ReserveTestNames
 * @dev Reserves test names after all contracts are deployed
 */
contract ReserveTestDomains is DeployBase {
    function run() public {
        // Get addresses from environment variables
        controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        require(controllerAddress != address(0), "Controller address not set.");
        
        mockOracleAddress = vm.envAddress("MOCK_ORACLE_ADDRESS");
        hypeOracleAddress = vm.envAddress("HYPE_ORACLE_ADDRESS");
        registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        resolverAddress = vm.envAddress("RESOLVER_ADDRESS");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address secondAddress = 0xc2AbE12785B69349b9C85F9b6812D8894C8AB945;
        
        console.log("\n====== Reserving Test Domains ======");
        console.log("Deployer address:", deployer);
        console.log("Second address:", secondAddress);
        console.log("Using Controller at:", controllerAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Use the controller contract
        DotHypeController controller = DotHypeController(controllerAddress);
        
        // Test names to reserve
        string[] memory names = new string[](10);
        address[] memory reservedFor = new address[](10);
        
        for (uint i = 0; i < 10; i++) {
            names[i] = string(abi.encodePacked("test", vm.toString(i + 1)));
            // Alternate between deployer and secondAddress
            reservedFor[i] = i % 2 == 0 ? deployer : secondAddress;
            
            console.log("Reserving", names[i], "for", reservedFor[i]);
        }
        
        // Reserve names in batch
        controller.setBatchReservations(names, reservedFor);
        
        console.log("Verifying reservations...");
        
        // Verify first and last reservation (to save gas)
        (bool isReserved1, address reservedAddress1) = controller.checkReservation(names[0]);
        (bool isReserved10, address reservedAddress10) = controller.checkReservation(names[9]);
        
        if (isReserved1 && reservedAddress1 == reservedFor[0]) {
            console.log(names[0], "is correctly reserved");
        } else {
            console.log("WARNING: Reservation failed for", names[0]);
        }
        
        if (isReserved10 && reservedAddress10 == reservedFor[9]) {
            console.log(names[9], "is correctly reserved");
        } else {
            console.log("WARNING: Reservation failed for", names[9]);
        }
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Test domains reserved");
        printSummary(deployer, secondAddress);
    }
    
    function printSummary(
        address deployer,
        address secondAddress
    ) internal view {
        console.log("\n====== Deployment Summary ======");
        console.log("Registry:   ", registryAddress);
        console.log("Controller: ", controllerAddress);
        console.log("Resolver:   ", resolverAddress);
        console.log("MockOracle: ", mockOracleAddress);
        console.log("HypeOracle: ", hypeOracleAddress);
        
        console.log("\nConfigured to use: MockOracle");
        console.log("To switch to real HypeOracle later, call:");
        console.log("controller.setPriceOracle(", hypeOracleAddress, ")");
        
        console.log("\nTest domains:");
        console.log("Even numbers (test2, test4, etc.) reserved for:", deployer);
        console.log("Odd numbers (test1, test3, etc.) reserved for:", secondAddress);
        
        console.log("\n====== Environment Variables For Next Steps ======");
        console.log("If not already set, run these commands:");
        console.log("export REGISTRY_ADDRESS=", registryAddress);
        console.log("export CONTROLLER_ADDRESS=", controllerAddress);
        console.log("export RESOLVER_ADDRESS=", resolverAddress);
        console.log("export MOCK_ORACLE_ADDRESS=", mockOracleAddress);
        console.log("export HYPE_ORACLE_ADDRESS=", hypeOracleAddress);
        
        console.log("\n====== Next Steps ======");
        console.log("1. To register your reserved domains:");
        console.log("   forge script script/RegisterReservedNames.s.sol --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998");
        console.log("2. To check registered domains:");
        console.log("   forge script script/CheckDomains.s.sol --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998");
        console.log("3. To switch to the real HypeOracle:");
        console.log("   forge script script/SwitchToHypeOracle.s.sol --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998");
    }
} 