// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IPriceOracle.sol";

/**
 * @title HypeOracle
 * @dev Oracle contract for converting USD amounts to HYPE using the Hyperliquid precompile
 */
contract HypeOracle is IPriceOracle {
    address constant PRECOMPILE = 0x0000000000000000000000000000000000000808; // Using 0x808 for spot prices
    uint32 constant PAIR_ID = 107;
    uint256 constant SCALE = 1e6; // 10^(8 − szDecimals)  (szDecimals = 2)

    /**
     * @dev Converts a USD amount to HYPE tokens
     * @param usdAmount 18-decimal USD amount (e.g. 1e18 = $1)
     * @return hypeAmount 18-decimal HYPE amount
     */
    function usdToHype(uint256 usdAmount) external view override returns (uint256 hypeAmount) {
        uint64 priceRaw = getRawPrice(); // uint64 spot price × 1e6
        hypeAmount = (usdAmount * SCALE) / priceRaw;
    }

    /**
     * @dev Gets the raw price from the precompile
     * @return price Raw price in the precompile format (scaled by 1e6)
     */
    function getRawPrice() public view override returns (uint64 price) {
        // Use standard abi.encode as used in hypercore-sim
        bytes memory data = abi.encode(PAIR_ID);
        (bool ok, bytes memory ret) = PRECOMPILE.staticcall(data);

        // Check if the call was successful
        require(ok, "SpotPx precompile call failed");

        // Use abi.decode to extract the uint64 value as done in hypercore-sim
        price = abi.decode(ret, (uint64));
    }
}
