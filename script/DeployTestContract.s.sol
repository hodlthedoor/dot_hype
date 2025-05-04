// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/test/TestContract.sol";

// This works:
// forge script script/DeployTestContract.s.sol --broadcast --verify --verifier sourcify --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --chain-id 998

contract DeployTestContract is Script {
    function run() external {
        // Get private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast (all subsequent calls will be part of the transaction)
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract with constructor arguments
        TestContract testContract = new TestContract("Hello, Hyperliquid!", 42);

        // End broadcast
        vm.stopBroadcast();

        // Log the address for verification
        console.log("TestContract deployed at: %s", address(testContract));
        console.log("");
        console.log("To verify:");
        console.log("forge verify-contract %s src/test/TestContract.sol:TestContract", address(testContract));
        console.log("--constructor-args $(cast abi-encode \"constructor(string,uint256)\" \"Hello, Hyperliquid!\" 42)");
        console.log("--chain-id 998 --verifier sourcify");
    }
}
