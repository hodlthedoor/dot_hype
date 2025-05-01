# DotHype Deployment Guide for Hyperliquid

This guide outlines the steps to deploy the DotHype domain name system to the Hyperliquid blockchain.

## Prerequisites

1. Set up your environment variables:
   ```bash
   export PRIVATE_KEY=your_private_key
   export RPC_URL=https://rpc.hyperliquid-testnet.xyz/evm
   ```

## Step-by-Step Deployment

### 1. Deploy the Registry

```bash
forge script script/MinimalDeploy.s.sol:MinimalDeployRegistry --rpc-url $RPC_URL --broadcast --verify
```

After deployment, set the registry address in your environment:

```bash
export REGISTRY_ADDRESS=<deployed_registry_address>
```

### 2. Deploy the MockOracle (for fixed pricing)

```bash
forge script script/MinimalDeploy.s.sol:MinimalDeployMockOracle --rpc-url $RPC_URL --broadcast --verify
```

Set the MockOracle address:

```bash
export MOCK_ORACLE_ADDRESS=<deployed_mock_oracle_address>
```

### 3. Deploy the HypeOracle (for Hyperliquid pricing)

```bash
forge script script/MinimalDeploy.s.sol:MinimalDeployHypeOracle --rpc-url $RPC_URL --broadcast --verify
```

Set the HypeOracle address:

```bash
export HYPE_ORACLE_ADDRESS=<deployed_hype_oracle_address>
```

### 4. Deploy the Controller (using the MockOracle initially)

```bash
forge script script/MinimalDeploy.s.sol:MinimalDeployController --rpc-url $RPC_URL --broadcast --verify
```

Set the Controller address:

```bash
export CONTROLLER_ADDRESS=<deployed_controller_address>
```

### 5. Deploy the Resolver

```bash
forge script script/MinimalDeploy.s.sol:MinimalDeployResolver --rpc-url $RPC_URL --broadcast --verify
```

Set the Resolver address:

```bash
export RESOLVER_ADDRESS=<deployed_resolver_address>
```

### 6. Set the Controller in the Registry

```bash
forge script script/MinimalDeploy.s.sol:SetController --rpc-url $RPC_URL --broadcast
```

### 7. Configure Pricing in the Controller

```bash
forge script script/MinimalDeploy.s.sol:SetPricing --rpc-url $RPC_URL --broadcast
```

## Switching Oracles (Optional)

To switch from the MockOracle to the HypeOracle later:

1. Create a new script:

```solidity
// SwitchToHypeOracle.s.sol
contract SwitchToHypeOracle is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        address hypeOracleAddress = vm.envAddress("HYPE_ORACLE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        DotHypeController controller = DotHypeController(payable(controllerAddress));
        controller.setPriceOracle(hypeOracleAddress);
        console.log("Controller now using HypeOracle at:", hypeOracleAddress);
        vm.stopBroadcast();
    }
}
```

2. Run the script:

```bash
forge script script/SwitchToHypeOracle.s.sol --rpc-url $RPC_URL --broadcast
```

## Troubleshooting

### Gas Limit Issues

If you encounter "exceeds block gas limit" errors:

1. Try increasing the gas limit in your forge script command:

   ```bash
   forge script script/MinimalDeploy.s.sol:MinimalDeployRegistry --rpc-url $RPC_URL --broadcast --gas-limit 10000000
   ```

2. If that doesn't work, try lowering the `optimizer_runs` setting in foundry.toml temporarily for deployment.

### Contract Verification

For verification on Hyperliquid via Sourcify:

```bash
forge verify-contract --chain hyperliquid-testnet <CONTRACT_ADDRESS> <CONTRACT_NAME>
```
