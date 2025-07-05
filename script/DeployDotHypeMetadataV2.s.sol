// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeOnchainMetadataV2.sol";

/**
 * @title DeployDotHypeMetadataV2
 * @dev Deployment script for DotHype Onchain Metadata V2 contract
 *
 * Usage:
 * forge script script/DeployDotHypeMetadataV2.s.sol:DeployDotHypeMetadataV2 --sig "run(address)" $REGISTRY_ADDRESS --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify
 */
contract DeployDotHypeMetadataV2 is Script {
    function run(address registryAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying DotHypeOnchainMetadataV2 with address:", deployer);
        console.log("Registry address:", registryAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeOnchainMetadataV2 metadataV2 = new DotHypeOnchainMetadataV2(deployer, registryAddress);
        console.log("DotHypeOnchainMetadataV2 deployed at:", address(metadataV2));

        vm.stopBroadcast();

        console.log("--- Deployment Complete ---");
        console.log("DotHypeOnchainMetadataV2:", address(metadataV2));
    }
}
