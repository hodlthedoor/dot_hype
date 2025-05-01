// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/interfaces/IPriceOracle.sol";

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
 * @title DeployDotHype
 * @dev Script to deploy the complete DotHype infrastructure
 */
contract DeployDotHype is Script {
    function run() public {
        // Get the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployer address
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with address:", deployer);

        // 1. Deploy the MockOracle first
        MockOracle mockOracle = new MockOracle();
        console.log("MockOracle deployed at:", address(mockOracle));
        console.log("Conversion rate: 1 HYPE = $5000");
        
        // Test oracle conversion rate
        uint256 oneUsd = 1e18; // $1 with 18 decimals
        uint256 oneUsdInHype = mockOracle.usdToHype(oneUsd);
        console.log("$1 equals this many HYPE tokens:", oneUsdInHype);

        // 2. Deploy the Registry
        // We need to pass controller address, but controller doesn't exist yet
        // So we'll deploy with a dummy address and then update it
        address temporaryController = deployer;
        DotHypeRegistry registry = new DotHypeRegistry(deployer, temporaryController);
        console.log("DotHypeRegistry deployed at:", address(registry));

        // 3. Deploy the Controller
        // Create a signer address (you can replace this with any address)
        address signer = deployer; // Using deployer as signer for simplicity
        DotHypeController controller = new DotHypeController(
            address(registry),
            signer,
            address(mockOracle),
            deployer
        );
        console.log("DotHypeController deployed at:", address(controller));

        // 4. Update Registry's controller to the real controller address
        registry.setController(address(controller));
        console.log("Registry controller set to:", address(controller));

        // 5. Deploy the Resolver
        DotHypeResolver resolver = new DotHypeResolver(deployer, address(registry));
        console.log("DotHypeResolver deployed at:", address(resolver));
        
        // 6. Set up pricing in the Controller
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
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        console.log("DotHype deployment complete!");
        console.log("----------------------------------------------------------------");
        console.log("Registry:   ", address(registry));
        console.log("Controller: ", address(controller));
        console.log("Resolver:   ", address(resolver));
        console.log("MockOracle: ", address(mockOracle));
        console.log("----------------------------------------------------------------");
        console.log("MockOracle conversion rate: 1 HYPE = $5000");
        console.log("$1 equals", oneUsdInHype, "HYPE tokens");
    }
} 