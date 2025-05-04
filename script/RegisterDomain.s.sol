// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.27;

// import "forge-std/Script.sol";
// import "../src/core/DotHypeController.sol";

// /**
//  * @title RegisterDomain
//  * @dev Registers a domain name using the DotHypeController
//  */
// contract RegisterDomain is Script {
//     function run() public {
//         // Required environment variables
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         address payable controllerAddress = payable(vm.envAddress("CONTROLLER_ADDRESS"));

//         // Optional environment variables with defaults
//         string memory domainName = vm.envOr("DOMAIN_NAME", string("myname"));
//         uint256 durationDays = vm.envOr("DURATION_DAYS", uint256(365));

//         // Convert duration to seconds
//         uint256 durationSeconds = durationDays * 24 * 60 * 60;

//         address registrant = vm.addr(deployerPrivateKey);

//         console.log("Registering domain:");
//         console.log("  Name:", domainName, ".hype");
//         console.log("  Duration:", durationDays, "days");
//         console.log("  Registrant:", registrant);

//         vm.startBroadcast(deployerPrivateKey);

//         // Get the controller contract
//         DotHypeController controller = DotHypeController(controllerAddress);

//         // Calculate registration fee
//         (uint256 fee, uint256 hypeAmount) = controller.calculateRegistrationFee(domainName, durationSeconds);
//         console.log("  Registration fee:", fee / 1e18, "HYPE");

//         // Register the domain
//         try controller.register{value: fee}(domainName, durationSeconds) {
//             console.log("Domain registered successfully!");
//         } catch Error(string memory reason) {
//             console.log("Registration failed:", reason);
//         } catch {
//             console.log("Registration failed with unknown error");
//         }

//         vm.stopBroadcast();
//     }
// }
