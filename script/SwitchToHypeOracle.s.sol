// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/core/DotHypeController.sol";
import "../src/interfaces/IPriceOracle.sol";

/**
 * @title SwitchToHypeOracle
 * @dev Switches the DotHypeController from using MockOracle to HypeOracle
 */
contract SwitchToHypeOracle is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        address hypeOracleAddress = vm.envAddress("HYPE_ORACLE_ADDRESS");

        console.log("Switching oracle to HypeOracle at", hypeOracleAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Get controller reference
        DotHypeController controller = DotHypeController(payable(controllerAddress));

        // Switch to HypeOracle
        controller.setPriceOracle(hypeOracleAddress);

        // Test the oracle
        IPriceOracle oracle = IPriceOracle(hypeOracleAddress);
        try oracle.getRawPrice() returns (uint64 rawPrice) {
            console.log("HypeOracle price (raw):", rawPrice);

            // Test USD to HYPE conversion (for $100)
            uint256 usdAmount = 100 * 1e18; // $100 in 18 decimals
            uint256 hypeAmount = oracle.usdToHype(usdAmount);
            console.log("$100 USD = ", hypeAmount / 1e18, "HYPE");
        } catch {
            console.log("Warning: Could not read price from HypeOracle!");
        }

        console.log("Controller now using HypeOracle at:", hypeOracleAddress);

        vm.stopBroadcast();
    }
}
