// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DotHypeOnchainMetadataV2} from "../src/core/DotHypeOnchainMetadataV2.sol";
import "../src/core/DotHypeRegistry.sol";
import "../src/core/DotHypeController.sol";
import "./mocks/MockPriceOracle.sol";

contract DotHypeOnchainMetadataV2Test is Test {
    DotHypeOnchainMetadataV2 public metadata;
    DotHypeRegistry public registry;
    DotHypeController public controller;
    MockPriceOracle public oracle;

    address payable public owner;
    address public user1 = address(0x2);

    // Mock price parameters
    uint64 constant INITIAL_PRICE = 2000000; // $2.00 (scaled by 1e6)

    // Allow contract to receive ETH
    receive() external payable {}

    function setUp() public {
        owner = payable(address(this));
        registry = new DotHypeRegistry(owner, address(this));
        metadata = new DotHypeOnchainMetadataV2(owner, address(registry));

        // Deploy mock oracle
        oracle = new MockPriceOracle(INITIAL_PRICE);

        // Deploy controller
        controller = new DotHypeController(
            address(registry),
            owner, // signer
            address(oracle),
            owner
        );

        // Set up permissions
        vm.prank(owner);
        registry.setController(address(controller));
        vm.prank(owner);
        registry.setMetadataProvider(address(metadata));

        // Set up pricing for the controller
        uint256[5] memory prices = [
            uint256(0), // 1 character: unavailable
            uint256(0), // 2 characters: unavailable
            uint256(100 ether), // 3 characters: $100 per year
            uint256(10 ether), // 4 characters: $10 per year
            uint256(1 ether) // 5+ characters: $1 per year
        ];

        vm.prank(owner);
        controller.setAllAnnualPrices(prices);

        // Set up merkle root for testing (empty merkle root allows any proof)
        vm.prank(owner);
        controller.setMerkleRoot(bytes32(0));

        // Make sure the owner can receive payments
        vm.deal(owner, 1 ether);
    }

    function test_ShortNameNotTruncated() public view {
        string memory svg = metadata.generateSVG("short");
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, ">short<"));
    }

    function test_MediumNameNotTruncated() public view {
        string memory svg = metadata.generateSVG("eighteenchar123");
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, ">eighteenchar123<"));
    }

    function test_LongNameTruncated() public view {
        string memory svg = metadata.generateSVG("thisislongerthaneighteencharacters");
        assertTrue(bytes(svg).length > 0);
        // Check for the truncated format: first8...last8
        assertTrue(_containsSubstring(svg, ">thisisl...racters<"));
    }

    function test_ExactlyEighteenNotTruncated() public view {
        string memory svg = metadata.generateSVG("exactly18character");
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, ">exactly18character<"));
    }

    function testGenerateSVGWithShortName() public view {
        string memory svg = metadata.generateSVG("test");

        // Verify the SVG contains the domain name
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, "test"));
        assertTrue(_containsSubstring(svg, "Feature Text"));
        assertTrue(_containsSubstring(svg, "58.4413"));
        assertTrue(_containsSubstring(svg, "text-anchor=\"end\""));
        assertTrue(_containsSubstring(svg, "text-anchor=\"start\""));
        assertTrue(_containsSubstring(svg, "x=\"534\""));
        assertTrue(_containsSubstring(svg, "x=\"538\""));
        assertTrue(_containsSubstring(svg, "LETO"));
        assertTrue(_containsSubstring(svg, ".HYPE"));
    }

    function testGenerateSVGWithLongName() public view {
        string memory svg = metadata.generateSVG("verylongdomainname");

        // Verify the SVG contains the domain name
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, "verylongdomainname"));
        assertTrue(_containsSubstring(svg, "Feature Text"));
        assertTrue(_containsSubstring(svg, "58.4413"));
        assertTrue(_containsSubstring(svg, "text-anchor=\"end\""));
        assertTrue(_containsSubstring(svg, "text-anchor=\"start\""));
        assertTrue(_containsSubstring(svg, "x=\"534\""));
        assertTrue(_containsSubstring(svg, "x=\"538\""));
        assertTrue(_containsSubstring(svg, "LETO"));
        assertTrue(_containsSubstring(svg, ".HYPE"));
    }

    function testGenerateSVGWithSpecialCharacters() public view {
        string memory svg = metadata.generateSVG("test-123");

        // Verify the SVG contains the domain name
        assertTrue(bytes(svg).length > 0);
        assertTrue(_containsSubstring(svg, "test-123"));
        assertTrue(_containsSubstring(svg, "text-anchor=\"end\""));
        assertTrue(_containsSubstring(svg, "text-anchor=\"start\""));
        assertTrue(_containsSubstring(svg, "x=\"534\""));
        assertTrue(_containsSubstring(svg, "x=\"538\""));
    }

    function testTokenURI() public {
        // Register a domain first
        string memory name = "testdomain";
        uint256 duration = 365 days;
        uint256 price = controller.calculatePrice(name, duration);

        // Set up signature-based registration
        uint256 signerPrivateKey = 0xA11CE;
        address signer = vm.addr(signerPrivateKey);

        // Update controller to use this signer
        vm.prank(owner);
        controller.setSigner(signer);

        // Prepare registration parameters
        uint256 maxPrice = type(uint256).max; // Allow any price
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = controller.getNextNonce(user1);

        // Create EIP-712 digest
        bytes32 REGISTRATION_TYPEHASH = keccak256(
            "Registration(string name,address owner,uint256 duration,uint256 maxPrice,uint256 deadline,uint256 nonce)"
        );

        bytes32 structHash = keccak256(
            abi.encode(REGISTRATION_TYPEHASH, keccak256(bytes(name)), user1, duration, maxPrice, deadline, nonce)
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("DotHypeController"),
                keccak256("1"),
                block.chainid,
                address(controller)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Register domain with signature
        vm.deal(user1, price * 2); // Give extra ETH to cover any fees
        vm.prank(user1);
        controller.registerWithSignature{value: price}(name, user1, duration, maxPrice, deadline, signature);

        uint256 tokenId = registry.nameToTokenId(name);
        string memory uri = metadata.tokenURI(tokenId, name);

        // Verify it's a valid data URI with proper format
        assertTrue(_containsSubstring(uri, "data:application/json;base64,"));
        assertTrue(bytes(uri).length > 50); // Should be a substantial base64 string
    }

    function testGenerateJSON() public view {
        string memory name = "testdomain";
        string memory encodedSVG = "test-svg-data";
        uint256 tokenId = 123;
        uint256 expiry = block.timestamp + 365 days;

        string memory json = metadata.generateJSON(name, encodedSVG, tokenId, expiry);

        // Verify JSON structure
        assertTrue(_containsSubstring(json, "testdomain.hype"));
        assertTrue(_containsSubstring(json, "A .hype identity on HyperEVM"));
        assertTrue(_containsSubstring(json, "data:image/svg+xml;base64,test-svg-data"));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Name\",\"value\":\"testdomain\""));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Length\",\"value\":10"));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Token ID\",\"value\":\"123\""));
        assertTrue(_containsSubstring(json, "\"trait_type\":\"Expiry\",\"value\":\""));
    }

    // Helper function to check if a string contains a substring
    function _containsSubstring(string memory _string, string memory _substring) internal pure returns (bool) {
        bytes memory stringBytes = bytes(_string);
        bytes memory substringBytes = bytes(_substring);

        if (substringBytes.length > stringBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= stringBytes.length - substringBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substringBytes.length; j++) {
                if (stringBytes[i + j] != substringBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
}
