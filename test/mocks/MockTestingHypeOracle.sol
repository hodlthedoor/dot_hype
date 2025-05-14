// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../src/interfaces/IPriceOracle.sol";

/**
 * @title MockTestingHypeOracle
 * @dev Mock oracle contract for testing USD to token conversion with different pair IDs
 *      Used for environments where the Hyperliquid precompile is not available
 */
contract MockTestingHypeOracle is IPriceOracle {
    uint256 constant SCALE = 1e6; // 10^(8 − szDecimals) (szDecimals = 2)
    
    // Default pair ID (usually HYPE = 107)
    uint32 private defaultPairId;
    
    // Mapping to store mock prices for different pair IDs
    mapping(uint32 => uint64) private pairPrices;
    
    constructor(uint32 _defaultPairId, uint64 _defaultPrice) {
        defaultPairId = _defaultPairId;
        pairPrices[_defaultPairId] = _defaultPrice;
    }
    
    /**
     * @dev Set a new default pair ID
     * @param _newPairId New default pair ID to use
     */
    function setDefaultPairId(uint32 _newPairId) external {
        defaultPairId = _newPairId;
    }
    
    /**
     * @dev Set a price for a specific pair ID
     * @param pairId Pair ID to set price for
     * @param price Price value to set (scaled by 1e6)
     */
    function setPairPrice(uint32 pairId, uint64 price) external {
        pairPrices[pairId] = price;
    }
    
    /**
     * @dev Set prices for multiple pair IDs in a single transaction
     * @param pairIds Array of pair IDs to set prices for
     * @param prices Array of price values (scaled by 1e6)
     */
    function setBulkPairPrices(uint32[] calldata pairIds, uint64[] calldata prices) external {
        require(pairIds.length == prices.length, "Array lengths must match");
        
        for (uint256 i = 0; i < pairIds.length; i++) {
            pairPrices[pairIds[i]] = prices[i];
        }
    }

    /**
     * @dev Converts a USD amount to tokens using the default pair ID
     * @param usdAmount 18-decimal USD amount (e.g. 1e18 = $1)
     * @return tokenAmount 18-decimal token amount
     */
    function usdToHype(uint256 usdAmount) external view override returns (uint256 tokenAmount) {
        return usdToToken(usdAmount, defaultPairId);
    }

    /**
     * @dev Converts a USD amount to tokens using a specific pair ID
     * @param usdAmount 18-decimal USD amount (e.g. 1e18 = $1)
     * @param pairId Pair ID to use for price lookup
     * @return tokenAmount 18-decimal token amount
     */
    function usdToToken(uint256 usdAmount, uint32 pairId) public view returns (uint256 tokenAmount) {
        uint64 priceRaw = getRawPriceForPair(pairId);
        tokenAmount = (usdAmount * SCALE) / priceRaw;
    }

    /**
     * @dev Gets the raw price for the default pair ID
     * @return price Raw price in the precompile format (scaled by 1e6)
     */
    function getRawPrice() public view override returns (uint64 price) {
        return getRawPriceForPair(defaultPairId);
    }

    /**
     * @dev Gets the raw price for a specific pair ID
     * @param pairId Pair ID to get price for
     * @return price Raw price in the mock format (scaled by 1e6)
     */
    function getRawPriceForPair(uint32 pairId) public view returns (uint64 price) {
        price = pairPrices[pairId];
        require(price != 0, "Price not set for this pair ID");
        return price;
    }
} 