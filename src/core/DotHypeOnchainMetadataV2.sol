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
        // Generate the SVG image
        string memory svgImage = generateSVG(name);

        // Base64 encode the SVG
        string memory encodedSVG = Base64.encode(bytes(svgImage));

        uint256 expiry = registry.expiryOf(tokenId);

        // Generate and encode the JSON metadata
        string memory json = generateJSON(name, encodedSVG, tokenId, expiry);
        string memory encodedJSON = Base64.encode(bytes(json));

        // Return the data URI
        return string(abi.encodePacked("data:application/json;base64,", encodedJSON));
    }

    /**
     * @dev Generates an SVG image for a .hype domain with modern gradient design
     * @param name The domain name
     * @return The SVG string
     */
    function generateSVG(string memory name) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg width="1074" height="1078" viewBox="0 0 1074 1078" fill="none" xmlns="http://www.w3.org/2000/svg">',
                '<g id="dotHYPE NFT Logo integrated">',
                '<g id="Background w/ Logo">',
                '<path d="M0 0H1074V1078H0V0Z" fill="#CAF1FF"/>',
                '<path d="M165.014 45.2575H44.0037C41.3837 45.2575 39.2494 47.3796 39.2494 49.99V139.006C39.2494 141.616 41.3793 143.743 44.0037 143.743H165.014C167.634 143.743 169.768 141.62 169.768 139.006V49.99C169.768 47.3796 167.638 45.253 165.014 45.253V45.2575ZM167.05 140.994C166.988 141.061 166.921 141.119 166.85 141.181C166.778 141.239 166.707 141.296 166.631 141.345C166.556 141.398 166.48 141.443 166.4 141.487C166.4 141.487 166.4 141.487 166.395 141.487C166.319 141.532 166.239 141.567 166.159 141.603C166.155 141.603 166.15 141.607 166.146 141.607C166.065 141.643 165.985 141.674 165.901 141.7C165.896 141.7 165.887 141.705 165.883 141.709C165.803 141.736 165.718 141.758 165.633 141.776C165.624 141.776 165.615 141.78 165.611 141.78C165.522 141.798 165.437 141.811 165.344 141.82C165.339 141.82 165.33 141.82 165.326 141.82C165.232 141.829 165.134 141.838 165.036 141.838H107.374C105.801 141.838 104.509 140.559 104.651 138.997C106.091 122.895 119.667 110.269 136.207 110.269C152.747 110.269 166.324 122.89 167.763 138.997C167.83 139.765 167.554 140.466 167.064 140.977L167.05 140.994ZM41.5709 140.484C41.4416 140.271 41.3392 140.044 41.2679 139.8C41.2679 139.787 41.2634 139.774 41.259 139.765C41.2322 139.667 41.2099 139.565 41.1921 139.458C41.1877 139.432 41.1832 139.401 41.1788 139.37C41.1654 139.254 41.152 139.134 41.152 139.014C41.152 139.014 41.152 139.014 41.152 139.01V49.99C41.152 49.8878 41.1565 49.7902 41.1698 49.6881C41.1788 49.586 41.1966 49.4839 41.2189 49.3862C41.2233 49.3596 41.2322 49.3329 41.2411 49.3018C41.259 49.2264 41.2812 49.1465 41.308 49.0754C41.3169 49.0488 41.3258 49.0266 41.3347 49C41.3659 48.92 41.3971 48.8446 41.4327 48.7647C41.4416 48.7469 41.4461 48.7336 41.455 48.7158C41.4996 48.627 41.553 48.5383 41.6065 48.4539C41.6065 48.4495 41.611 48.445 41.6154 48.4406C41.6243 48.4273 41.6288 48.4139 41.6377 48.4006C41.6511 48.3829 41.6644 48.3696 41.6733 48.3518C42.1902 47.6326 43.0368 47.1753 43.9993 47.233C68.916 48.7025 88.6729 69.3061 88.6729 94.5C88.6729 119.694 68.916 140.293 43.9993 141.767C42.97 141.829 42.0699 141.296 41.5664 140.484H41.5709ZM165.014 47.1531C165.112 47.1531 165.21 47.1576 165.308 47.1665C165.33 47.1665 165.357 47.1753 165.379 47.1753C165.451 47.1842 165.526 47.1931 165.598 47.2109C165.62 47.2153 165.638 47.2242 165.66 47.2286C165.731 47.2464 165.807 47.2641 165.878 47.2863C165.892 47.2908 165.909 47.2996 165.923 47.3041C165.999 47.3307 166.074 47.3574 166.146 47.3884C166.155 47.3884 166.163 47.3973 166.172 47.4017C166.253 47.4373 166.328 47.4728 166.404 47.5172C166.404 47.5172 166.413 47.5216 166.417 47.5261C166.498 47.5704 166.573 47.6193 166.649 47.6726C166.801 47.7791 166.943 47.9034 167.072 48.0366C167.545 48.5471 167.817 49.2352 167.745 49.99C166.306 66.0963 152.729 78.7177 136.189 78.7177C119.65 78.7177 106.073 66.0963 104.634 49.99C104.495 48.4273 105.779 47.1531 107.352 47.1531H165.014Z" fill="black"/>',
                '</g>',
                '<g id="Logo">',
                '<g id="CenteredTextContainer">',
                '<!-- Username -->',
                '<g id="Username" transform="translate(0, 0)">',
                '<text id="JuicyHamdogs" fill="black" xml:space="preserve" style="white-space: pre" font-family="Feature Text Trial" font-size="58.4413" letter-spacing="0em" text-anchor="end" x="520" y="970">',
                name,
                '</text>',
                '</g>',
                '<!-- .hype Wordmark to the right of username -->',
                '<g id=".hype Wordmark" transform="translate(-80, -38)">',
                '<g id="Group">',
                '<path id="Vector" d="M846.241 960.53C844.529 962.367 843.694 964.998 843.694 968.422V995.269C843.694 998.693 844.571 1001.37 846.241 1003.16C848.036 1005.08 850.792 1006.08 854.425 1006.08H911.794V994.016H862.65C861.94 994.016 860.938 993.849 860.228 992.931C859.56 992.096 859.435 991.094 859.435 990.384V987.879H911.668V975.812H859.435V973.307C859.435 972.597 859.56 971.553 860.228 970.76C860.938 969.883 861.94 969.674 862.65 969.674H911.794V957.607H854.425C850.792 957.607 848.036 958.568 846.241 960.53Z" fill="black"/>',
                '<path id="Vector_2" d="M830.917 957.649H773.548V1006.17H789.248V987.962H830.876C834.508 987.962 837.264 987.002 839.059 985.039C840.771 983.202 841.606 980.572 841.606 977.148V968.505C841.606 965.081 840.729 962.409 839.059 960.614C837.264 958.693 834.508 957.691 830.876 957.691L830.917 957.649ZM825.406 974.893C825.072 975.311 824.487 975.854 823.527 975.854H789.289V969.716H823.527C824.487 969.716 825.072 970.259 825.406 970.676C825.949 971.428 826.032 972.305 826.032 972.806C826.032 973.307 825.949 974.184 825.406 974.935V974.893Z" fill="black"/>',
                '<path id="Vector_3" d="M755.803 975.854H722.484C721.774 975.854 720.772 975.687 720.062 974.768C719.394 973.933 719.269 972.931 719.269 972.221V957.649H703.57V977.106C703.57 980.53 704.447 983.202 706.117 984.998C707.912 986.918 710.668 987.92 714.3 987.92H755.845V990.426C755.845 991.135 755.72 992.179 755.052 992.973C754.342 993.849 753.34 994.058 752.63 994.058H703.611V1006.12H760.855C764.488 1006.12 767.244 1005.16 769.039 1003.2C770.751 1001.36 771.586 998.735 771.586 995.311V957.649H755.887V975.854H755.803Z" fill="black"/>',
                '<path id="Vector_4" d="M685.825 976.564H650.042V957.649H634.426L634.51 1006.12H650.042V988.63H685.825V1006.12H701.44V957.649H685.825V976.564Z" fill="black"/>',
                '<path id="Vector_5" d="M618.936 990.342C614.426 990.342 610.794 993.766 610.794 997.983C610.794 1002.2 614.426 1005.62 618.936 1005.62C623.445 1005.62 627.078 1002.2 627.078 997.983C627.078 993.766 623.445 990.342 618.936 990.342Z" fill="black"/>',
                '</g>',
                '</g>',
                '</g>',
                '</g>',
                '<circle id="Orb" cx="537.009" cy="514" r="391" fill="url(#paint0_radial_15_30)"/>',
                '</g>',
                '<defs>',
                '<radialGradient id="paint0_radial_15_30" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(537.009 514) rotate(90) scale(391)">',
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
                '.hype",',
                '"description":"A .hype domain on the Hyperliquid network with modern gradient design.",',
                '"image":"data:image/svg+xml;base64,',
                encodedSVG,
                '",',
                '"attributes":[',
                '{"trait_type":"Name","value":"',
                name,
                '"},',
                '{"trait_type":"Length","value":',
                uint256(bytes(name).length).toString(),
                "},",
                '{"trait_type":"Token ID","value":"',
                tokenId.toString(),
                '"},',
                '{"trait_type":"Expiry","value":"',
                Strings.toString(expiry),
                '"},',
                '{"trait_type":"Version","value":"V2"}',
                "]}"
            )
        );
    }
} 