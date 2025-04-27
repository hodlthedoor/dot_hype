// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../src/interfaces/IPriceOracle.sol";

/**
 * @title MockPriceOracle
 * @dev Mock oracle contract for testing USD to HYPE conversion
 */
contract MockPriceOracle is IPriceOracle {
    uint64 private rawPrice;
    uint256 constant SCALE = 1e6;

    constructor(uint64 _initialPrice) {
        rawPrice = _initialPrice;
    }

    /**
     * @dev Set a new raw price for testing
     */
    function setRawPrice(uint64 _newPrice) external {
        rawPrice = _newPrice;
    }

    /**
     * @dev Converts a USD amount to HYPE tokens using mocked price
     * @param usdAmount 18-decimal USD amount (e.g. 1e18 = $1)
     * @return hypeAmount 18-decimal HYPE amount
     */
    function usdToHype(uint256 usdAmount) external view override returns (uint256 hypeAmount) {
        // Same formula as the actual contract
        hypeAmount = (usdAmount * SCALE) / rawPrice;
    }

    /**
     * @dev Returns the mocked raw price
     */
    function getRawPrice() public view override returns (uint64 price) {
        return rawPrice;
    }
}
