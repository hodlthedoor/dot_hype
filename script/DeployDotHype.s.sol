// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/core/DotHypeDutchAuction.sol";
import "../src/core/DotHypeOnchainMetadata.sol";
import "../src/core/HypeOracle.sol";

/**
 * @title DeployDotHype
 * @dev Deployment script for DotHype contracts
 */
contract DeployDotHype is Script {
    // Price configuration (in USD with 18 decimals)
    uint256 constant PRICE_1_CHAR = 0 ether;            // $0
    uint256 constant PRICE_2_CHAR = 0 ether;            // $0
    uint256 constant PRICE_3_CHAR = 10 ether;           // $10
    uint256 constant PRICE_4_CHAR = 2 ether;            // $2
    uint256 constant PRICE_5PLUS_CHAR = 0.5 ether;      // $0.5

    // Renewal price configuration (in USD with 18 decimals)
    uint256 constant RENEWAL_1_CHAR = 15 ether;         // $15
    uint256 constant RENEWAL_2_CHAR = 10 ether;         // $10
    uint256 constant RENEWAL_3_CHAR = 8 ether;          // $8
    uint256 constant RENEWAL_4_CHAR = 1.6 ether;        // $1.6
    uint256 constant RENEWAL_5PLUS_CHAR = 0.4 ether;    // $0.4

    // Metadata base URI
    string constant METADATA_BASE_URI = "https://metadata.dothype.xyz/";

    function run() public {
        // Fetch the deployer's private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Log deployment info
        console.log("Deploying DotHype contracts with address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy HypeOracle
        HypeOracle oracle = new HypeOracle();
        console.log("HypeOracle deployed at:", address(oracle));
        
        // 2. Deploy DotHypeRegistry
        DotHypeRegistry registry = new DotHypeRegistry(deployer, deployer);
        console.log("DotHypeRegistry deployed at:", address(registry));
        
        // 3. Deploy DotHypeResolver
        DotHypeResolver resolver = new DotHypeResolver(deployer, address(registry));
        console.log("DotHypeResolver deployed at:", address(resolver));
        
        // 4. Deploy DotHypeMetadata (Online metadata provider)
        DotHypeOnchainMetadata metadata = new DotHypeOnchainMetadata(deployer, address(registry));
        console.log("DotHypeOnlineMetadata deployed at:", address(metadata));
        
        // 5. Set metadata provider in registry
        registry.setMetadataProvider(address(metadata));
        console.log("Set metadata provider in registry");
        
        // 6. Deploy DotHypeDutchAuction (which is a controller extension)
        // Params: registry address, signer address, price oracle address, owner address
        DotHypeDutchAuction dutchAuction = new DotHypeDutchAuction(
            address(registry),
            deployer,      // Signer - set to deployer initially
            address(oracle),
            deployer       // Owner
        );
        console.log("DotHypeDutchAuction deployed at:", address(dutchAuction));
        
        // 7. Set controller in registry
        registry.setController(address(dutchAuction));
        console.log("Set controller in registry to DutchAuction");
        
        // 8. Configure pricing in controller
        // Set annual registration prices
        dutchAuction.setAnnualPrice(1, PRICE_1_CHAR);  // 1 char
        dutchAuction.setAnnualPrice(2, PRICE_2_CHAR);  // 2 char
        dutchAuction.setAnnualPrice(3, PRICE_3_CHAR);  // 3 char
        dutchAuction.setAnnualPrice(4, PRICE_4_CHAR);  // 4 char
        dutchAuction.setAnnualPrice(5, PRICE_5PLUS_CHAR);  // 5+ char
        console.log("Set annual registration prices");
        
        // Set annual renewal prices
        dutchAuction.setAnnualRenewalPrice(1, RENEWAL_1_CHAR);  // 1 char
        dutchAuction.setAnnualRenewalPrice(2, RENEWAL_2_CHAR);  // 2 char
        dutchAuction.setAnnualRenewalPrice(3, RENEWAL_3_CHAR);  // 3 char
        dutchAuction.setAnnualRenewalPrice(4, RENEWAL_4_CHAR);  // 4 char
        dutchAuction.setAnnualRenewalPrice(5, RENEWAL_5PLUS_CHAR);  // 5+ char
        console.log("Set annual renewal prices");
        
        vm.stopBroadcast();
        
        // Log summary
        console.log("--- Deployment Complete ---");
        console.log("DotHypeRegistry:", address(registry));
        console.log("DotHypeResolver:", address(resolver));
        console.log("DotHypeOnlineMetadata:", address(metadata));
        console.log("HypeOracle:", address(oracle));
        console.log("DotHypeDutchAuction:", address(dutchAuction));
    }
} 