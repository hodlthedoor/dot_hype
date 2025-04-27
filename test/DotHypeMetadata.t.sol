// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/core/DotHypeMetadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DotHypeMetadataTest is Test {
    DotHypeMetadata public metadata;

    address public owner = address(1);
    address public user1 = address(2);

    string public constant BASE_URI = "https://metadata.dothype.xyz/";

    function setUp() public {
        // Deploy metadata provider
        metadata = new DotHypeMetadata(owner, BASE_URI);
    }

    function testTokenURI() public {
        // Test token URI formatting
        uint256 tokenId = 123;
        string memory name = "example";

        string memory expectedURI = string(abi.encodePacked(BASE_URI, name, ".json"));
        assertEq(metadata.tokenURI(tokenId, name), expectedURI);
    }

    function testSetBaseURI() public {
        // Test updating base URI
        string memory newBaseURI = "https://new.metadata.dothype.xyz/";

        // Update from owner
        vm.prank(owner);
        metadata.setBaseURI(newBaseURI);

        // Verify update
        uint256 tokenId = 123;
        string memory name = "example";
        string memory expectedURI = string(abi.encodePacked(newBaseURI, name, ".json"));
        assertEq(metadata.tokenURI(tokenId, name), expectedURI);
    }

    function testSetBaseURIUnauthorized() public {
        // Test updating base URI from unauthorized account
        string memory newBaseURI = "https://new.metadata.dothype.xyz/";

        // Try to update from non-owner
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        metadata.setBaseURI(newBaseURI);
    }
}
