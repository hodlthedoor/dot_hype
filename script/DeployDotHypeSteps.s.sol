// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeResolver.sol";
import "../src/core/DotHypeDutchAuction.sol";
import "../src/core/DotHypeOnchainMetadataV2.sol";
import "../src/core/HypeOracle.sol";

/**
 * @title DeployDotHypeSteps
 * @dev Step-by-step deployment script for DotHype contracts
 *
 * Usage (with verification):
 * Step 1: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step1()" --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.dev/server
 * Step 2: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step2(address)" $ORACLE_ADDRESS --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify
 * Step 3: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step3(address)" $REGISTRY_ADDRESS --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify
 * Step 4: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step4(address)" $REGISTRY_ADDRESS --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify
 * Step 5: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step5(address,address)" $REGISTRY_ADDRESS $METADATA_ADDRESS --rpc-url $RPC_URL --broadcast
 * Step 6: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step6(address,address)" $REGISTRY_ADDRESS $HYPE_ORACLE_ADDRESS --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify
 * Step 7: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step7(address,address)" $REGISTRY_ADDRESS $DUTCH_AUCTION_ADDRESS --rpc-url $RPC_URL --broadcast
 * Step 8: forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig "step8(address)" $DUTCH_AUCTION_ADDRESS --rpc-url $RPC_URL --broadcast
 */
contract DeployDotHypeSteps is Script {
    // Price configuration (in USD with 18 decimals)
    uint256 constant PRICE_1_CHAR = 0 ether; // $0
    uint256 constant PRICE_2_CHAR = 0 ether; // $0
    uint256 constant PRICE_3_CHAR = 10 ether; // $10
    uint256 constant PRICE_4_CHAR = 2 ether; // $2
    uint256 constant PRICE_5PLUS_CHAR = 0.5 ether; // $0.5

    // Renewal price configuration (in USD with 18 decimals)
    uint256 constant RENEWAL_1_CHAR = 15 ether; // $15
    uint256 constant RENEWAL_2_CHAR = 10 ether; // $10
    uint256 constant RENEWAL_3_CHAR = 8 ether; // $8
    uint256 constant RENEWAL_4_CHAR = 1.6 ether; // $1.6
    uint256 constant RENEWAL_5PLUS_CHAR = 0.4 ether; // $0.4

    /**
     * @dev Step 1: Deploy HypeOracle
     */
    function step1() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 1: Deploy HypeOracle ===");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        HypeOracle oracle = new HypeOracle();
        console.log("HypeOracle deployed at:", address(oracle));

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 1 COMPLETE!");
        console.log("VERIFICATION: To verify this contract, run:");
        console.log("forge verify-contract");
        console.log(address(oracle));
        console.log(
            "src/core/HypeOracle.sol:HypeOracle --rpc-url hyperliquid-test --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify --chain-id 998 --compiler-version v0.8.27+commit.6d32f4a7"
        );
        console.log("");
        console.log("NEXT STEP: Run step2 with the oracle address:");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step2(address)\"");
        console.log(address(oracle));
        console.log(
            "--rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
    }

    /**
     * @dev Step 2: Deploy DotHypeRegistry
     * @param oracleAddress Address of the deployed HypeOracle
     */
    function step2(address oracleAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 2: Deploy DotHypeRegistry ===");
        console.log("Deployer address:", deployer);
        console.log("Oracle address:", oracleAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeRegistry registry = new DotHypeRegistry(deployer, deployer);
        console.log("DotHypeRegistry deployed at:", address(registry));

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 2 COMPLETE!");
        console.log("VERIFICATION: To verify this contract, run:");
        console.log("forge verify-contract");
        console.log(address(registry));
        console.log(
            "src/core/DotHypeRegistry.sol:DotHypeRegistry --rpc-url hyperliquid-test --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify --chain-id 998 --compiler-version v0.8.27+commit.6d32f4a7 --constructor-args $(cast abi-encode \"constructor(address,address)\""
        );
        console.log(deployer);
        console.log(deployer);
        console.log(")");
        console.log("");
        console.log("NEXT STEP: Run step3 with the registry address:");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step3(address)\"");
        console.log(address(registry));
        console.log(
            "--rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
    }

    /**
     * @dev Step 3: Deploy DotHypeResolver
     * @param registryAddress Address of the deployed DotHypeRegistry
     */
    function step3(address registryAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 3: Deploy DotHypeResolver ===");
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeResolver resolver = new DotHypeResolver(deployer, registryAddress);
        console.log("DotHypeResolver deployed at:", address(resolver));

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 3 COMPLETE!");
        console.log("VERIFICATION: To verify this contract, run:");
        console.log("forge verify-contract");
        console.log(address(resolver));
        console.log(
            "src/core/DotHypeResolver.sol:DotHypeResolver --rpc-url hyperliquid-test --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify --chain-id 998 --compiler-version v0.8.27+commit.6d32f4a7 --constructor-args $(cast abi-encode \"constructor(address,address)\""
        );
        console.log(deployer);
        console.log(registryAddress);
        console.log(")");
        console.log("");
        console.log("NEXT STEP: Run step4 with the registry address:");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step4(address)\"");
        console.log(registryAddress);
        console.log(
            "--rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
    }

    /**
     * @dev Step 4: Deploy DotHypeOnchainMetadata
     * @param registryAddress Address of the deployed DotHypeRegistry
     */
    function step4(address registryAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 4: Deploy DotHypeOnchainMetadata ===");
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeOnchainMetadataV2 metadata = new DotHypeOnchainMetadataV2(deployer, registryAddress);
        console.log("DotHypeOnchainMetadata deployed at:", address(metadata));

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 4 COMPLETE!");
        console.log("VERIFICATION: To verify this contract, run:");
        console.log("forge verify-contract");
        console.log(address(metadata));
        console.log(
            "src/core/DotHypeOnchainMetadata.sol:DotHypeOnchainMetadata --rpc-url hyperliquid-test --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify --chain-id 998 --compiler-version v0.8.27+commit.6d32f4a7 --constructor-args $(cast abi-encode \"constructor(address,address)\""
        );
        console.log(deployer);
        console.log(registryAddress);
        console.log(")");
        console.log("");
        console.log("NEXT STEP: Run step5 with registry and metadata addresses:");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step5(address,address)\"");
        console.log(registryAddress);
        console.log(address(metadata));
        console.log("--rpc-url $RPC_URL --broadcast");
        console.log("");
    }

    /**
     * @dev Step 5: Set metadata provider in registry
     * @param registryAddress Address of the deployed DotHypeRegistry
     * @param metadataAddress Address of the deployed DotHypeOnchainMetadata
     */
    function step5(address registryAddress, address metadataAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 5: Set Metadata Provider ===");
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);
        console.log("Metadata address:", metadataAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        registry.setMetadataProvider(metadataAddress);
        console.log("Metadata provider set in registry");

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 5 COMPLETE!");
        console.log("NEXT STEP: Run step6 with registry and oracle addresses:");
        console.log("Note: You'll need the oracle address from step 1");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step6(address,address)\"");
        console.log(registryAddress);
        console.log(
            "<ORACLE_ADDRESS> --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
    }

    /**
     * @dev Step 6: Deploy DotHypeDutchAuction
     * @param registryAddress Address of the deployed DotHypeRegistry
     * @param oracleAddress Address of the deployed HypeOracle
     */
    function step6(address registryAddress, address oracleAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 6: Deploy DotHypeDutchAuction ===");
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);
        console.log("Oracle address:", oracleAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeDutchAuction dutchAuction = new DotHypeDutchAuction(
            registryAddress,
            deployer, // Signer - set to deployer initially
            oracleAddress,
            deployer // Owner
        );
        console.log("DotHypeDutchAuction deployed at:", address(dutchAuction));

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 6 COMPLETE!");
        console.log("VERIFICATION: To verify this contract, run:");
        console.log("forge verify-contract");
        console.log(address(dutchAuction));
        console.log(
            "src/core/DotHypeDutchAuction.sol:DotHypeDutchAuction --rpc-url hyperliquid-test --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify --chain-id 998 --compiler-version v0.8.27+commit.6d32f4a7 --constructor-args $(cast abi-encode \"constructor(address,address,address,address)\""
        );
        console.log(registryAddress);
        console.log(deployer);
        console.log(oracleAddress);
        console.log(deployer);
        console.log(")");
        console.log("");
        console.log("NEXT STEP: Run step7 with registry and dutch auction addresses:");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step7(address,address)\"");
        console.log(registryAddress);
        console.log(address(dutchAuction));
        console.log("--rpc-url $RPC_URL --broadcast");
        console.log("");
    }

    /**
     * @dev Step 7: Set controller in registry
     * @param registryAddress Address of the deployed DotHypeRegistry
     * @param dutchAuctionAddress Address of the deployed DotHypeDutchAuction
     */
    function step7(address registryAddress, address dutchAuctionAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 7: Set Controller ===");
        console.log("Deployer address:", deployer);
        console.log("Registry address:", registryAddress);
        console.log("Dutch Auction address:", dutchAuctionAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        registry.setController(dutchAuctionAddress);
        console.log("Controller set in registry to DutchAuction");

        vm.stopBroadcast();

        console.log("");
        console.log("STEP 7 COMPLETE!");
        console.log("NEXT STEP: Run step8 with dutch auction address:");
        console.log("forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step8(address)\"");
        console.log(dutchAuctionAddress);
        console.log("--rpc-url $RPC_URL --broadcast");
        console.log("");
    }

    /**
     * @dev Step 8: Configure pricing (Final step)
     * @param dutchAuctionAddress Address of the deployed DotHypeDutchAuction
     */
    function step8(address dutchAuctionAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 8: Configure Pricing (Final Step) ===");
        console.log("Deployer address:", deployer);
        console.log("Dutch Auction address:", dutchAuctionAddress);

        vm.startBroadcast(deployerPrivateKey);

        DotHypeDutchAuction dutchAuction = DotHypeDutchAuction(payable(dutchAuctionAddress));

        // Set annual registration prices
        console.log("Setting annual registration prices...");
        dutchAuction.setAnnualPrice(1, PRICE_1_CHAR); // 1 char
        dutchAuction.setAnnualPrice(2, PRICE_2_CHAR); // 2 char
        dutchAuction.setAnnualPrice(3, PRICE_3_CHAR); // 3 char
        dutchAuction.setAnnualPrice(4, PRICE_4_CHAR); // 4 char
        dutchAuction.setAnnualPrice(5, PRICE_5PLUS_CHAR); // 5+ char
        console.log("Annual registration prices set");

        // Set annual renewal prices
        console.log("Setting annual renewal prices...");
        dutchAuction.setAnnualRenewalPrice(1, RENEWAL_1_CHAR); // 1 char
        dutchAuction.setAnnualRenewalPrice(2, RENEWAL_2_CHAR); // 2 char
        dutchAuction.setAnnualRenewalPrice(3, RENEWAL_3_CHAR); // 3 char
        dutchAuction.setAnnualRenewalPrice(4, RENEWAL_4_CHAR); // 4 char
        dutchAuction.setAnnualRenewalPrice(5, RENEWAL_5PLUS_CHAR); // 5+ char
        console.log("Annual renewal prices set");

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT AND CONFIGURATION COMPLETE! ===");
        console.log("DotHype deployment finished successfully!");
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("All contracts have been deployed and configured.");
        console.log("The system is now ready for use!");
        console.log("");
        console.log("OPTIONAL SECURITY STEP:");
        console.log("For production deployments, consider running Step 9 to transfer ownership:");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step9(address,address,address,address,address)\""
        );
        console.log("# Arguments: <REGISTRY> <RESOLVER> <METADATA> <DUTCH_AUCTION> <NEW_OWNER>");
        console.log("# Example addresses from this deployment:");
        console.log("# Registry:", dutchAuctionAddress, "# (replace with actual registry address)");
        console.log("# Resolver: <resolver_address>");
        console.log("# Metadata: <metadata_address>");
        console.log("# DutchAuction:", dutchAuctionAddress);
        console.log("# NewOwner: <your_secure_address>");
        console.log("");
        console.log("Registration Prices:");
        console.log("- 1 char: $0");
        console.log("- 2 char: $0");
        console.log("- 3 char: $10");
        console.log("- 4 char: $2");
        console.log("- 5+ char: $0.5");
        console.log("");
        console.log("Renewal Prices:");
        console.log("- 1 char: $15");
        console.log("- 2 char: $10");
        console.log("- 3 char: $8");
        console.log("- 4 char: $1.6");
        console.log("- 5+ char: $0.4");
        console.log("");
    }

    /**
     * @dev Step 9: Transfer ownership of all contracts to a new address
     * @param registryAddress Address of the deployed DotHypeRegistry
     * @param resolverAddress Address of the deployed DotHypeResolver
     * @param metadataAddress Address of the deployed DotHypeOnchainMetadata
     * @param dutchAuctionAddress Address of the deployed DotHypeDutchAuction
     * @param newOwner Address to transfer ownership to
     */
    function step9(
        address registryAddress,
        address resolverAddress,
        address metadataAddress,
        address dutchAuctionAddress,
        address newOwner
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STEP 9: Transfer Ownership (Final Security Step) ===");
        console.log("Current owner (deployer):", deployer);
        console.log("New owner:", newOwner);
        console.log("Registry address:", registryAddress);
        console.log("Resolver address:", resolverAddress);
        console.log("Metadata address:", metadataAddress);
        console.log("Dutch Auction address:", dutchAuctionAddress);

        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != deployer, "New owner must be different from current owner");

        vm.startBroadcast(deployerPrivateKey);

        // Transfer ownership of DotHypeRegistry
        console.log("Transferring DotHypeRegistry ownership...");
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        registry.transferOwnership(newOwner);

        // Transfer ownership of DotHypeResolver
        console.log("Transferring DotHypeResolver ownership...");
        DotHypeResolver resolver = DotHypeResolver(resolverAddress);
        resolver.transferOwnership(newOwner);

        // Transfer ownership of DotHypeOnchainMetadata
        console.log("Transferring DotHypeOnchainMetadata ownership...");
        DotHypeOnchainMetadataV2 metadata = DotHypeOnchainMetadataV2(metadataAddress);
        metadata.transferOwnership(newOwner);

        // Transfer ownership of DotHypeDutchAuction
        console.log("Transferring DotHypeDutchAuction ownership...");
        DotHypeDutchAuction dutchAuction = DotHypeDutchAuction(payable(dutchAuctionAddress));
        dutchAuction.transferOwnership(newOwner);

        vm.stopBroadcast();

        console.log("");
        console.log("=== OWNERSHIP TRANSFER COMPLETE! ===");
        console.log("All contracts have been transferred to:", newOwner);
        console.log("");
        console.log("IMPORTANT SECURITY NOTES:");
        console.log("1. Ownership has been immediately transferred (single-step process)");
        console.log("2. The new owner now has full control of all contracts");
        console.log("3. Make sure the new owner address is secure and accessible");
        console.log("4. The deployer no longer has any control over the contracts");
        console.log("");
        console.log("VERIFICATION:");
        console.log("You can verify the ownership transfer by checking the owner() function:");
        console.log("");
        console.log("# Check DotHypeRegistry owner");
        console.log("cast call");
        console.log(registryAddress);
        console.log("\"owner()\" --rpc-url $RPC_URL");
        console.log("");
        console.log("# Check DotHypeResolver owner");
        console.log("cast call");
        console.log(resolverAddress);
        console.log("\"owner()\" --rpc-url $RPC_URL");
        console.log("");
        console.log("# Check DotHypeOnchainMetadata owner");
        console.log("cast call");
        console.log(metadataAddress);
        console.log("\"owner()\" --rpc-url $RPC_URL");
        console.log("");
        console.log("# Check DotHypeDutchAuction owner");
        console.log("cast call");
        console.log(dutchAuctionAddress);
        console.log("\"owner()\" --rpc-url $RPC_URL");
        console.log("");
        console.log("=== DEPLOYMENT AND OWNERSHIP TRANSFER COMPLETE! ===");
        console.log("Your DotHype system is now fully deployed and secured!");
    }

    /**
     * @dev Helper function to display all steps
     */
    function showSteps() public pure {
        console.log("=== DotHype Step-by-Step Deployment Guide (with Verification) ===");
        console.log("");
        console.log("Step 1: Deploy HypeOracle");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step1()\" --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
        console.log("Step 2: Deploy DotHypeRegistry");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step2(address)\" <ORACLE_ADDRESS> --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
        console.log("Step 3: Deploy DotHypeResolver");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step3(address)\" <REGISTRY_ADDRESS> --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
        console.log("Step 4: Deploy DotHypeOnchainMetadata");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step4(address)\" <REGISTRY_ADDRESS> --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
        console.log("Step 5: Set Metadata Provider (no verification needed)");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step5(address,address)\" <REGISTRY_ADDRESS> <METADATA_ADDRESS> --rpc-url $RPC_URL --broadcast"
        );
        console.log("");
        console.log("Step 6: Deploy DotHypeDutchAuction");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step6(address,address)\" <REGISTRY_ADDRESS> <ORACLE_ADDRESS> --rpc-url $RPC_URL --broadcast --verifier sourcify --verifier-url https://sourcify.parsec.finance/verify"
        );
        console.log("");
        console.log("Step 7: Set Controller (no verification needed)");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step7(address,address)\" <REGISTRY_ADDRESS> <DUTCH_AUCTION_ADDRESS> --rpc-url $RPC_URL --broadcast"
        );
        console.log("");
        console.log("Step 8: Configure Pricing (no verification needed)");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step8(address)\" <DUTCH_AUCTION_ADDRESS> --rpc-url $RPC_URL --broadcast"
        );
        console.log("");
        console.log("Step 9: Transfer Ownership (optional security step)");
        console.log(
            "forge script script/DeployDotHypeSteps.s.sol:DeployDotHypeSteps --sig \"step9(address,address,address,address,address)\" <REGISTRY_ADDRESS> <RESOLVER_ADDRESS> <METADATA_ADDRESS> <DUTCH_AUCTION_ADDRESS> <NEW_OWNER_ADDRESS> --rpc-url $RPC_URL --broadcast"
        );
        console.log("");
        console.log(
            "NOTE: Each deployment step will also output the manual verification command if automatic verification fails."
        );
    }
}
