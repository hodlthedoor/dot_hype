// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeOnchainMetadataV3.sol";

/**
 * @title DeployDotHypeMetadataV3
 * @dev Deployment script for DotHype Onchain Metadata V3 contract
 *
 * Usage:
 * forge script script/DeployDotHypeMetadataV3.s.sol:DeployDotHypeMetadataV3 --sig "run()" --rpc-url $RPC_URL --broadcast --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployDotHypeMetadataV3 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address registryAddress = 0x69ab9d21B250a157B072F7bF162E8ea240CdD5B3;

        console.log("Deploying DotHypeOnchainMetadataV3 with address:", deployer);
        console.log("Registry address:", registryAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeOnchainMetadataV3 metadataV3 = new DotHypeOnchainMetadataV3(deployer, registryAddress);
        console.log("DotHypeOnchainMetadataV3 deployed at:", address(metadataV3));

        vm.stopBroadcast();

        console.log("--- Deployment Complete ---");
        console.log("DotHypeOnchainMetadataV3:", address(metadataV3));
    }
}
