// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";

/**
 * @title ReserveDomain
 * @dev Reserves a domain name using the controller contract's setReservation function
 */
contract ReserveDomain is Script {
    function run() public {
        // Required environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        
        // Domain to reserve
        string memory domainName = vm.envOr("DOMAIN_NAME", string("foobar"));
        address reservedFor = vm.envOr("RESERVED_FOR", vm.addr(deployerPrivateKey));
        
        console.log("Reserving domain:", domainName, ".hype");
        console.log("Reserved for:", reservedFor);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the controller contract
        DotHypeController controller = DotHypeController(payable(controllerAddress));
        
        // Reserve the domain using controller's setReservation method
        try controller.setReservation(domainName, reservedFor) {
            console.log("Domain successfully reserved!");
            
            // Verify the reservation
            (bool isReserved, address actualReservedFor) = controller.checkReservation(domainName);
            if (isReserved && actualReservedFor == reservedFor) {
                console.log("Reservation verified successfully!");
            } else {
                console.log("Reservation verification failed.");
            }
        } catch Error(string memory reason) {
            console.log("Reservation failed:", reason);
        } catch {
            console.log("Reservation failed with unknown error");
        }
        
        vm.stopBroadcast();
    }
}

/**
 * @title RegisterReservedDomain
 * @dev Registers a previously reserved domain
 */
contract RegisterReservedDomain is Script {
    function run() public {
        // Required environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        
        // Domain to register
        string memory domainName = vm.envOr("DOMAIN_NAME", string("foobar"));
        uint256 durationDays = vm.envOr("DURATION_DAYS", uint256(365));
        
        // Convert duration to seconds
        uint256 durationSeconds = durationDays * 24 * 60 * 60;
        
        address registrant = vm.addr(deployerPrivateKey);
        
        console.log("Registering reserved domain:");
        console.log("  Name:", domainName, ".hype");
        console.log("  Duration:", durationDays, "days");
        console.log("  Registrant:", registrant);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the controller contract
        DotHypeController controller = DotHypeController(controllerAddress);
        
        // Calculate price
        uint256 price = controller.calculatePrice(domainName, durationSeconds);
        console.log("  Registration price:", price, "HYPE");
        
        // Try to register the reserved domain with the calculated price
        try controller.registerReserved{value: price}(domainName, durationSeconds) returns (uint256 tokenId, uint256 expiry) {
            console.log("Reserved domain registered successfully!");
            console.log("  Token ID:", tokenId);
            console.log("  Expiry timestamp:", expiry);
        } catch Error(string memory reason) {
            console.log("Registration failed:", reason);
        } catch {
            console.log("Registration failed with unknown error");
        }
        
        vm.stopBroadcast();
    }
}

/**
 * @title RegisterDomain
 * @dev Registers a domain name directly (not reserved)
 */
contract RegisterDomain is Script {
    function run() public {
        // Required environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));
        
        // Domain to register
        string memory domainName = vm.envOr("DOMAIN_NAME", string("foobar"));
        uint256 durationDays = vm.envOr("DURATION_DAYS", uint256(365));
        
        // Convert duration to seconds
        uint256 durationSeconds = durationDays * 24 * 60 * 60;
        
        address registrant = vm.addr(deployerPrivateKey);
        
        console.log("Registering domain:");
        console.log("  Name:", domainName, ".hype");
        console.log("  Duration:", durationDays, "days");
        console.log("  Registrant:", registrant);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the controller contract
        DotHypeController controller = DotHypeController(controllerAddress);
        
        // Calculate registration fee
        uint256 price = controller.calculatePrice(domainName, durationSeconds);
        console.log("  Registration price:", price / 1e18, "HYPE");
        
        // Since direct registration via controller.register() isn't implemented,
        // we need to use registerWithSignature, but this requires a valid signature
        // which can't be easily generated in this script
        console.log("NOTE: Direct domain registration requires a valid signature.");
        console.log("Consider using the registerReserved function after reserving the domain.");
        
        // For demonstration purposes only - this would fail without a valid signature
        uint256 deadline = block.timestamp + 1 hours;
        uint256 maxPrice = price * 2; // Setting max price higher than calculated price
        bytes memory emptySignature = new bytes(0);
        
        try controller.registerWithSignature{value: price}(
            domainName, 
            registrant, 
            durationSeconds, 
            maxPrice, 
            deadline, 
            emptySignature
        ) returns (uint256 tokenId, uint256 expiry) {
            console.log("Domain registered successfully!");
            console.log("  Token ID:", tokenId);
            console.log("  Expiry timestamp:", expiry);
        } catch Error(string memory reason) {
            console.log("Registration failed:", reason);
            console.log("This is expected as we don't have a valid signature.");
        } catch {
            console.log("Registration failed with unknown error");
        }
        
        vm.stopBroadcast();
    }
} 