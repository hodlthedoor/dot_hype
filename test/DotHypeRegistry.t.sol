// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeMetadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DotHypeRegistryTest is Test {
    DotHypeRegistry public registry;
    DotHypeMetadata public metadata;
    
    address public owner = address(1);
    address public controller = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    
    string public constant BASE_URI = "https://metadata.dothype.xyz/";
    
    // Constants for namehash calculation
    bytes32 constant EMPTY_NODE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant TLD_NODE = keccak256(abi.encodePacked(EMPTY_NODE, keccak256(abi.encodePacked("hype"))));
    
    function setUp() public {
        // Deploy registry
        registry = new DotHypeRegistry(
            owner,
            controller
        );
        
        // Deploy metadata provider
        metadata = new DotHypeMetadata(
            owner,
            BASE_URI
        );
        
        // Set up test users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    function testRegisterName() public {
        string memory name = "test";
        uint256 duration = 365 days;
        
        // Register a name (from controller)
        vm.prank(controller);
        (uint256 tokenId, uint256 expiry) = registry.register(
            name,
            user1,
            duration
        );
        
        // Verify registration
        assertEq(registry.ownerOf(tokenId), user1);
        assertEq(registry.expiryOf(tokenId), expiry);
        assertEq(registry.tokenIdToName(tokenId), name);
        
        // Verify that the name is no longer available
        assertFalse(registry.available(name));
    }
    
    function testRegisterNameUnauthorized() public {
        string memory name = "test";
        uint256 duration = 365 days;
        
        // Try to register from non-controller account
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DotHypeRegistry.NotAuthorized.selector, user1, 0));
        registry.register(
            name,
            user1,
            duration
        );
    }
    
    function testRegisterNameTooShortDuration() public {
        string memory name = "test";
        uint256 duration = 1 days; // Too short
        
        // Try to register with too short duration
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(DotHypeRegistry.DurationTooShort.selector, duration, 28 days));
        registry.register(
            name,
            user1,
            duration
        );
    }
    
    function testRenewName() public {
        string memory name = "test";
        uint256 duration = 365 days;
        
        // Register a name
        vm.prank(controller);
        (uint256 tokenId, uint256 initialExpiry) = registry.register(
            name,
            user1,
            duration
        );
        
        // Renew the name
        vm.prank(controller);
        uint256 newExpiry = registry.renew(
            tokenId,
            duration
        );
        
        // Verify renewal
        assertEq(newExpiry, initialExpiry + duration);
        assertEq(registry.expiryOf(tokenId), newExpiry);
    }
    
    function testRenewNonExistentName() public {
        uint256 nonExistentTokenId = 999;
        uint256 duration = 365 days;
        
        // Try to renew non-existent name
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(DotHypeRegistry.TokenNotRegistered.selector, nonExistentTokenId));
        registry.renew(
            nonExistentTokenId,
            duration
        );
    }
    
    function testTransferName() public {
        string memory name = "test";
        uint256 duration = 365 days;
        
        // Register a name
        vm.prank(controller);
        (uint256 tokenId, ) = registry.register(
            name,
            user1,
            duration
        );
        
        // Transfer the name
        vm.prank(user1);
        registry.transferFrom(user1, user2, tokenId);
        
        // Verify transfer
        assertEq(registry.ownerOf(tokenId), user2);
    }
    
    function testNameToTokenId() public view {
        string memory label = "test";
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 namehash = keccak256(abi.encodePacked(TLD_NODE, labelhash));
        uint256 expectedTokenId = uint256(namehash);
        
        assert(registry.nameToTokenId(label) == expectedTokenId);
    }
    
    function testSetController() public {
        address newController = address(5);
        
        // Change controller
        vm.prank(owner);
        registry.setController(newController);
        
        // Verify controller was changed
        assertEq(registry.controller(), newController);
        
        // Try to register using old controller (should fail)
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(DotHypeRegistry.NotAuthorized.selector, controller, 0));
        registry.register("test", user1, 365 days);
        
        // Register using new controller (should succeed)
        vm.prank(newController);
        (uint256 tokenId, ) = registry.register("test", user1, 365 days);
        
        // Verify registration worked
        assertEq(registry.ownerOf(tokenId), user1);
    }
    
    function testUpdateControllerFromAdmin() public {
        address newController = address(10);
        
        // Update controller from owner account
        vm.prank(owner);
        registry.setController(newController);
        
        // Verify controller was updated
        assertEq(registry.controller(), newController);
    }
    
    function testUpdateControllerFromNonAdmin() public {
        address newController = address(10);
        
        // Try to update controller from non-owner account
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        registry.setController(newController);
        
        // Verify controller was not changed
        assertEq(registry.controller(), controller);
    }
    
    function testRenewFromAnyAddress() public {
        string memory name = "test";
        uint256 duration = 365 days;
        
        // Register a name
        vm.prank(controller);
        (uint256 tokenId, uint256 initialExpiry) = registry.register(
            name,
            user1,
            duration
        );
        
        // Try to renew from non-controller (should fail)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DotHypeRegistry.NotAuthorized.selector, user1, 0));
        registry.renew(tokenId, duration);
        
        // Verify expiry wasn't changed
        assertEq(registry.expiryOf(tokenId), initialExpiry);
        
        // Renew from controller (should succeed)
        vm.prank(controller);
        uint256 newExpiry = registry.renew(tokenId, duration);
        
        // Verify renewal
        assertEq(newExpiry, initialExpiry + duration);
    }
    
    function testSetMetadataProviderFromOwner() public {
        // Set metadata provider from owner
        vm.prank(owner);
        registry.setMetadataProvider(address(metadata));
        
        // Verify metadata provider was set
        assertEq(address(registry.metadataProvider()), address(metadata));
        
        // Register a name
        string memory name = "test";
        vm.prank(controller);
        (uint256 tokenId, ) = registry.register(name, user1, 365 days);
        
        // Verify tokenURI is correct
        string memory expectedURI = string(abi.encodePacked(BASE_URI, name, ".json"));
        assertEq(registry.tokenURI(tokenId), expectedURI);
    }
    
    function testSetMetadataProviderFromNonOwner() public {
        // Try to set metadata provider from non-owner
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        registry.setMetadataProvider(address(metadata));
        
        // Verify metadata provider was not set
        assertEq(address(registry.metadataProvider()), address(0));
    }
    
    function testTokenURIWithoutMetadataProvider() public {
        // Register a name
        string memory name = "test";
        vm.prank(controller);
        (uint256 tokenId, ) = registry.register(name, user1, 365 days);
        
        // Verify tokenURI uses default implementation (should be empty since no baseURI is set)
        assertEq(registry.tokenURI(tokenId), "");
    }
    
    function testTokenURIWithMetadataProvider() public {
        // Set metadata provider
        vm.prank(owner);
        registry.setMetadataProvider(address(metadata));
        
        // Register a name
        string memory name = "test";
        vm.prank(controller);
        (uint256 tokenId, ) = registry.register(name, user1, 365 days);
        
        // Verify tokenURI is correct
        string memory expectedURI = string(abi.encodePacked(BASE_URI, name, ".json"));
        assertEq(registry.tokenURI(tokenId), expectedURI);
    }
    
    function testUpdateMetadataURIs() public {
        // Set metadata provider
        vm.prank(owner);
        registry.setMetadataProvider(address(metadata));
        
        // Register a name
        string memory name = "test";
        vm.prank(controller);
        (uint256 tokenId, ) = registry.register(name, user1, 365 days);
        
        // Update the base URI in the metadata contract
        string memory newBaseURI = "https://new.metadata.dothype.xyz/";
        vm.prank(owner);
        metadata.setBaseURI(newBaseURI);
        
        // Verify tokenURI is updated
        string memory expectedURI = string(abi.encodePacked(newBaseURI, name, ".json"));
        assertEq(registry.tokenURI(tokenId), expectedURI);
    }
} 