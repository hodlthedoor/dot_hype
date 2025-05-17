// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "./mocks/MockPriceOracle.sol";

contract DotHypeControllerTest is Test {
    using stdStorage for StdStorage;

    DotHypeRegistry public registry;
    DotHypeController public controller;
    MockPriceOracle public priceOracle;

    address public owner = address(0x1);
    uint256 public signerPrivateKey = 0xA11CE; // Fixed type to uint256
    address public signer;
    address public user = address(0x3);

    // EIP-712 domain separator data
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant REGISTRATION_TYPEHASH = keccak256(
        "Registration(string name,address owner,uint256 duration,uint256 maxPrice,uint256 deadline,uint256 nonce)"
    );

    // Mock price parameters
    uint64 constant INITIAL_PRICE = 2000000; // $2.00 (scaled by 1e6)
    uint256 constant SCALE = 1e6;

    // Helper function to convert USD to HYPE
    function convertUsdToHype(uint256 usdAmount) internal pure returns (uint256) {
        return (usdAmount * SCALE) / INITIAL_PRICE;
    }

    // Setup before each test
    function setUp() public {
        // Get signer address from private key
        signer = vm.addr(signerPrivateKey); // signerPrivateKey is already uint256

        // Deploy mock price oracle
        priceOracle = new MockPriceOracle(INITIAL_PRICE);

        // Deploy registry and controller
        registry = new DotHypeRegistry(owner, address(this));
        controller = new DotHypeController(address(registry), signer, address(priceOracle), owner);

        // Set controller in registry
        vm.prank(owner);
        registry.setController(address(controller));

        // Set annual prices for different character counts
        uint256[5] memory prices = [
            uint256(0), // 1 character: unavailable
            uint256(0), // 2 characters: unavailable
            uint256(100 ether), // 3 characters: $100 per year
            uint256(10 ether), // 4 characters: $10 per year
            uint256(1 ether) // 5+ characters: $1 per year
        ];

        vm.prank(owner);
        controller.setAllAnnualPrices(prices);

        // Set annual renewal prices (lower than registration prices)
        uint256[5] memory renewalPrices = [
            uint256(0), // 1 character: unavailable
            uint256(0), // 2 characters: unavailable
            uint256(80 ether), // 3 characters: $80 per year (20% discount)
            uint256(8 ether), // 4 characters: $8 per year (20% discount)
            uint256(0.8 ether) // 5+ characters: $0.8 per year (20% discount)
        ];

        vm.prank(owner);
        controller.setAllAnnualRenewalPrices(renewalPrices);

        // Ensure payment recipient is set to owner
        vm.prank(owner);
        controller.setPaymentRecipient(owner);
    }

    // Helper function to compute the EIP-712 domain separator
    function computeDomainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("DotHypeController"),
                keccak256("1"),
                block.chainid,
                address(controller)
            )
        );
    }

    // Helper function to get the registration digest
    function getRegistrationDigest(
        string memory name,
        address owner,
        uint256 duration,
        uint256 maxPrice,
        uint256 deadline,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(REGISTRATION_TYPEHASH, keccak256(bytes(name)), owner, duration, maxPrice, deadline, nonce)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", computeDomainSeparator(), structHash));

        return digest;
    }

    // Helper function to register a domain through the controller
    function _registerDomain(string memory name, address registrant, uint256 duration)
        internal
        returns (uint256 tokenId, uint256 expiry)
    {
        uint256 maxPrice = 1000 ether; // Much more than needed to ensure test passes
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, duration);

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        // Sign message
        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Register domain
        vm.deal(registrant, expectedPrice);
        vm.prank(registrant);
        return controller.registerWithSignature{value: expectedPrice}(
            name, registrant, duration, maxPrice, deadline, signature
        );
    }

    // Test registration with signature
    function testRegisterWithSignature() public {
        // Prepare registration parameters
        string memory name = "test"; // 4 characters, $10 per year
        address registrant = user;
        uint256 duration = 365 days;
        uint256 maxPrice = 1000 ether; // Much more than needed to ensure test passes
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, duration);

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        // need this to fix stack too deep error
        bytes memory signature;

        {
            // Sign message
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Register domain
        vm.deal(user, expectedPrice);
        vm.prank(user);
        (uint256 tokenId, uint256 expiry) = controller.registerWithSignature{value: expectedPrice}(
            name, registrant, duration, maxPrice, deadline, signature
        );

        // Verify registration
        assertEq(registry.ownerOf(tokenId), registrant);
        assertEq(expiry, block.timestamp + duration);
        assertEq(registry.expiryOf(tokenId), block.timestamp + duration);
    }

    // Test renewal (anyone can renew)
    function testRenewal() public {
        // First register a domain using controller
        string memory name = "renew"; // 5 characters, $1 per year
        address registrant = user;
        uint256 duration = 365 days;

        // Register through controller
        (uint256 tokenId, uint256 initialExpiry) = _registerDomain(name, registrant, duration);

        // Prepare renewal parameters
        uint256 renewalDuration = 365 days;

        // Calculate expected price using renewal price
        uint256 expectedPrice = controller.calculateRenewalPrice(name, renewalDuration);

        // Renew domain as a different address
        address renewer = address(0x4);
        vm.deal(renewer, expectedPrice);
        vm.prank(renewer);
        uint256 newExpiry = controller.renew{value: expectedPrice}(tokenId, renewalDuration);

        // Verify renewal
        assertEq(registry.ownerOf(tokenId), registrant); // Owner should not change
        assertEq(newExpiry, initialExpiry + renewalDuration);
        assertEq(registry.expiryOf(tokenId), initialExpiry + renewalDuration);
    }

    // Test empty string or zero-length domain name
    function testEmptyName() public {
        string memory emptyName = "";
        uint256 duration = 365 days;

        // This should revert with InvalidCharacterCount(0)
        vm.expectRevert();
        controller.calculatePrice(emptyName, duration);
    }

    // Test premium pricing for short domains
    function testPremiumPricing() public {
        // Test 3-character domain
        string memory threeChar = "abc";
        uint256 threeCharPrice = controller.calculatePrice(threeChar, 365 days);
        console.log("threeCharPrice", threeCharPrice);
        assertEq(threeCharPrice, convertUsdToHype(100 ether)); // $100 = 50 HYPE

        // Test 1 and 2 character domains - should revert with PricingNotSet
        string memory oneChar = "a";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(oneChar, 365 days);

        string memory twoChar = "ab";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(twoChar, 365 days);
    }

    // Test minimum registration length
    function testMinimumRegistrationLength() public {
        // Test that MIN_REGISTRATION_LENGTH is set correctly
        assertEq(controller.MIN_REGISTRATION_LENGTH(), 365 days);

        // Test registration with duration less than minimum
        string memory name = "test";
        address registrant = user;
        uint256 duration = 364 days; // Just under minimum
        uint256 maxPrice = 1000 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Should revert with DurationTooShort
        vm.deal(registrant, maxPrice);
        vm.prank(registrant);
        vm.expectRevert(abi.encodeWithSelector(DotHypeController.DurationTooShort.selector, duration, 365 days));
        controller.registerWithSignature{value: maxPrice}(name, registrant, duration, maxPrice, deadline, signature);

        // Test registration with duration equal to minimum (should succeed)
        duration = 365 days;
        nonce = controller.getNextNonce(registrant);
        digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        vm.deal(registrant, maxPrice);
        vm.prank(registrant);
        (uint256 tokenId, uint256 expiry) =
            controller.registerWithSignature{value: maxPrice}(name, registrant, duration, maxPrice, deadline, signature);

        // Verify registration succeeded
        assertEq(registry.ownerOf(tokenId), registrant);
        assertEq(expiry, block.timestamp + duration);
    }

    // Test that renewal allows any duration
    function testRenewalAnyDuration() public {
        // First register a domain
        string memory name = "test";
        address registrant = user;
        uint256 duration = 365 days;
        (uint256 tokenId, uint256 initialExpiry) = _registerDomain(name, registrant, duration);

        // Test renewal with duration less than minimum (should succeed)
        uint256 shortDuration = 30 days;
        uint256 expectedPrice = controller.calculateRenewalPrice(name, shortDuration);

        address renewer = address(0x4);
        vm.deal(renewer, expectedPrice);
        vm.prank(renewer);
        uint256 newExpiry = controller.renew{value: expectedPrice}(tokenId, shortDuration);

        // Verify renewal succeeded
        assertEq(registry.ownerOf(tokenId), registrant);
        assertEq(newExpiry, initialExpiry + shortDuration);
        assertEq(registry.expiryOf(tokenId), initialExpiry + shortDuration);
    }

    // Test attempting to register 1-2 character domains
    function testRegisterShortDomainsFails() public {
        // Parameters for registration attempt
        address registrant = user;
        uint256 duration = 365 days;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 maxPrice = 1000 ether; // Not enough for 1-2 char domains

        // Try to register 1-character domain
        string memory oneChar = "a";
        uint256 nonce = controller.getNextNonce(registrant);

        bytes32 digest = getRegistrationDigest(oneChar, registrant, duration, maxPrice, deadline, nonce);

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Should revert with PricingNotSet for 1 character domains
        vm.deal(registrant, maxPrice);
        vm.prank(registrant);
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.registerWithSignature{value: maxPrice}(oneChar, registrant, duration, maxPrice, deadline, signature);

        // Try to register 2-character domain
        string memory twoChar = "ab";
        nonce = controller.getNextNonce(registrant);

        digest = getRegistrationDigest(twoChar, registrant, duration, maxPrice, deadline, nonce);

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Should revert with PricingNotSet for 2 character domains
        vm.prank(registrant);
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.registerWithSignature{value: maxPrice}(twoChar, registrant, duration, maxPrice, deadline, signature);
    }

    // Test refunding of excess payment
    function testExcessPaymentRefund() public {
        // Prepare registration parameters
        string memory name = "excess"; // 6 characters, 1 ETH per year
        address registrant = user;
        uint256 duration = 365 days;
        uint256 maxPrice = 1000 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, duration);
        uint256 excessPayment = 3 ether; // Add 3 ETH extra
        uint256 totalPayment = expectedPrice + excessPayment;

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Track user balance before
        vm.deal(registrant, totalPayment);
        uint256 balanceBefore = registrant.balance;

        // Register domain with excess payment
        vm.prank(registrant);
        controller.registerWithSignature{value: totalPayment}(name, registrant, duration, maxPrice, deadline, signature);

        // Verify excess was refunded
        uint256 balanceAfter = registrant.balance;
        uint256 actualCost = balanceBefore - balanceAfter;

        // We should have spent the expected price, not the total payment
        // The expected price includes the 10% fee, which goes to the owner, not back to the user
        assertEq(actualCost, expectedPrice);

        // Alternatively, check explicit refund amount
        assertEq(balanceAfter, excessPayment);
    }

    // Test insufficient payment for renewal
    function testInsufficientPaymentRenewal() public {
        // First register a domain using controller
        string memory name = "payment"; // 7 characters, 1 ETH per year (falls into 5+ bucket)
        address registrant = user;
        uint256 duration = 365 days;

        // Register through controller
        (uint256 tokenId, uint256 initialExpiry) = _registerDomain(name, registrant, duration);

        // Prepare renewal parameters
        uint256 renewalDuration = 365 days;

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, renewalDuration);

        // Try to renew with insufficient payment
        address renewer = address(0x4);
        vm.deal(renewer, expectedPrice / 2); // Only half the required payment
        vm.prank(renewer);
        vm.expectRevert();
        controller.renew{value: expectedPrice / 2}(tokenId, renewalDuration);
    }

    // Test nonce replay protection
    function testNonceReplayProtection() public {
        // Prepare registration parameters
        string memory name = "replay";
        address registrant = user;
        uint256 duration = 365 days;
        uint256 maxPrice = 1000 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, duration);

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        uint256 ownerBalanceBefore;
        bytes memory signature;

        {
            // Sign message
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Register domain
        vm.deal(user, expectedPrice * 2); // Double the ether for two attempts
        vm.prank(user);
        controller.registerWithSignature{value: expectedPrice}(
            name, registrant, duration, maxPrice, deadline, signature
        );

        // Try to register another domain with same signature
        // This should fail because nonce is now incremented
        vm.expectRevert();
        vm.prank(user);
        controller.registerWithSignature{value: expectedPrice}(
            name, registrant, duration, maxPrice, deadline, signature
        );
    }

    // Test price calculation for different character counts
    function testPriceCalculation() public {
        uint256 duration = 365 days;

        // 3 characters: $100 per year = 50 HYPE
        string memory threeChar = "abc";
        uint256 threeCharPrice = controller.calculatePrice(threeChar, duration);
        assertEq(threeCharPrice, convertUsdToHype(100 ether)); // $100 = 50 HYPE

        // 4 characters: $10 per year = 5 HYPE
        string memory fourChar = "abcd";
        uint256 fourCharPrice = controller.calculatePrice(fourChar, duration);
        assertEq(fourCharPrice, convertUsdToHype(10 ether)); // $10 = 5 HYPE

        // 5 characters: $1 per year = 0.5 HYPE
        string memory fiveChar = "abcde";
        uint256 fiveCharPrice = controller.calculatePrice(fiveChar, duration);
        assertEq(fiveCharPrice, convertUsdToHype(1 ether)); // $1 = 0.5 HYPE

        // 6 characters: also $1 per year = 0.5 HYPE (same bucket as 5)
        string memory sixChar = "abcdef";
        uint256 sixCharPrice = controller.calculatePrice(sixChar, duration);
        assertEq(sixCharPrice, convertUsdToHype(1 ether)); // $1 = 0.5 HYPE

        // Verify 5 and 6 have the same price (in the same bucket)
        assertEq(fiveCharPrice, sixCharPrice);

        // 10 characters: still $1 per year = 0.5 HYPE (5+ bucket)
        string memory tenChar = "abcdefghij";
        uint256 tenCharPrice = controller.calculatePrice(tenChar, duration);
        assertEq(tenCharPrice, convertUsdToHype(1 ether)); // $1 = 0.5 HYPE

        // Verify 5, 6, and 10 all have the same price
        assertEq(fiveCharPrice, tenCharPrice);
    }

    // Test partial-year duration pricing
    function testPartialYearPricing() public {
        string memory name = "test"; // 4 characters, $10 per year

        // 6 months should cost half the annual price
        uint256 sixMonthPrice = controller.calculatePrice(name, 182.5 days);
        assertEq(sixMonthPrice, convertUsdToHype(5 ether)); // Half of registration price

        // 3 months should cost quarter the annual price
        uint256 threeMonthPrice = controller.calculatePrice(name, 91.25 days);
        assertEq(threeMonthPrice, convertUsdToHype(2.5 ether)); // Quarter of registration price

        // 2 years should cost double the annual price
        uint256 twoYearPrice = controller.calculatePrice(name, 730 days);
        assertEq(twoYearPrice, convertUsdToHype(18 ether)); // First year registration + second year renewal
    }

    // Test payment distribution to recipient
    function testPaymentDistribution() public {
        // Prepare registration parameters
        string memory name = "fees"; // 4 characters, 10 ETH per year
        address registrant = user;
        uint256 duration = 365 days;
        uint256 maxPrice = 1000 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, duration);

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        uint256 ownerBalanceBefore;
        bytes memory signature;

        {
            // Sign message
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Track owner balance
        ownerBalanceBefore = owner.balance;

        // Register domain
        vm.deal(user, expectedPrice);
        vm.prank(user);
        controller.registerWithSignature{value: expectedPrice}(
            name, registrant, duration, maxPrice, deadline, signature
        );

        // Verify payment was sent to owner
        uint256 ownerBalanceAfter = owner.balance;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedPrice);
    }

    // Test setting individual price
    function testSetIndividualPrice() public {
        // Update price for 3-character domains
        uint256 newUsdPrice = 200 ether; // $200 = 100 HYPE
        vm.prank(owner);
        controller.setAnnualPrice(3, newUsdPrice);

        // Verify the new price
        string memory threeChar = "abc";
        uint256 updatedPrice = controller.calculatePrice(threeChar, 365 days);
        assertEq(updatedPrice, convertUsdToHype(200 ether)); // $200 = 100 HYPE

        // Verify registration price is unchanged
        uint256 registrationPrice = controller.calculatePrice(threeChar, 365 days);
        assertEq(registrationPrice, convertUsdToHype(200 ether)); // $200 = 100 HYPE
    }

    // Test updating all prices at once
    function testSetAllPrices() public {
        // New prices in USD
        uint256[5] memory newPrices = [
            uint256(0), // 1 char (unavailable)
            uint256(0), // 2 char (unavailable)
            uint256(50 ether), // 3 char ($50 = 25 HYPE)
            uint256(5 ether), // 4 char ($5 = 2.5 HYPE)
            uint256(0.5 ether) // 5+ char ($0.5 = 0.25 HYPE)
        ];

        vm.prank(owner);
        controller.setAllAnnualPrices(newPrices);

        // Verify new prices
        // 1 and 2-character domains should be unavailable
        string memory oneChar = "a";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(oneChar, 365 days);

        string memory twoChar = "ab";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(twoChar, 365 days);

        string memory threeChar = "abc";
        uint256 threeCharPrice = controller.calculatePrice(threeChar, 365 days);
        assertEq(threeCharPrice, convertUsdToHype(50 ether)); // $50 = 25 HYPE

        string memory longName = "longname";
        uint256 longNamePrice = controller.calculatePrice(longName, 365 days);
        assertEq(longNamePrice, convertUsdToHype(0.5 ether)); // $0.5 = 0.25 HYPE
    }

    // Test registering domains before and after price update
    function testPriceUpdateAndMint() public {
        // Initial domain registration with original price
        string memory firstDomain = "firstdomain"; // 11 characters, $1 per year (5+ bucket)
        address registrant = user;
        uint256 duration = 365 days;

        // Get original price and register first domain
        uint256 originalPrice = controller.calculatePrice(firstDomain, duration);
        assertEq(originalPrice, convertUsdToHype(1 ether)); // Verify original price

        (uint256 firstTokenId, uint256 firstExpiry) = _registerDomain(firstDomain, registrant, duration);

        // Verify first domain registration
        assertEq(registry.ownerOf(firstTokenId), registrant);
        assertEq(registry.expiryOf(firstTokenId), firstExpiry);

        // Update pricing for 5+ character domains (bucket 5)
        uint256 newUsdPrice = 3 ether; // Increase price to $3 per year
        vm.prank(owner);
        controller.setAnnualPrice(5, newUsdPrice);

        // Verify price update was applied
        uint256 updatedPrice = controller.calculatePrice(firstDomain, duration);
        assertEq(updatedPrice, convertUsdToHype(newUsdPrice));

        // Register a second domain with new price
        string memory secondDomain = "seconddomain"; // Also 5+ characters

        // Calculate price for second domain (should use new price)
        uint256 secondDomainPrice = controller.calculatePrice(secondDomain, duration);
        assertEq(secondDomainPrice, convertUsdToHype(newUsdPrice)); // Should match new price

        // Register second domain
        (uint256 secondTokenId, uint256 secondExpiry) = _registerDomain(secondDomain, registrant, duration);

        // Verify second domain registration
        assertEq(registry.ownerOf(secondTokenId), registrant);
        assertEq(registry.expiryOf(secondTokenId), secondExpiry);

        // Verify that renewing the first domain also uses the new price
        uint256 renewalPrice = controller.calculatePrice(firstDomain, duration);
        assertEq(renewalPrice, convertUsdToHype(newUsdPrice)); // Should match new price

        vm.deal(registrant, renewalPrice);
        vm.prank(registrant);
        uint256 newExpiry = controller.renew{value: renewalPrice}(firstTokenId, duration);

        // Verify renewal worked at new price
        assertEq(newExpiry, firstExpiry + duration);
        assertEq(registry.expiryOf(firstTokenId), firstExpiry + duration);
    }

    // Test USD to HYPE price conversion
    function testPriceConversion() public {
        // Part 1: Register first domain with initial price
        {
            string memory name = "usdpriced"; // 9 characters, $1 per year (5+ bucket)
            uint256 duration = 365 days;
            uint256 maxPrice = 1000 ether; // Much higher than needed

            // Calculate expected price (HYPE price is $2.00, so 1 USD = 0.5 HYPE)
            uint256 usdPrice = 1 ether; // $1 in 18 decimals
            uint256 expectedHypePrice = (usdPrice * SCALE) / INITIAL_PRICE; // Around 0.5 HYPE

            // Verify the calculation matches controller's calculation
            assertEq(controller.calculatePrice(name, duration), expectedHypePrice);

            // Register domain with calculated price
            _registerDomainWithPrice(name, user, duration, maxPrice, expectedHypePrice);
        }

        // Part 2: Change HYPE price and register another domain
        {
            // Change HYPE price to $4.00
            uint64 newPrice = 4000000; // $4.00 (scaled by 1e6)
            priceOracle.setRawPrice(newPrice);

            string memory name = "priceupdated"; // Also in the 5+ bucket ($1 per year)
            uint256 duration = 365 days;
            uint256 maxPrice = 1000 ether;

            // New expected price in HYPE should be less since HYPE is worth more
            uint256 usdPrice = 1 ether; // $1 in 18 decimals
            uint256 expectedHypePrice = (usdPrice * SCALE) / newPrice; // Around 0.25 HYPE

            // Verify the calculation matches controller's calculation
            assertEq(controller.calculatePrice(name, duration), expectedHypePrice);

            // Register second domain
            _registerDomainWithPrice(name, user, duration, maxPrice, expectedHypePrice);
        }
    }

    // Helper function to register a domain with a specific price
    function _registerDomainWithPrice(
        string memory name,
        address registrant,
        uint256 duration,
        uint256 maxPrice,
        uint256 paymentAmount
    ) internal returns (uint256 tokenId) {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(registrant);

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, registrant, duration, maxPrice, deadline, nonce);

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Register domain with calculated price
        vm.deal(registrant, paymentAmount);
        vm.prank(registrant);
        (tokenId,) = controller.registerWithSignature{value: paymentAmount}(
            name, registrant, duration, maxPrice, deadline, signature
        );

        // Verify registration was successful
        assertEq(registry.ownerOf(tokenId), registrant);

        return tokenId;
    }

    // Test renewal pricing
    function testRenewalPricing() public {
        // First register a domain
        string memory name = "test"; // 4 characters
        address registrant = user;
        uint256 duration = 365 days;
        (uint256 tokenId, uint256 initialExpiry) = _registerDomain(name, registrant, duration);

        // Calculate registration price (should be $10 per year = 5 HYPE)
        uint256 registrationPrice = controller.calculatePrice(name, duration);
        assertEq(registrationPrice, convertUsdToHype(10 ether)); // $10 = 5 HYPE

        // Calculate renewal price (should be $8 per year = 4 HYPE)
        uint256 renewalPrice = controller.calculateRenewalPrice(name, duration);
        assertEq(renewalPrice, convertUsdToHype(8 ether)); // $8 = 4 HYPE

        // Verify renewal uses the renewal price
        address renewer = address(0x4);
        vm.deal(renewer, renewalPrice);
        vm.prank(renewer);
        uint256 newExpiry = controller.renew{value: renewalPrice}(tokenId, duration);

        // Verify renewal succeeded
        assertEq(registry.ownerOf(tokenId), registrant);
        assertEq(newExpiry, initialExpiry + duration);
        assertEq(registry.expiryOf(tokenId), initialExpiry + duration);
    }

    // Test setting individual renewal price
    function testSetIndividualRenewalPrice() public {
        // Update renewal price for 3-character domains
        uint256 newUsdPrice = 150 ether; // $150 = 75 HYPE
        vm.prank(owner);
        controller.setAnnualRenewalPrice(3, newUsdPrice);

        // Verify the new renewal price
        string memory threeChar = "abc";
        uint256 updatedPrice = controller.calculateRenewalPrice(threeChar, 365 days);
        assertEq(updatedPrice, convertUsdToHype(150 ether)); // $150 = 75 HYPE

        // Verify registration price is unchanged
        uint256 registrationPrice = controller.calculatePrice(threeChar, 365 days);
        assertEq(registrationPrice, convertUsdToHype(100 ether)); // $100 = 50 HYPE
    }

    // Test updating all renewal prices at once
    function testSetAllRenewalPrices() public {
        // New renewal prices in USD
        uint256[5] memory newPrices = [
            uint256(0), // 1 char (unavailable)
            uint256(0), // 2 char (unavailable)
            uint256(40 ether), // 3 char ($40 = 20 HYPE)
            uint256(4 ether), // 4 char ($4 = 2 HYPE)
            uint256(0.4 ether) // 5+ char ($0.4 = 0.2 HYPE)
        ];

        vm.prank(owner);
        controller.setAllAnnualRenewalPrices(newPrices);

        // Verify new renewal prices
        // 1 and 2-character domains should be unavailable
        string memory oneChar = "a";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculateRenewalPrice(oneChar, 365 days);

        string memory twoChar = "ab";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculateRenewalPrice(twoChar, 365 days);

        string memory threeChar = "abc";
        uint256 threeCharPrice = controller.calculateRenewalPrice(threeChar, 365 days);
        assertEq(threeCharPrice, convertUsdToHype(40 ether)); // $40 = 20 HYPE

        string memory longName = "longname";
        uint256 longNamePrice = controller.calculateRenewalPrice(longName, 365 days);
        assertEq(longNamePrice, convertUsdToHype(0.4 ether)); // $0.4 = 0.2 HYPE

        // Verify registration prices are unchanged
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(oneChar, 365 days);
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(twoChar, 365 days);
        assertEq(controller.calculatePrice(threeChar, 365 days), convertUsdToHype(100 ether)); // $100 = 50 HYPE
        assertEq(controller.calculatePrice(longName, 365 days), convertUsdToHype(1 ether)); // $1 = 0.5 HYPE
    }

    // Test split pricing for registration (first year registration price, additional years renewal price)
    function testSplitPricing() public {
        string memory name = "test"; // 4 characters
        // Registration price: $10 per year = 5 HYPE
        // Renewal price: $8 per year = 4 HYPE

        // Test 1 year registration
        uint256 oneYearPrice = controller.calculatePrice(name, 365 days);
        assertEq(oneYearPrice, convertUsdToHype(10 ether)); // $10 = 5 HYPE

        // Test 2 year registration
        uint256 twoYearPrice = controller.calculatePrice(name, 730 days);
        // First year: $10 = 5 HYPE (registration price)
        // Second year: $8 = 4 HYPE (renewal price)
        assertEq(twoYearPrice, convertUsdToHype(18 ether)); // $18 = 9 HYPE

        // Test 1.5 year registration
        uint256 oneAndHalfYearPrice = controller.calculatePrice(name, 547.5 days);
        // First year: $10 = 5 HYPE (registration price)
        // Additional 0.5 year: $4 = 2 HYPE (half of renewal price)
        assertEq(oneAndHalfYearPrice, convertUsdToHype(14 ether)); // $14 = 7 HYPE

        // Test 3 year registration
        uint256 threeYearPrice = controller.calculatePrice(name, 1095 days);
        // First year: $10 = 5 HYPE (registration price)
        // Additional 2 years: $16 = 8 HYPE (2 * renewal price)
        assertEq(threeYearPrice, convertUsdToHype(26 ether)); // $26 = 13 HYPE

        // Test 6 month registration
        uint256 sixMonthPrice = controller.calculatePrice(name, 182.5 days);
        // Less than a year, should use registration price proportionally
        assertEq(sixMonthPrice, convertUsdToHype(5 ether)); // $5 = 2.5 HYPE (half of registration price)
    }

    // Test split pricing with different character lengths
    function testSplitPricingDifferentLengths() public {
        // Test 3-character domain
        string memory threeChar = "abc";
        // Registration price: $100 per year
        // Renewal price: $80 per year

        uint256 threeCharTwoYearPrice = controller.calculatePrice(threeChar, 730 days);
        // First year: $100 (registration price)
        // Second year: $80 (renewal price)
        assertEq(threeCharTwoYearPrice, convertUsdToHype(180 ether));

        // Test 5+ character domain
        string memory longName = "longname";
        // Registration price: $1 per year
        // Renewal price: $0.8 per year

        uint256 longNameTwoYearPrice = controller.calculatePrice(longName, 730 days);
        // First year: $1 (registration price)
        // Second year: $0.8 (renewal price)
        assertEq(longNameTwoYearPrice, convertUsdToHype(1.8 ether));
    }

    // Test split pricing with unavailable domains
    function testSplitPricingUnavailableDomains() public {
        // Test 1-character domain (unavailable)
        string memory oneChar = "a";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(oneChar, 730 days);

        // Test 2-character domain (unavailable)
        string memory twoChar = "ab";
        vm.expectRevert(DotHypeController.PricingNotSet.selector);
        controller.calculatePrice(twoChar, 730 days);
    }
}
