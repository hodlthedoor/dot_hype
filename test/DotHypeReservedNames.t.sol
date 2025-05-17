// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "./mocks/MockPriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DotHypeReservedNamesTest is Test {
    using stdStorage for StdStorage;

    DotHypeRegistry public registry;
    DotHypeController public controller;
    MockPriceOracle public priceOracle;

    address public owner = address(0x1);
    uint256 public signerPrivateKey = 0xA11CE;
    address public signer;
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public reservedUser = address(0x5);

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
        signer = vm.addr(signerPrivateKey);

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

        // Set annual renewal prices (lower than registration prices)
        uint256[5] memory renewalPrices = [
            type(uint256).max, // 1 character: extremely high price (effectively unavailable)
            type(uint256).max, // 2 characters: extremely high price (effectively unavailable)
            80 ether, // 3 characters: $80 per year (20% discount)
            8 ether, // 4 characters: $8 per year (20% discount)
            0.8 ether // 5+ characters: $0.8 per year (20% discount)
        ];

        vm.prank(owner);
        controller.setAllAnnualRenewalPrices(renewalPrices);

        // Ensure payment recipient is set to owner
        vm.prank(owner);
        controller.setPaymentRecipient(owner);

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(reservedUser, 10 ether);
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
        bytes32 REGISTRATION_TYPEHASH = keccak256(
            "Registration(string name,address owner,uint256 duration,uint256 maxPrice,uint256 deadline,uint256 nonce)"
        );

        bytes32 structHash = keccak256(
            abi.encode(REGISTRATION_TYPEHASH, keccak256(bytes(name)), owner, duration, maxPrice, deadline, nonce)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", computeDomainSeparator(), structHash));

        return digest;
    }

    // Helper function to register a domain with signature
    function _registerWithSignature(string memory name, address registrant, uint256 duration, uint256 maxPrice)
        internal
        returns (uint256 tokenId, uint256 expiry)
    {
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

    // Test setting a name reservation
    function testSetReservation() public {
        string memory name = "premium";

        // Set reservation for reservedUser
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Check reservation status
        (bool isReserved, address reservedFor) = controller.checkReservation(name);

        // Verify reservation was set correctly
        assertTrue(isReserved);
        assertEq(reservedFor, reservedUser);
    }

    // Test removing a name reservation
    function testRemoveReservation() public {
        string memory name = "premium";

        // Set reservation
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Remove reservation by setting to address(0)
        vm.prank(owner);
        controller.setReservation(name, address(0));

        // Check reservation status
        (bool isReserved, address reservedFor) = controller.checkReservation(name);

        // Verify reservation was removed
        assertFalse(isReserved);
        assertEq(reservedFor, address(0));
    }

    // Test registering a reserved name by the authorized address
    function testRegisterReservedName() public {
        string memory name = "premium";
        uint256 duration = 365 days;

        // Set reservation for reservedUser
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Calculate price
        uint256 price = controller.calculatePrice(name, duration);

        // Register the reserved name from reserved user
        vm.deal(reservedUser, price);
        vm.prank(reservedUser);
        (uint256 tokenId, uint256 expiry) = controller.registerReserved{value: price}(name, duration);

        // Verify registration
        assertEq(registry.ownerOf(tokenId), reservedUser);
        assertEq(expiry, block.timestamp + duration);

        // Verify reservation was removed after registration
        (bool isReserved, address reservedFor) = controller.checkReservation(name);
        assertFalse(isReserved);
        assertEq(reservedFor, address(0));
    }

    // Test non-authorized address can't register reserved name
    function testRegisterReservedNameUnauthorized() public {
        string memory name = "premium";
        uint256 duration = 365 days;
        uint256 maxPrice = 1000 ether;

        // Set reservation for reservedUser
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Try to register with signature from different user
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(user1);

        // Create EIP-712 digest and sign
        bytes32 digest = getRegistrationDigest(name, user1, duration, maxPrice, deadline, nonce);

        // Sign message
        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
            signature = abi.encodePacked(r, s, v);
        }

        // Calculate price and set up for the test
        uint256 expectedPrice = controller.calculatePrice(name, duration);
        vm.deal(user1, expectedPrice);
        vm.prank(user1);

        // Should revert because name is reserved
        vm.expectRevert(
            abi.encodeWithSelector(DotHypeController.NameIsReserved.selector, keccak256(bytes(name)), reservedUser)
        );
        controller.registerWithSignature{value: expectedPrice}(name, user1, duration, maxPrice, deadline, signature);

        // Try to register reserved name directly from different user
        uint256 price = controller.calculatePrice(name, duration);
        vm.deal(user1, price);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DotHypeController.NotAuthorized.selector, user1, keccak256(bytes(name))));
        controller.registerReserved{value: price}(name, duration);
    }

    // Test authorized address can register a reserved name directly
    function testRegisterReservedNameDirect() public {
        string memory name = "premium";
        uint256 duration = 365 days;

        // Set reservation for reservedUser
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Calculate price
        uint256 price = controller.calculatePrice(name, duration);

        // Register the reserved name
        vm.deal(reservedUser, price);
        vm.prank(reservedUser);
        (uint256 tokenId, uint256 expiry) = controller.registerReserved{value: price}(name, duration);

        // Verify registration
        assertEq(registry.ownerOf(tokenId), reservedUser);
        assertEq(expiry, block.timestamp + duration);
    }

    // Test registerReserved fails on non-reserved name
    function testRegisterNonReservedName() public {
        string memory name = "nonreserved";
        uint256 duration = 365 days;

        // Calculate price
        uint256 price = controller.calculatePrice(name, duration);

        // Try to register non-reserved name through registerReserved
        vm.deal(user1, price);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DotHypeController.NotReserved.selector, name));
        controller.registerReserved{value: price}(name, duration);
    }

    // Test reservedUser can register normally through signature despite reservation
    function testReservedUserRegisterNormally() public {
        string memory name = "premium";
        uint256 duration = 365 days;
        uint256 maxPrice = 1000 ether;

        // Set reservation for reservedUser
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Register through normal signature method
        (uint256 tokenId, uint256 expiry) = _registerWithSignature(name, reservedUser, duration, maxPrice);

        // Verify registration
        assertEq(registry.ownerOf(tokenId), reservedUser);
        assertEq(expiry, block.timestamp + duration);

        // Verify reservation was not cleared (since we used normal registration)
        (bool isReserved, address reservedFor) = controller.checkReservation(name);
        assertTrue(isReserved);
        assertEq(reservedFor, reservedUser);
    }

    // Test batch reservation setting
    function testSetBatchReservations() public {
        // Create test data
        string[] memory names = new string[](3);
        address[] memory reservedAddresses = new address[](3);

        names[0] = "batch1";
        names[1] = "batch2";
        names[2] = "batch3";

        reservedAddresses[0] = user1;
        reservedAddresses[1] = user2;
        reservedAddresses[2] = reservedUser;

        // Set batch reservations
        vm.prank(owner);
        controller.setBatchReservations(names, reservedAddresses);

        // Verify each reservation is set correctly
        for (uint256 i = 0; i < names.length; i++) {
            (bool isReserved, address reservedFor) = controller.checkReservation(names[i]);
            assertTrue(isReserved);
            assertEq(reservedFor, reservedAddresses[i]);
        }
    }

    // Test batch reservation removal
    function testRemoveBatchReservations() public {
        // First set up batch reservations
        string[] memory names = new string[](3);
        address[] memory reservedAddresses = new address[](3);

        names[0] = "batch1";
        names[1] = "batch2";
        names[2] = "batch3";

        reservedAddresses[0] = user1;
        reservedAddresses[1] = user2;
        reservedAddresses[2] = reservedUser;

        vm.prank(owner);
        controller.setBatchReservations(names, reservedAddresses);

        // Create an array of address(0) to remove reservations
        address[] memory zeroAddresses = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            zeroAddresses[i] = address(0);
        }

        // Now remove them with batch reservation to address(0)
        vm.prank(owner);
        controller.setBatchReservations(names, zeroAddresses);

        // Verify each reservation was removed
        for (uint256 i = 0; i < names.length; i++) {
            (bool isReserved, address reservedFor) = controller.checkReservation(names[i]);
            assertFalse(isReserved);
            assertEq(reservedFor, address(0));
        }
    }

    // Test mismatched array lengths in batch reservation
    function testBatchReservationMismatchedLengths() public {
        // Create test data with mismatched lengths
        string[] memory names = new string[](3);
        address[] memory reservedAddresses = new address[](2); // One less than names

        names[0] = "batch1";
        names[1] = "batch2";
        names[2] = "batch3";

        reservedAddresses[0] = user1;
        reservedAddresses[1] = user2;

        // This should revert with "Array lengths mismatch"
        vm.prank(owner);
        vm.expectRevert("Array lengths mismatch");
        controller.setBatchReservations(names, reservedAddresses);
    }

    // Test non-owner cannot set reservations
    function testSetReservationUnauthorized() public {
        string memory name = "premium";

        // Try to set reservation from non-owner account
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        controller.setReservation(name, reservedUser);

        // Verify reservation was not set
        (bool isReserved, address reservedFor) = controller.checkReservation(name);
        assertFalse(isReserved);
        assertEq(reservedFor, address(0));
    }

    // Test non-owner cannot remove reservations
    function testRemoveReservationUnauthorized() public {
        string memory name = "premium";

        // First set a reservation as owner
        vm.prank(owner);
        controller.setReservation(name, reservedUser);

        // Try to remove reservation from non-owner account by setting to address(0)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        controller.setReservation(name, address(0));

        // Verify reservation still exists
        (bool isReserved, address reservedFor) = controller.checkReservation(name);
        assertTrue(isReserved);
        assertEq(reservedFor, reservedUser);
    }

    // Test non-owner cannot set batch reservations
    function testSetBatchReservationsUnauthorized() public {
        // Create test data
        string[] memory names = new string[](3);
        address[] memory reservedAddresses = new address[](3);

        names[0] = "batch1";
        names[1] = "batch2";
        names[2] = "batch3";

        reservedAddresses[0] = user1;
        reservedAddresses[1] = user2;
        reservedAddresses[2] = reservedUser;

        // Try to set batch reservations from non-owner account
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        controller.setBatchReservations(names, reservedAddresses);

        // Verify reservations were not set
        for (uint256 i = 0; i < names.length; i++) {
            (bool isReserved, address reservedFor) = controller.checkReservation(names[i]);
            assertFalse(isReserved);
            assertEq(reservedFor, address(0));
        }
    }
}
