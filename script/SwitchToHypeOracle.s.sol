// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeController.sol";

/**
 * @title SwitchToHypeOracle
 * @dev Script to switch from MockOracle to HypeOracle
 */
contract SwitchToHypeOracle is Script {
    function run() public {
        // Get deployment addresses from environment or config
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        address hypeOracleAddress = vm.envAddress("HYPE_ORACLE_ADDRESS");
        
        // Get the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployer address
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Switching oracles with address:", deployer);
        
        // Get the controller contract
        DotHypeController controller = DotHypeController(controllerAddress);
        
        // Check current oracle
        address currentOracle = address(controller.priceOracle());
        console.log("Current oracle address:", currentOracle);
        console.log("Switching to HypeOracle at:", hypeOracleAddress);
        
        // Update the oracle
        controller.setPriceOracle(hypeOracleAddress);
        
        // Verify the change
        address newOracle = address(controller.priceOracle());
        console.log("New oracle address:", newOracle);
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        console.log("Oracle switch complete!");
    }
} 