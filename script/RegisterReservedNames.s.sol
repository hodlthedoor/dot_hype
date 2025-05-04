// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeController.sol";

/**
 * @title RegisterReservedNames
 * @dev Script to register reserved test names owned by the caller
 */
contract RegisterReservedNames is Script {
    function run() public {
        // Get the controller address from the environment
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));

        // Get the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployer address (msg.sender)
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Registering reserved test names with address:", deployer);

        // Get the controller contract
        DotHypeController controller = DotHypeController(controllerAddress);

        // Registration duration - 1 year
        uint256 duration = 365 days;
        console.log("Registration duration:", duration, "seconds (1 year)");

        // Test names to register - we'll try all 10, but only the ones reserved for msg.sender will succeed
        for (uint256 i = 0; i < 10; i++) {
            string memory name = string(abi.encodePacked("test", vm.toString(i + 1)));

            (bool isReserved, address reservedFor) = controller.checkReservation(name);

            if (isReserved) {
                if (reservedFor == deployer) {
                    console.log("Attempting to register reserved name:", name);

                    try controller.registerReserved(name, duration) returns (uint256 tokenId, uint256 expiry) {
                        console.log("SUCCESS! Registered", name, "- Token ID:", tokenId);
                    } catch Error(string memory reason) {
                        console.log("FAILED to register", name, "- Reason:", reason);
                    } catch (bytes memory) {
                        console.log("FAILED to register", name, "(unknown error)");
                    }
                } else {
                    console.log("Skipping", name, "- Reserved for different address:", reservedFor);
                }
            } else {
                console.log("Skipping", name, "- Not reserved");
            }
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("Registration of reserved names complete!");
    }
}
