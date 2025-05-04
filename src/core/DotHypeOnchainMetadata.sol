// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IDotHypeMetadata.sol";

/**
 * @title DotHypeOnchainMetadata
 * @dev Implements on-chain SVG and JSON generation for .hype domains
 */
contract DotHypeOnchainMetadata is Ownable, IDotHypeMetadata {
    using Strings for uint256;
    using Strings for address;

    // SVG configuration variables
    string public backgroundColor = "#141420"; // Deeper blue background
    string public textColor = "#FFFFFF";       // White text
    string public accentColor = "#FF5F1F";     // Orange accent color
    string public logoColor = "#97FCE4";       // Hyperliquid logo color
    string public circleColor = "#1D1D30";     // Subtle inner circle color
    
    // Font size and style configuration
    uint256 public mainFontSize = 40;
    uint256 public secondaryFontSize = 16;
    string public fontFamily = "'Helvetica Neue', Arial, sans-serif";
    
    // Design settings
    uint256 public logoSize = 80;
    uint256 public circleRadius = 170;

    /**
     * @dev Constructor
     * @param _owner Initial owner of the contract
     */
    constructor(address _owner) Ownable(_owner) {}

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
        
        // Generate and encode the JSON metadata
        string memory json = generateJSON(name, encodedSVG, tokenId);
        string memory encodedJSON = Base64.encode(bytes(json));
        
        // Return the data URI
        return string(abi.encodePacked("data:application/json;base64,", encodedJSON));
    }

    /**
     * @dev Generates an SVG image for a .hype domain
     * @param name The domain name
     * @return The SVG string
     */
    function generateSVG(string memory name) public view returns (string memory) {
        // Determine font size based on name length
        uint256 fontSize = mainFontSize;
        if (bytes(name).length > 10) {
            fontSize = 32;
        } else if (bytes(name).length > 6) {
            fontSize = 36;
        }

        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" viewBox="0 0 500 500">',
                // Background
                '<rect width="500" height="500" fill="', backgroundColor, '" />',
                
                // Inner circle for depth
                '<circle cx="250" cy="250" r="', circleRadius.toString(), '" fill="', circleColor, '" />',
                
                // Accent circle
                '<circle cx="250" cy="250" r="', circleRadius.toString(), '" fill="none" stroke="', accentColor, '" stroke-width="2" />',
                
                // Hyperliquid logo - positioned in the upper part of the circle
                '<g transform="translate(210, 130) scale(0.55)">',
                '<path d="M144 71.6991C144 119.306 114.866 134.582 99.5156 120.98C86.8804 109.889 83.1211 86.4521 64.116 84.0456C39.9942 81.0113 37.9057 113.133 22.0334 113.133C3.5504 113.133 0 86.2428 0 72.4315C0 58.3063 3.96809 39.0542 19.736 39.0542C38.1146 39.0542 39.1588 66.5722 62.132 65.1073C85.0007 63.5379 85.4184 34.8689 100.247 22.6271C113.195 12.0593 144 23.4641 144 71.6991Z" fill="', logoColor, '"/>',
                '</g>',
                
                // Domain name - centered, with a clean font and good size
                '<text x="250" y="280" font-family="', fontFamily, '" font-weight="bold" font-size="', fontSize.toString(), 'px" fill="', textColor, '" text-anchor="middle">',
                name,
                '</text>',
                
                // .hype - slightly smaller, still elegant
                '<text x="250" y="320" font-family="', fontFamily, '" font-size="', secondaryFontSize.toString(), 'px" fill="', accentColor, '" text-anchor="middle">',
                '.hype',
                '</text>',
                
                // Service name at bottom - small and subtle
                '<text x="250" y="450" font-family="', fontFamily, '" font-size="12px" fill="', textColor, '" text-anchor="middle" opacity="0.6">',
                'Hype Name Service',
                '</text>',
                '</svg>'
            )
        );
    }

    /**
     * @dev Generates JSON metadata for a .hype domain
     * @param name The domain name
     * @param encodedSVG The base64 encoded SVG
     * @param tokenId The token ID
     * @return The JSON string
     */
    function generateJSON(
        string memory name,
        string memory encodedSVG,
        uint256 tokenId
    ) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"',
                name,
                '.hype",',
                '"description":"A .hype domain on the Hyperliquid network.",',
                '"image":"data:image/svg+xml;base64,',
                encodedSVG,
                '",',
                '"attributes":[',
                '{"trait_type":"Name","value":"',
                name,
                '"},',
                '{"trait_type":"Length","value":',
                uint256(bytes(name).length).toString(),
                '},',
                '{"trait_type":"Token ID","value":',
                tokenId.toString(),
                '}',
                ']}'
            )
        );
    }

    /**
     * @dev Updates the background color
     * @param _backgroundColor New background color in hex
     */
    function setBackgroundColor(string calldata _backgroundColor) external onlyOwner {
        backgroundColor = _backgroundColor;
    }

    /**
     * @dev Updates the text color
     * @param _textColor New text color in hex
     */
    function setTextColor(string calldata _textColor) external onlyOwner {
        textColor = _textColor;
    }

    /**
     * @dev Updates the accent color
     * @param _accentColor New accent color in hex
     */
    function setAccentColor(string calldata _accentColor) external onlyOwner {
        accentColor = _accentColor;
    }
    
    /**
     * @dev Updates the logo color
     * @param _logoColor New logo color in hex
     */
    function setLogoColor(string calldata _logoColor) external onlyOwner {
        logoColor = _logoColor;
    }
    
    /**
     * @dev Updates the circle color
     * @param _circleColor New circle color in hex
     */
    function setCircleColor(string calldata _circleColor) external onlyOwner {
        circleColor = _circleColor;
    }

    /**
     * @dev Updates the font sizes
     * @param _mainFontSize New main font size
     * @param _secondaryFontSize New secondary font size
     */
    function setFontSizes(uint256 _mainFontSize, uint256 _secondaryFontSize) external onlyOwner {
        mainFontSize = _mainFontSize;
        secondaryFontSize = _secondaryFontSize;
    }

    /**
     * @dev Updates the font family
     * @param _fontFamily New font family
     */
    function setFontFamily(string calldata _fontFamily) external onlyOwner {
        fontFamily = _fontFamily;
    }
    
    /**
     * @dev Updates the design settings
     * @param _logoSize New logo size
     * @param _circleRadius New circle radius
     */
    function setDesignSettings(uint256 _logoSize, uint256 _circleRadius) external onlyOwner {
        logoSize = _logoSize;
        circleRadius = _circleRadius;
    }
} 