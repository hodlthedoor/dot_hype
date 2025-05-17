// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../src/interfaces/IPriceOracle.sol";

/**
 * @title TestingHypeOracle
 * @dev Testing oracle contract for converting USD amounts to HYPE using the Hyperliquid precompile
 *      Allows specifying pair ID in function calls
 */
contract TestingHypeOracle is IPriceOracle {
    address constant PRECOMPILE = 0x0000000000000000000000000000000000000808; // Using 0x808 for spot prices
    uint256 constant SCALE = 1e6; // 10^(8 − szDecimals) (szDecimals = 2)

    // Default pair ID (HYPE = 107)
    uint32 private defaultPairId;

    constructor(uint32 _defaultPairId) {
        defaultPairId = _defaultPairId;
    }

    /**
     * @dev Set a new default pair ID
     * @param _newPairId New default pair ID to use
     */
    function setDefaultPairId(uint32 _newPairId) external {
        defaultPairId = _newPairId;
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
        uint64 priceRaw = getRawPriceForPair(pairId); // uint64 spot price × 1e6
        tokenAmount = (usdAmount * SCALE) / priceRaw;
    }

    /**
     * @dev Gets the raw price from the precompile using the default pair ID
     * @return price Raw price in the precompile format (scaled by 1e6)
     */
    function getRawPrice() public view override returns (uint64 price) {
        return getRawPriceForPair(defaultPairId);
    }

    /**
     * @dev Gets the raw price from the precompile for a specific pair ID
     * @param pairId Pair ID to get price for
     * @return price Raw price in the precompile format (scaled by 1e6)
     */
    function getRawPriceForPair(uint32 pairId) public view returns (uint64 price) {
        // Use standard abi.encode as used in hypercore-sim
        bytes memory data = abi.encode(pairId);
        (bool ok, bytes memory ret) = PRECOMPILE.staticcall(data);

        // Check if the call was successful
        require(ok, "SpotPx precompile call failed");

        // Use abi.decode to extract the uint64 value as done in hypercore-sim
        price = abi.decode(ret, (uint64));
    }
}
