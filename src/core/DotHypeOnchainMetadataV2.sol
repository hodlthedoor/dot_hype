// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IDotHypeMetadata.sol";
import "../interfaces/IDotHypeRegistry.sol";

/**
 * @title DotHypeOnchainMetadataV2
 * @dev Implements on-chain SVG and JSON generation for .hype domains using provided SVG template
 */
contract DotHypeOnchainMetadataV2 is Ownable, IDotHypeMetadata {
    using Strings for uint256;
    using Strings for address;

    // Registry reference
    IDotHypeRegistry public registry;

    /**
     * @dev Constructor
     * @param _owner Initial owner of the contract
     * @param _registry Address of the DotHypeRegistry contract
     */
    constructor(address _owner, address _registry) Ownable(_owner) {
        registry = IDotHypeRegistry(_registry);
    }

    /**
     * @dev Returns the metadata for a specific token ID as a base64 encoded JSON
     * @param tokenId The ID of the token
     * @param name The name associated with the token
     * @return A base64 encoded JSON string
     */
    function tokenURI(uint256 tokenId, string calldata name) external view override returns (string memory) {
        // Get expiry from registry
        uint256 expiry = registry.expiryOf(tokenId);
        
        // Generate SVG
        string memory svg = generateSVG(name);
        string memory encodedSVG = Base64.encode(bytes(svg));
        
        // Generate JSON
        string memory json = generateJSON(name, encodedSVG, tokenId, expiry);
        
        // Return base64 encoded JSON
        return string(
            abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json)))
        );
    }

    /**
     * @dev Truncates a long domain name to a maximum of 18 characters
     * @param name The domain name
     * @return The truncated domain name
     */
    function truncateLongName(string memory name) internal pure returns (string memory) {
        bytes memory nameBytes = bytes(name);
        if (nameBytes.length <= 18) {
            return name;
        }
        
        // Get first 7 characters
        bytes memory first7 = new bytes(7);
        for (uint i = 0; i < 7; i++) {
            first7[i] = nameBytes[i];
        }
        
        // Get last 7 characters
        bytes memory last7 = new bytes(7);
        for (uint i = 0; i < 7; i++) {
            last7[i] = nameBytes[nameBytes.length - 7 + i];
        }
        
        // Combine with "..."
        return string(abi.encodePacked(string(first7), "...", string(last7)));
    }

    /**
     * @dev Generates an SVG image for a .hype domain with modern gradient design
     * @param name The domain name
     * @return The SVG string
     */
    function generateSVG(string memory name) public pure returns (string memory) {
        string memory displayName = truncateLongName(name);
        return string(
            abi.encodePacked(
                '<svg width="1078" height="1078" viewBox="0 0 1078 1078" fill="none" xmlns="http://www.w3.org/2000/svg">',
                '<g id="dotHYPE NFT w/ two fonts">',
                '<rect id="NFT Background" width="1074" height="1078" fill="#CAF1FF"/>',
                // Main container for text elements
                '<g id="Username.hype">',
                // Domain name on the right side of center
                '<text id="domain-name" fill="black" xml:space="preserve" style="white-space: pre" font-family="Feature Text" font-size="58.4413" letter-spacing="0em" text-anchor="end" x="534" y="999.831">',
                displayName,
                '</text>',
                // .HYPE on the left side of center with minimal fixed spacing (4px gap)
                '<text id="hype-text" fill="black" xml:space="preserve" style="white-space: pre" font-family="LETO" font-size="96" letter-spacing="0em" text-anchor="start" x="538" y="1001">.HYPE</text>',
                '</g>',
                '<path id="dotHYPE logo" d="M165.629 45.2575H44.1678C41.538 45.2575 39.3958 47.3796 39.3958 49.99V139.006C39.3958 141.616 41.5335 143.743 44.1678 143.743H165.629C168.258 143.743 170.401 141.62 170.401 139.006V49.99C170.401 47.3796 168.263 45.253 165.629 45.253V45.2575ZM167.672 140.994C167.61 141.061 167.543 141.119 167.471 141.181C167.4 141.239 167.328 141.296 167.252 141.345C167.176 141.398 167.1 141.443 167.02 141.487C167.02 141.487 167.02 141.487 167.015 141.487C166.939 141.532 166.858 141.567 166.778 141.603C166.774 141.603 166.769 141.607 166.765 141.607C166.684 141.643 166.604 141.674 166.519 141.7C166.514 141.7 166.505 141.705 166.501 141.709C166.42 141.736 166.335 141.758 166.25 141.776C166.241 141.776 166.232 141.78 166.228 141.78C166.138 141.798 166.053 141.811 165.96 141.82C165.955 141.82 165.946 141.82 165.942 141.82C165.848 141.829 165.749 141.838 165.651 141.838H107.774C106.195 141.838 104.898 140.559 105.041 138.997C106.486 122.895 120.113 110.269 136.715 110.269C153.316 110.269 166.943 122.89 168.388 138.997C168.455 139.765 168.178 140.466 167.686 140.977L167.672 140.994ZM41.7259 140.484C41.5962 140.271 41.4933 140.044 41.4217 139.8C41.4217 139.787 41.4173 139.774 41.4128 139.765C41.386 139.667 41.3636 139.565 41.3457 139.458C41.3412 139.432 41.3368 139.401 41.3323 139.37C41.3189 139.254 41.3055 139.134 41.3055 139.014C41.3055 139.014 41.3055 139.014 41.3055 139.01V49.99C41.3055 49.8878 41.3099 49.7902 41.3233 49.6881C41.3323 49.586 41.3502 49.4839 41.3725 49.3862C41.377 49.3596 41.386 49.3329 41.3949 49.3018C41.4128 49.2264 41.4352 49.1465 41.462 49.0754C41.4709 49.0488 41.4799 49.0266 41.4888 49C41.5201 48.92 41.5514 48.8446 41.5872 48.7647C41.5962 48.7469 41.6006 48.7336 41.6096 48.7158C41.6543 48.627 41.708 48.5382 41.7616 48.4539C41.7616 48.4495 41.7661 48.445 41.7706 48.4406C41.7795 48.4273 41.784 48.4139 41.7929 48.4006C41.8064 48.3829 41.8198 48.3696 41.8287 48.3518C42.3475 47.6326 43.1973 47.1753 44.1633 47.233C69.1728 48.7025 89.0034 69.3061 89.0034 94.5C89.0034 119.694 69.1728 140.293 44.1633 141.767C43.1302 141.829 42.2268 141.296 41.7214 140.484H41.7259ZM165.629 47.1531C165.727 47.1531 165.825 47.1576 165.924 47.1665C165.946 47.1665 165.973 47.1753 165.995 47.1753C166.067 47.1842 166.143 47.1931 166.214 47.2109C166.237 47.2153 166.255 47.2242 166.277 47.2286C166.349 47.2464 166.425 47.2641 166.496 47.2863C166.51 47.2908 166.528 47.2996 166.541 47.3041C166.617 47.3307 166.693 47.3574 166.765 47.3884C166.774 47.3884 166.782 47.3973 166.791 47.4017C166.872 47.4373 166.948 47.4728 167.024 47.5172C167.024 47.5172 167.033 47.5216 167.037 47.5261C167.118 47.5704 167.194 47.6193 167.27 47.6726C167.422 47.7791 167.565 47.9034 167.695 48.0366C168.169 48.5471 168.442 49.2352 168.37 49.99C166.926 66.0963 153.298 78.7177 136.697 78.7177C120.095 78.7177 106.468 66.0963 105.023 49.99C104.885 48.4273 106.173 47.1531 107.752 47.1531H165.624H165.629Z" fill="black"/>',
                '<circle id="Orb" cx="537" cy="504" r="391" fill="url(#paint0_radial_266_654)"/>',
                '</g>',
                '<defs>',
                '<radialGradient id="paint0_radial_266_654" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(537 504) rotate(90) scale(391)">',
                '<stop offset="0.274038" stop-color="#CBF7F5"/>',
                '<stop offset="0.716346" stop-color="#7BC0F6"/>',
                '<stop offset="1" stop-color="#E87DC5"/>',
                '</radialGradient>',
                '</defs>',
                '</svg>'
            )
        );
    }

    /**
     * @dev Generates JSON metadata for a .hype domain
     * @param name The domain name
     * @param encodedSVG The base64 encoded SVG
     * @param tokenId The token ID
     * @param expiry The expiry timestamp of the domain (0 if not set)
     * @return The JSON string
     */
    function generateJSON(string memory name, string memory encodedSVG, uint256 tokenId, uint256 expiry)
        public
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '{"name":"',
                name,
                '.hype","description":"A .hype identity on HyperEVM","image":"data:image/svg+xml;base64,',
                encodedSVG,
                '","attributes":[{"trait_type":"Name","value":"',
                name,
                '"},{"trait_type":"Length","value":',
                uint256(bytes(name).length).toString(),
                '},{"trait_type":"Token ID","value":"',
                tokenId.toString(),
                '"},{"trait_type":"Expiry","value":"',
                expiry.toString(),
                '"},{"trait_type":"Version","value":"V2"}]}'
            )
        );
    }
} 