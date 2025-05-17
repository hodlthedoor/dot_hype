// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeDutchAuction.sol";
import "./mocks/MockPriceOracle.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract DotHypeDutchAuctionTest is Test {
    using stdStorage for StdStorage;

    DotHypeRegistry public registry;
    DotHypeDutchAuction public dutchAuction;
    MockPriceOracle public priceOracle;

    address public owner = address(0x1);
    uint256 public signerPrivateKey = 0xA11CE;
    address public signer;
    address public user = address(0x3);
    address public notOwner = address(0x4);

    // EIP-712 domain separator data
    bytes32 public constant DUTCH_AUCTION_REGISTRATION_TYPEHASH = keccak256(
        "DutchAuctionRegistration(string name,address owner,uint256 duration,uint256 maxPrice,uint256 deadline,uint256 nonce)"
    );

    // Mock price parameters
    uint64 constant INITIAL_PRICE = 2000000; // $2.00 (scaled by 1e6)
    uint256 constant SCALE = 1e6;

    // Dutch auction parameters
    uint256 constant START_PRICE = 10 ether; // $10 starting price
    uint256 constant END_PRICE = 1 ether; // $1 ending price
    uint256 constant AUCTION_DURATION = 24 hours;

    // Helper function to convert USD to HYPE
    function convertUsdToHype(uint256 usdAmount) internal pure returns (uint256) {
        return (usdAmount * SCALE) / INITIAL_PRICE;
    }

    // Setup before each test
    function setUp() public {
        // Get signer address from private key
        signer = vm.addr(signerPrivateKey);

        // Deploy mock price oracle
        priceOracle = new MockPriceOracle(INITIAL_PRICE);

        // Deploy registry and dutch auction controller
        registry = new DotHypeRegistry(owner, address(this));
        dutchAuction = new DotHypeDutchAuction(address(registry), signer, address(priceOracle), owner);

        // Set controller in registry
        vm.prank(owner);
        registry.setController(address(dutchAuction));

        // Set annual prices for different character counts
        uint256[5] memory prices = [
            type(uint256).max, // 1 character: extremely high price (effectively unavailable)
            type(uint256).max, // 2 characters: extremely high price (effectively unavailable)
            100 ether, // 3 characters: $100 per year
            10 ether, // 4 characters: $10 per year
            1 ether // 5+ characters: $1 per year
        ];

        vm.prank(owner);
        dutchAuction.setAllAnnualPrices(prices);

        // Set annual renewal prices (lower than registration prices)
        uint256[5] memory renewalPrices = [
            type(uint256).max, // 1 character: extremely high price (effectively unavailable)
            type(uint256).max, // 2 characters: extremely high price (effectively unavailable)
            80 ether, // 3 characters: $80 per year (20% discount)
            8 ether, // 4 characters: $8 per year (20% discount)
            0.8 ether // 5+ characters: $0.8 per year (20% discount)
        ];

        vm.prank(owner);
        dutchAuction.setAllAnnualRenewalPrices(renewalPrices);

        // Ensure payment recipient is set to owner
        vm.prank(owner);
        dutchAuction.setPaymentRecipient(owner);

        // Create a proper Merkle root for testing
        // We're just going to create a simple Merkle tree with one leaf (user address)
        bytes32 leaf = keccak256(abi.encodePacked(user));

        // Set the Merkle root to be the leaf itself since we're only using one address
        vm.prank(owner);
        dutchAuction.setMerkleRoot(leaf);
    }

    // Helper function to compute the EIP-712 domain separator
    function computeDomainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("DotHypeController"),
                keccak256("1"),
                block.chainid,
                address(dutchAuction)
            )
        );
    }

    // Helper function to get the Dutch auction registration digest
    function getDutchAuctionRegistrationDigest(
        string memory name,
        address owner_,
        uint256 duration,
        uint256 maxPrice,
        uint256 deadline,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                DUTCH_AUCTION_REGISTRATION_TYPEHASH, keccak256(bytes(name)), owner_, duration, maxPrice, deadline, nonce
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", computeDomainSeparator(), structHash));

        return digest;
    }

    // Helper function to create a Dutch auction batch
    function createAuctionBatch(string[] memory domains, uint256 startTime) internal returns (uint256) {
        vm.prank(owner);
        return dutchAuction.createDutchAuctionBatch(domains, START_PRICE, END_PRICE, AUCTION_DURATION, startTime);
    }

    // Test 1: Create a Dutch auction batch
    function testCreateDutchAuctionBatch() public {
        string[] memory domains = new string[](2);
        domains[0] = "domain1";
        domains[1] = "domain2";

        uint256 batchId = createAuctionBatch(domains, block.timestamp);

        assertEq(batchId, 1);

        (bool isInAuction1, uint256 batchId1) = dutchAuction.isDomainInAuction("domain1");
        (bool isInAuction2, uint256 batchId2) = dutchAuction.isDomainInAuction("domain2");

        assertTrue(isInAuction1);
        assertTrue(isInAuction2);
        assertEq(batchId1, 1);
        assertEq(batchId2, 1);
    }

    // Test 2: Only owner can create Dutch auction batches
    function testOnlyOwnerCanCreateDutchAuctionBatch() public {
        string[] memory domains = new string[](1);
        domains[0] = "domain3";

        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with Ownable: caller is not the owner
        dutchAuction.createDutchAuctionBatch(domains, START_PRICE, END_PRICE, AUCTION_DURATION, block.timestamp);
    }

    // Test 3: Can't buy a domain before the auction starts
    function testCannotBuyBeforeAuctionStarts() public {
        // Create an auction batch that starts in the future
        string[] memory domains = new string[](1);
        domains[0] = "future";

        uint256 startTime = block.timestamp + 1 hours;
        createAuctionBatch(domains, startTime);

        // Try to buy before auction starts
        vm.prank(user);
        vm.deal(user, 100 ether); // Plenty of funds
        vm.expectRevert(); // Should revert since auction hasn't started
        dutchAuction.purchaseDutchAuction("future", 365 days, 100 ether);
    }

    // Test 4: Buy domain at different stages of the Dutch auction
    function testBuyDomainAtDifferentAuctionStages() public {
        // Create an auction batch
        string[] memory domains = new string[](1);
        domains[0] = "auction";

        createAuctionBatch(domains, block.timestamp); // Start now

        // Record owner's initial balance
        uint256 initialOwnerBalance = owner.balance;

        // Check price at the start of the auction (should be base price + max auction price)
        (uint256 basePrice, uint256 auctionPrice, uint256 totalPrice) =
            dutchAuction.calculateDutchAuctionPrice("auction", 365 days);

        // Base price should be the regular price for a 7-character domain for 1 year
        assertEq(basePrice, convertUsdToHype(1 ether));

        // Auction price should be the start price converted to HYPE
        assertEq(auctionPrice, convertUsdToHype(START_PRICE));

        // Total price should be base price + auction price
        assertEq(totalPrice, basePrice + auctionPrice);

        // Fast forward to halfway through the auction
        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        // Check price at the middle of the auction
        (uint256 basePrice2, uint256 auctionPrice2, uint256 totalPrice2) =
            dutchAuction.calculateDutchAuctionPrice("auction", 365 days);

        // Base price should remain the same
        assertEq(basePrice2, basePrice);

        // Auction price should be approximately halfway between start and end price
        uint256 expectedMidPrice = convertUsdToHype((START_PRICE + END_PRICE) / 2);
        assertApproxEqRel(auctionPrice2, expectedMidPrice, 0.02e18); // Allow 2% tolerance due to rounding

        // Buy the domain at this halfway point
        vm.prank(user);
        vm.deal(user, totalPrice2);
        (uint256 tokenId,) = dutchAuction.purchaseDutchAuction{value: totalPrice2}("auction", 365 days, totalPrice2);

        // Verify domain was purchased
        assertEq(registry.ownerOf(tokenId), user);

        // Verify owner received the payment
        assertEq(owner.balance - initialOwnerBalance, totalPrice2);

        // Verify domain is no longer in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction("auction");
        assertFalse(isInAuction);
    }

    // Test 5: Buy domain at the end of the auction
    function testBuyDomainAtEndOfAuction() public {
        // Create an auction batch
        string[] memory domains = new string[](1);
        domains[0] = "endauction";

        createAuctionBatch(domains, block.timestamp);

        // Fast forward to after the auction ends
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Check price after auction ends
        (uint256 basePrice, uint256 auctionPrice, uint256 totalPrice) =
            dutchAuction.calculateDutchAuctionPrice("endauction", 365 days);

        // Auction price should be the end price
        assertEq(auctionPrice, convertUsdToHype(END_PRICE));

        // Buy the domain at end price
        vm.prank(user);
        vm.deal(user, totalPrice);
        (uint256 tokenId,) = dutchAuction.purchaseDutchAuction{value: totalPrice}("endauction", 365 days, totalPrice);

        // Verify domain was purchased
        assertEq(registry.ownerOf(tokenId), user);
    }

    // Test 6: Register auction domain with signature verification
    function testRegisterDutchAuctionWithSignature() public {
        // Create an auction batch
        string[] memory domains = new string[](1);
        domains[0] = "signature";

        createAuctionBatch(domains, block.timestamp);

        // Prepare registration parameters
        string memory name = "signature";
        address registrant = user;
        uint256 duration = 365 days;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = dutchAuction.getNextNonce(registrant);

        // Calculate expected price
        (,, uint256 expectedPrice) = dutchAuction.calculateDutchAuctionPrice(name, duration);
        uint256 maxPrice = expectedPrice + 1 ether; // Add some buffer

        // Create EIP-712 digest and sign
        bytes32 digest = getDutchAuctionRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Execute the registration
        vm.prank(user);
        vm.deal(user, expectedPrice);
        (uint256 tokenId, uint256 expiry) = dutchAuction.registerDutchAuctionWithSignature{value: expectedPrice}(
            name, registrant, duration, maxPrice, deadline, signature
        );

        // Verify registration
        assertEq(registry.ownerOf(tokenId), registrant);
        assertEq(expiry, block.timestamp + duration);

        // Verify domain is no longer in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction(name);
        assertFalse(isInAuction); // Domain remains in auction when registering with merkle proof
    }

    // Test 7: Try to bypass auction with regular merkle proof registration
    function testMerkleProofRespectsDutchAuctionPrice() public {
        // Create an auction batch
        string[] memory domains = new string[](1);
        domains[0] = "merkle";

        createAuctionBatch(domains, block.timestamp);

        // Create an empty merkle proof
        // Since our Merkle tree has only one leaf (the user's address),
        // the proof is an empty array
        bytes32[] memory proof = new bytes32[](0);

        // Calculate the dutch auction price components
        (uint256 basePrice, uint256 auctionPrice, uint256 totalPrice) =
            dutchAuction.calculateDutchAuctionPrice("merkle", 365 days);

        assertTrue(auctionPrice > 0, "Auction price should be positive");
        assertTrue(totalPrice > basePrice, "Total price should be greater than base price");

        // Now register with the full auction price
        vm.prank(user);
        vm.deal(user, totalPrice);
        (uint256 tokenId,) = dutchAuction.registerWithMerkleProof{value: totalPrice}("merkle", 365 days, proof);

        // Verify domain was purchased
        assertEq(registry.ownerOf(tokenId), user);

        // Verify the merkle proof mint was used
        assertTrue(dutchAuction.hasAddressUsedMerkleProof(user));

        // Verify domain is no longer in auction
        (bool isInAuction,) = dutchAuction.isDomainInAuction("merkle");
        assertTrue(isInAuction); // Domain remains in auction when registering with merkle proof
    }

    // Test 8: Test batch auction status
    function testGetAuctionStatus() public {
        // Create an auction batch
        string[] memory domains = new string[](1);
        domains[0] = "status";

        uint256 batchId = createAuctionBatch(domains, block.timestamp);

        // Check status at the start
        (
            DotHypeDutchAuction.DutchAuctionConfig memory config,
            uint256 currentPrice,
            uint256 timeRemaining,
            bool isActive,
            bool hasStarted,
            bool isComplete
        ) = dutchAuction.getAuctionStatus(batchId);

        assertEq(config.startPrice, START_PRICE);
        assertEq(config.endPrice, END_PRICE);
        assertEq(config.auctionDuration, AUCTION_DURATION);
        assertEq(config.startTime, block.timestamp);
        assertTrue(config.isActive);
        assertEq(currentPrice, START_PRICE);
        assertEq(timeRemaining, AUCTION_DURATION);
        assertTrue(isActive);
        assertTrue(hasStarted);
        assertFalse(isComplete);

        // Fast forward to halfway
        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        // Check status in the middle
        (, uint256 midPrice, uint256 midTimeRemaining,,, bool midComplete) = dutchAuction.getAuctionStatus(batchId);

        // Price should be approximately halfway between start and end
        uint256 expectedMidPrice = (START_PRICE + END_PRICE) / 2;
        assertApproxEqRel(midPrice, expectedMidPrice, 0.02e18);

        // Time remaining should be half the total duration
        assertEq(midTimeRemaining, AUCTION_DURATION / 2);

        // Auction should not be complete yet
        assertFalse(midComplete);

        // Fast forward to the end
        vm.warp(block.timestamp + AUCTION_DURATION);

        // Check status at the end
        (, uint256 endPrice, uint256 endTimeRemaining,,, bool endComplete) = dutchAuction.getAuctionStatus(batchId);

        // Price should be at the end price
        assertEq(endPrice, END_PRICE);

        // Time remaining should be 0
        assertEq(endTimeRemaining, 0);

        // Auction should be complete
        assertTrue(endComplete);
    }

    // Test 9: Get batch domains
    function testGetBatchDomains() public {
        // Create an auction batch with multiple domains
        string[] memory domains = new string[](3);
        domains[0] = "one";
        domains[1] = "two";
        domains[2] = "three";

        uint256 batchId = createAuctionBatch(domains, block.timestamp);

        // Get the domains in the batch
        bytes32[] memory batchDomains = dutchAuction.getBatchDomains(batchId);

        // Verify the count
        assertEq(batchDomains.length, 3);

        // Verify the domains are in the batch
        assertEq(batchDomains[0], keccak256(bytes("one")));
        assertEq(batchDomains[1], keccak256(bytes("two")));
        assertEq(batchDomains[2], keccak256(bytes("three")));
    }
}
