// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";

/**
 * @title SimpleDeployRegistry
 * @dev Very minimal script to deploy just the registry
 */
contract SimpleDeployRegistry is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Registry with address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Registry with deployer as both owner and controller
        DotHypeRegistry registry = new DotHypeRegistry(deployer, deployer);

        console.log("DotHypeRegistry deployed at:", address(registry));

        vm.stopBroadcast();
    }
}
