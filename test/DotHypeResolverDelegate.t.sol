// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeResolver.sol";

/**
 * @title DotHypeResolverDelegateTest
 * @dev Test contract for the delegate functionality in DotHypeResolver
 */
contract DotHypeResolverDelegateTest is Test {
    // Contracts
    DotHypeRegistry public registry;
    DotHypeResolver public resolver;

    // Test accounts
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    address public delegate1 = address(0x5);
    address public delegate2 = address(0x6);

    // Test domains
    string public aliceName = "alice";
    string public bobName = "bob";
    bytes32 public aliceNode;
    bytes32 public bobNode;

    // Duration
    uint256 public constant REGISTRATION_DURATION = 365 days;

    /**
     * @dev Set up the test environment
     */
    function setUp() public {
        // Deploy registry and set owner as controller
        vm.startPrank(owner);
        registry = new DotHypeRegistry(owner, owner);

        // Deploy resolver
        resolver = new DotHypeResolver(owner, address(registry));

        // Register test domains
        (uint256 aliceTokenId,) = registry.register(aliceName, alice, REGISTRATION_DURATION);
        (uint256 bobTokenId,) = registry.register(bobName, bob, REGISTRATION_DURATION);

        // Convert tokenIds to nodes
        aliceNode = bytes32(aliceTokenId);
        bobNode = bytes32(bobTokenId);

        vm.stopPrank();
    }

    /**
     * @dev Test basic delegate setting and getting
     */
    function testSetAndGetDelegate() public {
        // Initially no delegate should be set
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), address(0));
        assertEq(resolver.getDelegate(aliceNode, alice), address(0));

        // Alice sets delegate1 as her delegate
        vm.expectEmit(true, true, true, true);
        emit DotHypeResolver.DelegateSet(aliceNode, alice, delegate1);

        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Verify delegate was set
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), delegate1);
        assertEq(resolver.getDelegate(aliceNode, alice), delegate1);
        assertTrue(resolver.isDelegateForCurrentOwner(aliceNode, delegate1));
        assertFalse(resolver.isDelegateForCurrentOwner(aliceNode, delegate2));
    }

    /**
     * @dev Test clearing a delegate
     */
    function testClearDelegate() public {
        // Alice sets a delegate
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Verify delegate is set
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), delegate1);

        // Alice clears the delegate
        vm.expectEmit(true, true, true, true);
        emit DotHypeResolver.DelegateCleared(aliceNode, alice, delegate1);

        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, address(0));
        vm.stopPrank();

        // Verify delegate is cleared
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), address(0));
        assertFalse(resolver.isDelegateForCurrentOwner(aliceNode, delegate1));
    }

    /**
     * @dev Test replacing a delegate
     */
    function testReplaceDelegate() public {
        // Alice sets delegate1
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Verify delegate1 is set
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), delegate1);

        // Alice replaces with delegate2
        vm.expectEmit(true, true, true, true);
        emit DotHypeResolver.DelegateSet(aliceNode, alice, delegate2);

        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate2);
        vm.stopPrank();

        // Verify delegate2 is now set and delegate1 is not
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), delegate2);
        assertTrue(resolver.isDelegateForCurrentOwner(aliceNode, delegate2));
        assertFalse(resolver.isDelegateForCurrentOwner(aliceNode, delegate1));
    }

    /**
     * @dev Test that only domain owner can set delegates
     */
    function testOnlyOwnerCanSetDelegate() public {
        // Bob tries to set a delegate for Alice's domain - should fail
        vm.startPrank(bob);
        vm.expectRevert("Not domain owner");
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Charlie tries to set a delegate for Alice's domain - should fail
        vm.startPrank(charlie);
        vm.expectRevert("Not domain owner");
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Alice can set her own delegate - should succeed
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), delegate1);
    }

    /**
     * @dev Test delegate can update address records
     */
    function testDelegateCanUpdateAddressRecords() public {
        // Alice sets delegate1 as her delegate
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Initially, address should resolve to alice (the owner)
        assertEq(resolver.addr(aliceNode), alice);

        // Delegate1 sets a custom address
        address customAddress = address(0x999);
        vm.startPrank(delegate1);
        resolver.setAddr(aliceNode, customAddress);
        vm.stopPrank();

        // Address should now resolve to the custom address
        assertEq(resolver.addr(aliceNode), customAddress);
    }

    /**
     * @dev Test delegate can update text records
     */
    function testDelegateCanUpdateTextRecords() public {
        string memory email = "alice@example.com";
        string memory twitter = "@alice";

        // Alice sets delegate1 as her delegate
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Delegate1 sets text records
        vm.startPrank(delegate1);
        resolver.setText(aliceNode, "email", email);
        resolver.setText(aliceNode, "twitter", twitter);
        vm.stopPrank();

        // Verify text records were set
        assertEq(resolver.text(aliceNode, "email"), email);
        assertEq(resolver.text(aliceNode, "twitter"), twitter);
    }

    /**
     * @dev Test delegate can update content hash
     */
    function testDelegateCanUpdateContentHash() public {
        bytes memory contentHash = hex"ee301017012204eff6f9a26dbef5e8720fabf993879d2d6c9aba90326a7a6add70dbec041461";

        // Alice sets delegate1 as her delegate
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Delegate1 sets content hash
        vm.startPrank(delegate1);
        resolver.setContenthash(aliceNode, contentHash);
        vm.stopPrank();

        // Verify content hash was set
        assertEq(resolver.contenthash(aliceNode), contentHash);
    }

    /**
     * @dev Test delegate can clear records
     */
    function testDelegateCanClearRecords() public {
        string memory email = "alice@example.com";
        address customAddress = address(0x999);

        // Alice sets delegate1 and some records
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        resolver.setAddr(aliceNode, customAddress);
        resolver.setText(aliceNode, "email", email);
        vm.stopPrank();

        // Verify records are set
        assertEq(resolver.addr(aliceNode), customAddress);
        assertEq(resolver.text(aliceNode, "email"), email);

        // Delegate1 clears all records
        vm.startPrank(delegate1);
        resolver.clearRecords(aliceNode);
        vm.stopPrank();

        // Records should be cleared (address falls back to owner)
        assertEq(resolver.addr(aliceNode), alice);
        assertEq(resolver.text(aliceNode, "email"), "");
    }

    /**
     * @dev Test non-delegate cannot update records
     */
    function testNonDelegateCannotUpdateRecords() public {
        // Alice sets delegate1 as her delegate
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Bob (not a delegate) tries to update records - should fail
        vm.startPrank(bob);
        vm.expectRevert();
        resolver.setAddr(aliceNode, bob);

        vm.expectRevert();
        resolver.setText(aliceNode, "email", "bob@example.com");

        vm.expectRevert();
        resolver.setContenthash(aliceNode, bytes("fake-hash"));
        vm.stopPrank();

        // Charlie (not a delegate) tries to update records - should fail
        vm.startPrank(charlie);
        vm.expectRevert();
        resolver.setAddr(aliceNode, charlie);
        vm.stopPrank();
    }

    /**
     * @dev Test delegate permissions after ownership transfer
     */
    function testDelegateAfterOwnershipTransfer() public {
        // Alice sets delegate1
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Verify delegate1 can update records
        vm.startPrank(delegate1);
        resolver.setAddr(aliceNode, delegate1);
        vm.stopPrank();
        assertEq(resolver.addr(aliceNode), delegate1);

        // Alice transfers domain to Bob
        vm.startPrank(alice);
        registry.transferFrom(alice, bob, uint256(aliceNode));
        vm.stopPrank();

        // Verify transfer worked
        assertEq(registry.ownerOf(uint256(aliceNode)), bob);

        // Alice's delegate should no longer work
        vm.startPrank(delegate1);
        vm.expectRevert();
        resolver.setAddr(aliceNode, address(0x888));
        vm.stopPrank();

        // Bob should be able to set his own delegate
        vm.startPrank(bob);
        resolver.setDelegate(aliceNode, delegate2);
        vm.stopPrank();

        // delegate2 should now be able to update records
        vm.startPrank(delegate2);
        resolver.setAddr(aliceNode, address(0x777));
        vm.stopPrank();
        assertEq(resolver.addr(aliceNode), address(0x777));
    }

    /**
     * @dev Test multiple domains with different delegates
     */
    function testMultipleDomainsWithDifferentDelegates() public {
        // Alice sets delegate1 for her domain
        vm.startPrank(alice);
        resolver.setDelegate(aliceNode, delegate1);
        vm.stopPrank();

        // Bob sets delegate2 for his domain
        vm.startPrank(bob);
        resolver.setDelegate(bobNode, delegate2);
        vm.stopPrank();

        // Verify delegates are set correctly
        assertEq(resolver.getDelegateForCurrentOwner(aliceNode), delegate1);
        assertEq(resolver.getDelegateForCurrentOwner(bobNode), delegate2);

        // delegate1 can update Alice's domain but not Bob's
        vm.startPrank(delegate1);
        resolver.setAddr(aliceNode, delegate1);

        vm.expectRevert();
        resolver.setAddr(bobNode, delegate1);
        vm.stopPrank();

        // delegate2 can update Bob's domain but not Alice's
        vm.startPrank(delegate2);
        resolver.setAddr(bobNode, delegate2);

        vm.expectRevert();
        resolver.setAddr(aliceNode, delegate2);
        vm.stopPrank();

        // Verify addresses are set correctly
        assertEq(resolver.addr(aliceNode), delegate1);
        assertEq(resolver.addr(bobNode), delegate2);
    }

    /**
     * @dev Test delegate with invalid node
     */
    function testDelegateWithInvalidNode() public {
        bytes32 invalidNode = bytes32(uint256(999999));

        // Alice tries to set delegate for non-existent node
        vm.startPrank(alice);
        vm.expectRevert();
        resolver.setDelegate(invalidNode, delegate1);
        vm.stopPrank();

        // Check delegate functions with invalid node
        assertEq(resolver.getDelegateForCurrentOwner(invalidNode), address(0));
        assertFalse(resolver.isDelegateForCurrentOwner(invalidNode, delegate1));
    }
}
