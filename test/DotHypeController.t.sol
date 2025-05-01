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
            type(uint256).max, // 1 character: extremely high price (effectively unavailable)
            type(uint256).max, // 2 characters: extremely high price (effectively unavailable)
            100 ether, // 3 characters: $100 per year
            10 ether, // 4 characters: $10 per year
            1 ether // 5+ characters: $1 per year
        ];

        vm.prank(owner);
        controller.setAllAnnualPrices(prices);

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

        // Calculate expected price
        uint256 expectedPrice = controller.calculatePrice(name, renewalDuration);

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
        assertEq(threeCharPrice, convertUsdToHype(100 ether));

        // Test 1 and 2 character domains - we need to manually compute to avoid overflow
        // We're not testing exact values, just verifying they're effectively unavailable

        // Verify 1-character domains have the max price configured
        vm.prank(owner);
        controller.setAnnualPrice(1, type(uint256).max);
        assertTrue(controller.annualPrices(1) == type(uint256).max);

        // Verify 2-character domains have the max price configured
        vm.prank(owner);
        controller.setAnnualPrice(2, type(uint256).max);
        assertTrue(controller.annualPrices(2) == type(uint256).max);
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

        // Should revert with CharacterLengthNotAvailable for 1 character domains
        vm.deal(registrant, maxPrice);
        vm.prank(registrant);
        vm.expectRevert(
            abi.encodeWithSelector(
                DotHypeController.CharacterLengthNotAvailable.selector,
                1 // 1 character
            )
        );
        controller.registerWithSignature{value: maxPrice}(oneChar, registrant, duration, maxPrice, deadline, signature);

        // Try to register 2-character domain
        string memory twoChar = "ab";
        nonce = controller.getNextNonce(registrant);

        digest = getRegistrationDigest(twoChar, registrant, duration, maxPrice, deadline, nonce);

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Should revert with CharacterLengthNotAvailable for 2 character domains
        vm.prank(registrant);
        vm.expectRevert(
            abi.encodeWithSelector(
                DotHypeController.CharacterLengthNotAvailable.selector,
                2 // 2 characters
            )
        );
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

        // 3 characters: $100 per year
        string memory threeChar = "abc";
        uint256 threeCharPrice = controller.calculatePrice(threeChar, duration);
        assertEq(threeCharPrice, convertUsdToHype(100 ether));

        // 4 characters: $10 per year
        string memory fourChar = "abcd";
        uint256 fourCharPrice = controller.calculatePrice(fourChar, duration);
        assertEq(fourCharPrice, convertUsdToHype(10 ether));

        // 5 characters: $1 per year
        string memory fiveChar = "abcde";
        uint256 fiveCharPrice = controller.calculatePrice(fiveChar, duration);
        assertEq(fiveCharPrice, convertUsdToHype(1 ether));

        // 6 characters: also $1 per year (same bucket as 5)
        string memory sixChar = "abcdef";
        uint256 sixCharPrice = controller.calculatePrice(sixChar, duration);
        assertEq(sixCharPrice, convertUsdToHype(1 ether));

        // Verify 5 and 6 have the same price (in the same bucket)
        assertEq(fiveCharPrice, sixCharPrice);

        // 10 characters: still $1 per year (5+ bucket)
        string memory tenChar = "abcdefghij";
        uint256 tenCharPrice = controller.calculatePrice(tenChar, duration);
        assertEq(tenCharPrice, convertUsdToHype(1 ether));

        // Verify 5, 6, and 10 all have the same price
        assertEq(fiveCharPrice, tenCharPrice);
    }

    // Test partial-year duration pricing
    function testPartialYearPricing() public {
        string memory name = "test"; // 4 characters, $10 per year

        // 6 months should cost half the annual price
        uint256 sixMonthPrice = controller.calculatePrice(name, 182.5 days);
        assertEq(sixMonthPrice, convertUsdToHype(5 ether));

        // 3 months should cost quarter the annual price
        uint256 threeMonthPrice = controller.calculatePrice(name, 91.25 days);
        assertEq(threeMonthPrice, convertUsdToHype(2.5 ether));

        // 2 years should cost double the annual price
        uint256 twoYearPrice = controller.calculatePrice(name, 730 days);
        assertEq(twoYearPrice, convertUsdToHype(20 ether));
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
        uint256 newUsdPrice = 200 ether; // $200
        vm.prank(owner);
        controller.setAnnualPrice(3, newUsdPrice);

        // Verify the new price
        string memory threeChar = "abc";
        uint256 updatedPrice = controller.calculatePrice(threeChar, 365 days);
        assertEq(updatedPrice, convertUsdToHype(newUsdPrice));
    }

    // Test updating all prices at once
    function testSetAllPrices() public {
        // New prices in USD
        uint256[5] memory newPrices = [
            type(uint256).max, // 1 char (still unavailable)
            1000 ether, // 2 char (now available at high price)
            50 ether, // 3 char
            5 ether, // 4 char
            0.5 ether // 5+ char
        ];

        vm.prank(owner);
        controller.setAllAnnualPrices(newPrices);

        // Verify new prices
        string memory twoChar = "ab";
        uint256 twoCharPrice = controller.calculatePrice(twoChar, 365 days);
        assertEq(twoCharPrice, convertUsdToHype(1000 ether));

        string memory threeChar = "abc";
        uint256 threeCharPrice = controller.calculatePrice(threeChar, 365 days);
        assertEq(threeCharPrice, convertUsdToHype(50 ether));

        string memory longName = "longname";
        uint256 longNamePrice = controller.calculatePrice(longName, 365 days);
        assertEq(longNamePrice, convertUsdToHype(0.5 ether));
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
}
