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
    
    // Simple manual JSON parsing to avoid complexity
    function getAddressFromJson(string memory json, string memory key) internal pure returns (address) {
        // Look for the key in format: "key":"0x..."
        bytes memory jsonBytes = bytes(json);
        bytes memory keyBytes = bytes(string(abi.encodePacked("\"", key, "\":\"0x")));
        
        uint256 i = 0;
        while (i < jsonBytes.length - keyBytes.length) {
            bool found = true;
            for (uint256 j = 0; j < keyBytes.length; j++) {
                if (jsonBytes[i + j] != keyBytes[j]) {
                    found = false;
                    break;
                }
            }
            
            if (found) {
                // Found the key, now extract the address (40 hex chars after 0x)
                uint256 startPos = i + keyBytes.length;
                bytes memory addrBytes = new bytes(42); // 0x + 40 hex chars
                addrBytes[0] = "0";
                addrBytes[1] = "x";
                for (uint256 j = 0; j < 40; j++) {
                    addrBytes[j + 2] = jsonBytes[startPos + j];
                }
                return parseAddress(string(addrBytes));
            }
            i++;
        }
        return address(0);
    }
    
    // Parse address string to address
    function parseAddress(string memory addrStr) internal pure returns (address) {
        bytes memory addrBytes = bytes(addrStr);
        require(addrBytes.length == 42, "Invalid address length"); // 0x + 40 hex chars
        
        bytes32 value;
        for (uint256 i = 2; i < 42; i++) {
            bytes1 char = addrBytes[i];
            uint8 digit;
            
            if (char >= bytes1("0") && char <= bytes1("9")) {
                digit = uint8(char) - uint8(bytes1("0"));
            } else if (char >= bytes1("a") && char <= bytes1("f")) {
                digit = 10 + uint8(char) - uint8(bytes1("a"));
            } else if (char >= bytes1("A") && char <= bytes1("F")) {
                digit = 10 + uint8(char) - uint8(bytes1("A"));
            } else {
                revert("Invalid address character");
            }
            
            value = bytes32(uint256(value) * 16 + digit);
        }
        
        return address(uint160(uint256(value)));
    }
    
    // Load addresses from file if it exists, otherwise return empty struct
    function loadAddresses() internal returns (DeployedAddresses memory) {
        string memory filePath = "deployment_addresses.json";
        DeployedAddresses memory addresses;
        
        // Check if file exists
        if (vm.exists(filePath)) {
            string memory json = vm.readFile(filePath);
            
            // Manual parsing of addresses
            addresses.mockOracle = getAddressFromJson(json, "mockOracle");
            addresses.hypeOracle = getAddressFromJson(json, "hypeOracle");
            addresses.registry = getAddressFromJson(json, "registry");
            addresses.controller = payable(getAddressFromJson(json, "controller"));
            addresses.resolver = getAddressFromJson(json, "resolver");
        }
        
        return addresses;
    }
    
    // Save addresses to file
    function saveAddresses(DeployedAddresses memory addresses) internal {
        string memory filePath = "deployment_addresses.json";
        string memory json = string(abi.encodePacked(
            "{",
            "\"mockOracle\":\"", vm.toString(addresses.mockOracle), "\",",
            "\"hypeOracle\":\"", vm.toString(addresses.hypeOracle), "\",",
            "\"registry\":\"", vm.toString(addresses.registry), "\",",
            "\"controller\":\"", vm.toString(addresses.controller), "\",",
            "\"resolver\":\"", vm.toString(addresses.resolver), "\"",
            "}"
        ));
        
        vm.writeFile(filePath, json);
        console.log("Addresses saved to", filePath);
    }
}

/**
 * @title DeployOracles
 * @dev Deploys both the mock oracle and HypeOracle
 */
contract DeployOracles is DeployBase {
    function run() public {
        // Load existing addresses
        DeployedAddresses memory addresses = loadAddresses();
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Oracles ======");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MockOracle if not already deployed
        if (addresses.mockOracle == address(0)) {
            MockOracle mockOracle = new MockOracle();
            addresses.mockOracle = address(mockOracle);
            console.log("MockOracle deployed at:", addresses.mockOracle);
            
            uint256 oneUsd = 1e18; // $1 with 18 decimals
            uint256 oneUsdInHype = mockOracle.usdToHype(oneUsd);
            console.log("Mock rate: 1 HYPE = $5000, $1 =", oneUsdInHype, "HYPE");
        } else {
            console.log("Using existing MockOracle at:", addresses.mockOracle);
        }
        
        // Deploy HypeOracle if not already deployed
        if (addresses.hypeOracle == address(0)) {
            HypeOracle hypeOracle = new HypeOracle();
            addresses.hypeOracle = address(hypeOracle);
            console.log("HypeOracle deployed at:", addresses.hypeOracle);
        } else {
            console.log("Using existing HypeOracle at:", addresses.hypeOracle);
        }
        
        vm.stopBroadcast();
        
        // Save addresses
        saveAddresses(addresses);
        
        console.log("\n[SUCCESS] Oracles deployment complete");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:DeployRegistry --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title DeployRegistry
 * @dev Deploys the registry contract
 */
contract DeployRegistry is DeployBase {
    function run() public {
        // Load existing addresses
        DeployedAddresses memory addresses = loadAddresses();
        
        // Ensure oracles were deployed
        require(addresses.mockOracle != address(0), "MockOracle not deployed yet. Run DeployOracles first.");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Registry ======");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Registry if not already deployed
        if (addresses.registry == address(0)) {
            // Use deployer as temporary controller
            DotHypeRegistry registry = new DotHypeRegistry(deployer, deployer);
            addresses.registry = address(registry);
            console.log("DotHypeRegistry deployed at:", addresses.registry);
        } else {
            console.log("Using existing Registry at:", addresses.registry);
        }
        
        vm.stopBroadcast();
        
        // Save addresses
        saveAddresses(addresses);
        
        console.log("\n[SUCCESS] Registry deployment complete");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:DeployController --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title DeployController
 * @dev Deploys the controller contract and links it to the registry
 */
contract DeployController is DeployBase {
    function run() public {
        // Load existing addresses
        DeployedAddresses memory addresses = loadAddresses();
        
        // Ensure previous steps were completed
        require(addresses.mockOracle != address(0), "MockOracle not deployed yet");
        require(addresses.registry != address(0), "Registry not deployed yet");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Controller ======");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Controller if not already deployed
        if (addresses.controller == address(0)) {
            address signer = deployer; // Using deployer as signer for simplicity
            DotHypeController controller = new DotHypeController(
                addresses.registry,
                signer,
                addresses.mockOracle, // Initially connect to MockOracle
                deployer
            );
            addresses.controller = payable(address(controller));
            console.log("DotHypeController deployed at:", addresses.controller);
            
            // Update Registry's controller
            DotHypeRegistry registry = DotHypeRegistry(addresses.registry);
            registry.setController(addresses.controller);
            console.log("Registry controller updated to:", addresses.controller);
            
            // Set up pricing
            console.log("Setting up pricing...");
            controller.setAnnualPrice(1, type(uint256).max); // 1-char - unavailable
            controller.setAnnualPrice(2, type(uint256).max); // 2-char - unavailable
            controller.setAnnualPrice(3, 1000 * 1e18);       // 3-char - $1000/year
            controller.setAnnualPrice(4, 100 * 1e18);        // 4-char - $100/year
            controller.setAnnualPrice(5, 20 * 1e18);         // 5+ char - $20/year
            console.log("Pricing configured");
        } else {
            console.log("Using existing Controller at:", addresses.controller);
        }
        
        vm.stopBroadcast();
        
        // Save addresses
        saveAddresses(addresses);
        
        console.log("\n[SUCCESS] Controller deployment complete");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:DeployResolver --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title DeployResolver
 * @dev Deploys the resolver contract
 */
contract DeployResolver is DeployBase {
    function run() public {
        // Load existing addresses
        DeployedAddresses memory addresses = loadAddresses();
        
        // Ensure previous steps were completed
        require(addresses.registry != address(0), "Registry not deployed yet");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n====== Deploying Resolver ======");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Resolver if not already deployed
        if (addresses.resolver == address(0)) {
            DotHypeResolver resolver = new DotHypeResolver(deployer, addresses.registry);
            addresses.resolver = address(resolver);
            console.log("DotHypeResolver deployed at:", addresses.resolver);
        } else {
            console.log("Using existing Resolver at:", addresses.resolver);
        }
        
        vm.stopBroadcast();
        
        // Save addresses
        saveAddresses(addresses);
        
        console.log("\n[SUCCESS] Resolver deployment complete");
        console.log("\nNext step: Run 'forge script script/DeployForHyperliquid.s.sol:ReserveTestDomains --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998'");
    }
}

/**
 * @title ReserveTestNames
 * @dev Reserves test names after all contracts are deployed
 */
contract ReserveTestDomains is DeployBase {
    function run() public {
        // Load existing addresses
        DeployedAddresses memory addresses = loadAddresses();
        
        // Ensure controller is deployed
        require(addresses.controller != address(0), "Controller not deployed yet");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address secondAddress = 0xc2AbE12785B69349b9C85F9b6812D8894C8AB945;
        
        console.log("\n====== Reserving Test Domains ======");
        console.log("Deployer address:", deployer);
        console.log("Second address:", secondAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Use the controller contract
        // Handle the payable controller address correctly
        DotHypeController controller = DotHypeController(addresses.controller);
        
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
        printSummary(addresses, deployer, secondAddress);
    }
    
    function printSummary(
        DeployedAddresses memory addresses, 
        address deployer,
        address secondAddress
    ) internal view {
        console.log("\n====== Deployment Summary ======");
        console.log("Registry:   ", addresses.registry);
        console.log("Controller: ", addresses.controller);
        console.log("Resolver:   ", addresses.resolver);
        console.log("MockOracle: ", addresses.mockOracle);
        console.log("HypeOracle: ", addresses.hypeOracle);
        
        console.log("\nConfigured to use: MockOracle");
        console.log("To switch to real HypeOracle later, call:");
        console.log("controller.setPriceOracle(", addresses.hypeOracle, ")");
        
        console.log("\nTest domains:");
        console.log("Even numbers (test2, test4, etc.) reserved for:", deployer);
        console.log("Odd numbers (test1, test3, etc.) reserved for:", secondAddress);
        
        console.log("\n====== Environment Variables For Next Steps ======");
        console.log("Run these commands to set up environment variables:");
        console.log("export REGISTRY_ADDRESS=", addresses.registry);
        console.log("export CONTROLLER_ADDRESS=", addresses.controller);
        console.log("export RESOLVER_ADDRESS=", addresses.resolver);
        console.log("export MOCK_ORACLE_ADDRESS=", addresses.mockOracle);
        console.log("export HYPE_ORACLE_ADDRESS=", addresses.hypeOracle);
        
        console.log("\n====== Next Steps ======");
        console.log("1. To register your reserved domains:");
        console.log("   forge script script/RegisterReservedNames.s.sol --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998");
        console.log("2. To check registered domains:");
        console.log("   forge script script/CheckDomains.s.sol --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998");
        console.log("3. To switch to the real HypeOracle:");
        console.log("   forge script script/SwitchToHypeOracle.s.sol --broadcast --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998");
    }
} 