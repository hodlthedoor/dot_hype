// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeResolver.sol";

/**
 * @title LookupDomain
 * @dev Looks up information about a domain name
 */
contract LookupDomain is Script {
    function run() public {
        // Required environment variables
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address resolverAddress = vm.envAddress("RESOLVER_ADDRESS");
        
        // Domain to look up
        string memory domainName = vm.envOr("DOMAIN_NAME", string("myname"));
        
        console.log("Looking up domain:", domainName, ".hype");
        
        // Get contracts
        DotHypeRegistry registry = DotHypeRegistry(registryAddress);
        DotHypeResolver resolver = DotHypeResolver(resolverAddress);
        
        // Calculate token ID
        uint256 tokenId = registry.nameToTokenId(domainName);
        console.log("Token ID:", tokenId);
        
        // Convert tokenId to node (bytes32) for resolver
        bytes32 node = bytes32(tokenId);
        
        // Check if domain exists and get owner
        try registry.ownerOf(tokenId) returns (address owner) {
            console.log("Owner:", owner);
            
            // Get expiry
            try registry.expiryOf(tokenId) returns (uint256 expiry) {
                console.log("Expires at:", expiry);
                
                // Format expiry date
                string memory expiryDate = vm.toString(expiry);
                console.log("Expiry Date (timestamp):", expiryDate);
                
                // Check if domain is expired
                if (block.timestamp > expiry) {
                    console.log("Status: EXPIRED");
                } else {
                    console.log("Status: ACTIVE");
                }
                
                // Get days remaining
                if (expiry > block.timestamp) {
                    uint256 daysRemaining = (expiry - block.timestamp) / (24 * 60 * 60);
                    console.log("Days remaining:", daysRemaining);
                }
            } catch {
                console.log("Could not retrieve expiry information");
            }
            
            // Try to get resolved address using the node (bytes32)
            try resolver.addr(node) returns (address payable resolvedAddress) {
                if (resolvedAddress != address(0)) {
                    console.log("Resolves to address:", resolvedAddress);
                } else {
                    console.log("No address resolution set");
                }
            } catch {
                console.log("Could not retrieve resolver information");
            }
        } catch {
            console.log("Domain not registered");
        }
    }
} 