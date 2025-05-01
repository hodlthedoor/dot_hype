// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeController.sol";

/**
 * @title ReserveTestNames
 * @dev Script to reserve test names for the deployer and a specific address
 */
contract ReserveTestNames is Script {
    function run() public {
        // Get the controller address from the environment
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        
        // Get the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployer address (msg.sender)
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Reserving test names with deployer address:", deployer);
        
        // The second address to reserve names for
        address secondAddress = 0xc2AbE12785B69349b9C85F9b6812D8894C8AB945;
        console.log("And second address:", secondAddress);
        
        // Get the controller contract
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
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        console.log("Test name reservations complete!");
    }
} 