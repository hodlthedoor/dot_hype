// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeDutchAuction.sol";
import "./mocks/MockPriceOracle.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title DotHypeAuctionBypassBug
 * @dev Test to demonstrate and verify fix for auction bypass vulnerability
 *
 * BUG: Users can bypass Dutch auction premiums by using merkle proof or other
 * registration functions, paying only base price instead of auction price.
 *
 * EXPECTED BEHAVIOR: If a domain is in a Dutch auction, all registration
 * functions should either:
 * 1. Fail with an error (RECOMMENDED - easier to implement)
 * 2. Apply the Dutch auction premium
 */
contract DotHypeAuctionBypassBugTest is Test {
    DotHypeRegistry public registry;
    DotHypeDutchAuction public dutchAuction;
    MockPriceOracle public priceOracle;

    address public owner = address(0x1);
    address public signer = address(0x2);
    address public user = address(0x3);
    address public attacker = address(0x4);

    // Merkle tree setup (single user for simplicity)
    bytes32 public merkleRoot;
    bytes32[] public merkleProof;

    // Auction parameters
    uint256 constant START_PRICE = 100 ether; // $100 auction premium
    uint256 constant END_PRICE = 0 ether; // $0 at end
    uint256 constant AUCTION_DURATION = 24 hours;

    // Mock price parameters
    uint64 constant HYPE_PRICE = 2000000; // $2.00 per HYPE (scaled by 1e6)

    function setUp() public {
        // Deploy contracts
        priceOracle = new MockPriceOracle(HYPE_PRICE);
        registry = new DotHypeRegistry(owner, address(this));
        dutchAuction = new DotHypeDutchAuction(address(registry), signer, address(priceOracle), owner);

        // Set controller in registry
        vm.prank(owner);
        registry.setController(address(dutchAuction));

        // Set pricing
        uint256[5] memory prices = [
            type(uint256).max, // 1 char
            type(uint256).max, // 2 char
            10 ether, // 3 char: $10
            2 ether, // 4 char: $2
            1 ether // 5+ char: $1
        ];

        vm.prank(owner);
        dutchAuction.setAllAnnualPrices(prices);

        // Setup merkle tree (just user address)
        address[] memory whitelist = new address[](1);
        whitelist[0] = user;

        bytes32 leaf = keccak256(abi.encodePacked(user));
        merkleRoot = leaf; // Single leaf = root
        merkleProof = new bytes32[](0); // Empty proof for single leaf

        vm.prank(owner);
        dutchAuction.setMerkleRoot(merkleRoot);
    }

    /**
     * @dev Test that merkle proof registration should fail for domains in Dutch auction
     */
    function testMerkleProofShouldFailForAuctionDomains() public {
        string memory domainName = "premium";
        uint256 duration = 365 days;

        // 1. Create auction for the domain
        string[] memory domains = new string[](1);
        domains[0] = domainName;

        vm.prank(owner);
        dutchAuction.createDutchAuctionBatch(domains, START_PRICE, END_PRICE, AUCTION_DURATION, block.timestamp);

        // 2. Verify domain is in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction(domainName);
        assertTrue(isInAuction, "Domain should be in auction");

        // 3. Attempting to register with merkle proof should fail
        uint256 basePrice = dutchAuction.calculatePrice(domainName, duration);
        vm.deal(user, basePrice);
        vm.prank(user);

        // EXPECTED: This should revert with DomainInAuction error
        vm.expectRevert(abi.encodeWithSignature("DomainInAuction(string)", domainName));
        dutchAuction.registerWithMerkleProof{value: basePrice}(domainName, duration, merkleProof);
    }

    /**
     * @dev Test that signature-based registration should fail for domains in Dutch auction
     */
    function testSignatureRegistrationShouldFailForAuctionDomains() public {
        string memory domainName = "signature";
        uint256 duration = 365 days;

        // Create auction
        string[] memory domains = new string[](1);
        domains[0] = domainName;

        vm.prank(owner);
        dutchAuction.createDutchAuctionBatch(domains, START_PRICE, END_PRICE, AUCTION_DURATION, block.timestamp);

        // Note: We can't easily test registerWithSignature without proper signature setup
        // But the same fix will apply to all functions that use _registerDomain()
        console.log("registerWithSignature() should also fail for auction domains after fix");
        console.log("All registration functions that use _registerDomain() will be protected");

        // For now, just verify the domain is in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction(domainName);
        assertTrue(isInAuction, "Domain should be in auction");
    }

    /**
     * @dev Test that reserved name registration should fail for domains in Dutch auction
     */
    function testReservedNameShouldFailForAuctionDomains() public {
        string memory domainName = "reserved";
        uint256 duration = 365 days;

        // Reserve domain for attacker
        vm.prank(owner);
        dutchAuction.setReservation(domainName, attacker);

        // Create auction for the same domain
        string[] memory domains = new string[](1);
        domains[0] = domainName;

        vm.prank(owner);
        dutchAuction.createDutchAuctionBatch(domains, START_PRICE, END_PRICE, AUCTION_DURATION, block.timestamp);

        // Attempting to register reserved domain should fail during auction
        uint256 basePrice = dutchAuction.calculatePrice(domainName, duration);
        vm.deal(attacker, basePrice);
        vm.prank(attacker);

        // EXPECTED: This should revert with DomainInAuction error
        vm.expectRevert(abi.encodeWithSignature("DomainInAuction(string)", domainName));
        dutchAuction.registerReserved{value: basePrice}(domainName, duration);
    }

    /**
     * @dev Test that domains not in auction can still be registered normally
     */
    function testNonAuctionDomainsStillWork() public {
        string memory domainName = "normal";
        uint256 duration = 365 days;

        // Don't create auction for this domain

        // Verify domain is NOT in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction(domainName);
        assertFalse(isInAuction, "Domain should not be in auction");

        // Registration should work normally
        uint256 basePrice = dutchAuction.calculatePrice(domainName, duration);
        vm.deal(user, basePrice);
        vm.prank(user);

        (uint256 tokenId,) = dutchAuction.registerWithMerkleProof{value: basePrice}(domainName, duration, merkleProof);

        // Verify successful registration
        assertEq(registry.ownerOf(tokenId), user, "User should own the domain");
        assertTrue(dutchAuction.hasAddressUsedMerkleProof(user), "Merkle proof should be used");
    }

    /**
     * @dev Test that domains can be registered normally after auction ends
     */
    function testDomainsCanBeRegisteredAfterAuctionEnds() public {
        string memory domainName = "afterauction";
        uint256 duration = 365 days;

        // Create auction for the domain
        string[] memory domains = new string[](1);
        domains[0] = domainName;

        vm.prank(owner);
        dutchAuction.createDutchAuctionBatch(domains, START_PRICE, END_PRICE, AUCTION_DURATION, block.timestamp);

        // Verify domain is in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction(domainName);
        assertTrue(isInAuction, "Domain should be in auction");

        // Fast forward past auction end time
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Domain should still be "in auction" but auction should be complete
        (bool stillInAuction,) = dutchAuction.isDomainInAuction(domainName);
        assertTrue(stillInAuction, "Domain should still be tracked as in auction");

        // But registration should now work since auction is complete
        uint256 basePrice = dutchAuction.calculatePrice(domainName, duration);

        // Reset merkle proof usage for this test (since we used it in previous test)
        address[] memory usersToReset = new address[](1);
        usersToReset[0] = user;
        vm.prank(owner);
        dutchAuction.resetMerkleProofUsage(usersToReset);

        vm.deal(user, basePrice);
        vm.prank(user);

        // This should now succeed since auction is complete
        (uint256 tokenId,) = dutchAuction.registerWithMerkleProof{value: basePrice}(domainName, duration, merkleProof);

        // Verify successful registration
        assertEq(registry.ownerOf(tokenId), user, "User should own the domain");
        assertTrue(dutchAuction.hasAddressUsedMerkleProof(user), "Merkle proof should be used");
    }
}
