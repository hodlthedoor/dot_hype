// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IPriceOracle
 * @dev Interface for Hyperliquid price oracle functions
 */
interface IPriceOracle {
    /**
     * @dev Converts a USD amount to HYPE tokens
     * @param usdAmount 18-decimal USD amount (e.g. 1e18 = $1)
     * @return hypeAmount 18-decimal HYPE amount
     */
    function usdToHype(uint256 usdAmount) external view returns (uint256 hypeAmount);

    /**
     * @dev Gets the raw HYPE/USD price from the precompile
     * @return price Raw price in the precompile format (scaled by 1e6)
     */
    function getRawPrice() external view returns (uint64 price);
}
