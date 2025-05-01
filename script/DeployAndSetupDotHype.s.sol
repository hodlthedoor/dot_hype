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
 * @title DeployAndSetupDotHype
 * @dev Script to deploy and set up the complete DotHype infrastructure in multiple steps
 *      to avoid exceeding block gas limits
 */
contract DeployAndSetupDotHype is Script {
    // Contract addresses to persist between transactions
    address public mockOracleAddress;
    address public hypeOracleAddress;
    address public registryAddress;
    address payable public controllerAddress;
    address public resolverAddress;
    
    function run() public {
        // Get the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("====== STEP 1: Deploy Oracles ======");
        deployOracles(deployerPrivateKey, deployer);
        
        console.log("\n====== STEP 2: Deploy Core Contracts ======");
        deployCoreContracts(deployerPrivateKey, deployer);
        
        console.log("\n====== STEP 3: Configure Pricing ======");
        configurePricing(deployerPrivateKey);
        
        console.log("\n====== STEP 4: Reserve Test Names ======");
        reserveTestNames(deployerPrivateKey, deployer);
        
        printSummary(deployer);
    }
    
    function deployOracles(uint256 deployerPrivateKey, address deployer) internal {
        // Start transaction
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying contracts with address:", deployer);
        
        // Deploy the mock oracle
        MockOracle mockOracle = new MockOracle();
        mockOracleAddress = address(mockOracle);
        console.log("MockOracle deployed at:", mockOracleAddress);
        console.log("Mock conversion rate: 1 HYPE = $5000");
        
        // Deploy the real HypeOracle
        HypeOracle hypeOracle = new HypeOracle();
        hypeOracleAddress = address(hypeOracle);
        console.log("HypeOracle deployed at:", hypeOracleAddress);
        
        // Test mock oracle conversion rate
        uint256 oneUsd = 1e18; // $1 with 18 decimals
        uint256 oneUsdInHype = mockOracle.usdToHype(oneUsd);
        console.log("$1 equals this many HYPE tokens (using MockOracle):", oneUsdInHype);
        
        // End transaction
        vm.stopBroadcast();
    }
    
    function deployCoreContracts(uint256 deployerPrivateKey, address deployer) internal {
        // Start transaction
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the Registry with temporary controller
        address temporaryController = deployer;
        DotHypeRegistry registry = new DotHypeRegistry(deployer, temporaryController);
        registryAddress = address(registry);
        console.log("DotHypeRegistry deployed at:", registryAddress);
        
        // Deploy the Controller
        address signer = deployer; // Using deployer as signer for simplicity
        DotHypeController controller = new DotHypeController(
            registryAddress,
            signer,
            mockOracleAddress, // Initially connect to MockOracle
            deployer
        );
        controllerAddress = payable(address(controller));
        console.log("DotHypeController deployed at:", controllerAddress);
        
        // Update Registry's controller to the real controller address
        registry.setController(controllerAddress);
        console.log("Registry controller set to:", controllerAddress);
        
        // Deploy the Resolver
        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);
        resolverAddress = address(resolver);
        console.log("DotHypeResolver deployed at:", resolverAddress);
        
        // End transaction
        vm.stopBroadcast();
    }
    
    function configurePricing(uint256 deployerPrivateKey) internal {
        // Start transaction
        vm.startBroadcast(deployerPrivateKey);
        
        DotHypeController controller = DotHypeController(controllerAddress);
        
        // Set up pricing in the Controller
        // These are example annual prices in USD (1e18 = $1)
        // Index corresponds to character length: [not used, 1-char, 2-char, 3-char, 4-char, 5+ char]
        uint256[6] memory annualPrices = [
            0,                   // Not used
            type(uint256).max,   // 1-character domains - unavailable
            type(uint256).max,   // 2-character domains - unavailable
            1000 * 1e18,         // 3-character domains - $1000/year
            100 * 1e18,          // 4-character domains - $100/year
            20 * 1e18            // 5+ character domains - $20/year
        ];
        
        // Set prices in the controller
        for (uint256 i = 1; i < annualPrices.length; i++) {
            controller.setAnnualPrice(i, annualPrices[i]);
            console.log("Set price for", i, "character domains:", annualPrices[i]);
        }
        
        // End transaction
        vm.stopBroadcast();
    }
    
    function reserveTestNames(uint256 deployerPrivateKey, address deployer) internal {
        // Start transaction
        vm.startBroadcast(deployerPrivateKey);
        
        // The second address to reserve names for
        address secondAddress = 0xc2AbE12785B69349b9C85F9b6812D8894C8AB945;
        console.log("Reserving test names for deployer and:", secondAddress);
        
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
        
        // Verify reservations
        for (uint i = 0; i < 10; i++) {
            (bool isReserved, address reservedAddress) = controller.checkReservation(names[i]);
            if (isReserved && reservedAddress == reservedFor[i]) {
                console.log(names[i], "is correctly reserved for", reservedAddress);
            } else {
                console.log("WARNING: Reservation failed for", names[i]);
                console.log("Expected:", reservedFor[i], "Got:", reservedAddress);
            }
        }
        
        // End transaction
        vm.stopBroadcast();
    }
    
    function printSummary(address deployer) internal view {
        // Get conversion rate
        MockOracle mockOracle = MockOracle(mockOracleAddress);
        uint256 oneUsd = 1e18; // $1 with 18 decimals
        uint256 oneUsdInHype = mockOracle.usdToHype(oneUsd);
        
        // Get second address
        address secondAddress = 0xc2AbE12785B69349b9C85F9b6812D8894C8AB945;
        
        console.log("\n=== Deployment Summary ===");
        console.log("----------------------------------------------------------------");
        console.log("Registry:   ", registryAddress);
        console.log("Controller: ", controllerAddress);
        console.log("Resolver:   ", resolverAddress);
        console.log("MockOracle: ", mockOracleAddress);
        console.log("HypeOracle: ", hypeOracleAddress);
        console.log("----------------------------------------------------------------");
        console.log("Currently using: MockOracle");
        console.log("To switch to HypeOracle later, call controller.setPriceOracle(", hypeOracleAddress, ")");
        console.log("----------------------------------------------------------------");
        console.log("MockOracle conversion rate: 1 HYPE = $5000");
        console.log("$1 equals", oneUsdInHype, "HYPE tokens");
        console.log("----------------------------------------------------------------");
        console.log("Test names reserved: 'test1' through 'test10'");
        console.log("Even numbers reserved for:", deployer);
        console.log("Odd numbers reserved for:", secondAddress);
        console.log("----------------------------------------------------------------");
        console.log("NEXT STEPS:");
        console.log("1. Export the addresses to your environment:");
        console.log("   export REGISTRY_ADDRESS=", registryAddress);
        console.log("   export CONTROLLER_ADDRESS=", controllerAddress);
        console.log("   export RESOLVER_ADDRESS=", resolverAddress);
        console.log("   export MOCK_ORACLE_ADDRESS=", mockOracleAddress);
        console.log("   export HYPE_ORACLE_ADDRESS=", hypeOracleAddress);
        console.log("2. To register your reserved names, run: forge script RegisterReservedNames");
        console.log("3. To check registered domains, run: forge script CheckDomains");
        console.log("----------------------------------------------------------------");
    }
} 