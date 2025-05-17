// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title GetTokenId
 * @dev Script to calculate the token ID for a domain name using the nameToTokenId logic
 * Usage: forge script script/GetTokenId.s.sol --sig "run(string)" "yourdomain"
 */
contract GetTokenId is Script {
    // Constants for namehash calculation (copied from DotHypeRegistry)
    bytes32 private constant EMPTY_NODE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 private constant TLD_NODE = keccak256(abi.encodePacked(EMPTY_NODE, keccak256(abi.encodePacked("hype"))));

    function run() external {
        string memory name = "samtest";
        console.log("\n===== DOMAIN NAME TO TOKEN ID CALCULATOR =====\n");
        console.log("Domain:", name, ".hype");

        // Calculate token ID using the same logic as in DotHypeRegistry
        uint256 tokenId = nameToTokenId(name);

        console.log("\nToken ID (decimal):");
        console.log(tokenId);

        console.log("\nToken ID (hex):");
        console.logBytes32(bytes32(tokenId));

        // Also output information for querying the contract
        console.log("\nTo get token information, run:");
        console.log("cast call <REGISTRY_ADDRESS> \"ownerOf(uint256)(address)\" %s --rpc-url <RPC_URL>", tokenId);
        console.log("cast call <REGISTRY_ADDRESS> \"tokenURI(uint256)(string)\" %s --rpc-url <RPC_URL>", tokenId);
    }

    /**
     * @dev Calculates token ID from name (copied from DotHypeRegistry)
     * @param label The domain name (without .hype extension)
     * @return tokenId The token ID
     */
    function nameToTokenId(string memory label) public pure returns (uint256 tokenId) {
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 namehash = keccak256(abi.encodePacked(TLD_NODE, labelhash));
        return uint256(namehash);
    }
}
