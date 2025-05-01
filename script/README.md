# DotHype Deployment Scripts

This directory contains scripts for deploying and managing the DotHype domain service on Hyperliquid.

## Key Issues & Solutions

The Hyperliquid chain has a block gas limit that can be exceeded when trying to deploy multiple contracts and run multiple transactions in a single script. To resolve this, we've created two deployment approaches:

1. **Multi-Contract Script with Transaction Batching** (`DeployAndSetupDotHype.s.sol`)
2. **Step-by-Step Deployment Scripts** (`DeployForHyperliquid.s.sol`)

## Step-by-Step Deployment (Recommended)

This approach divides the deployment process into separate steps, each in its own transaction. This ensures we stay within gas limits.

### Deployment Steps

```bash
# 1. Deploy both oracles (MockOracle and HypeOracle)
forge script script/DeployForHyperliquid.s.sol:DeployOracles --broadcast

# 2. Deploy the Registry
forge script script/DeployForHyperliquid.s.sol:DeployRegistry --broadcast

# 3. Deploy the Controller and configure pricing
forge script script/DeployForHyperliquid.s.sol:DeployController --broadcast

# 4. Deploy the Resolver
forge script script/DeployForHyperliquid.s.sol:DeployResolver --broadcast

# 5. Reserve test domains
forge script script/DeployForHyperliquid.s.sol:ReserveTestDomains --broadcast
```

This approach will:

- Save contract addresses to a JSON file between steps
- Only deploy contracts that haven't been deployed yet
- Provide clear next steps after each stage

## Working with Deployed Contracts

After deployment, you'll need to set environment variables for other scripts to work:

```bash
export REGISTRY_ADDRESS=0x...
export CONTROLLER_ADDRESS=0x...
export RESOLVER_ADDRESS=0x...
export MOCK_ORACLE_ADDRESS=0x...
export HYPE_ORACLE_ADDRESS=0x...
```

These values will be output at the end of the deployment process.

## Utility Scripts

### Register Reserved Names

Registers domain names that have been reserved for your address:

```bash
forge script script/RegisterReservedNames.s.sol --broadcast
```

### Check Registered Domains

View all domains registered to specific addresses:

```bash
forge script script/CheckDomains.s.sol
```

### Switch Oracle

Switch from MockOracle to the real HypeOracle:

```bash
forge script script/SwitchToHypeOracle.s.sol --broadcast
```

### Test HypeOracle

Test the functionality of the real HypeOracle:

```bash
forge script script/TestHypeOracle.s.sol
```

## Oracle Usage

The deployment initially configures the system to use MockOracle with a fixed conversion rate (1 HYPE = $5000). This allows you to test and use the system immediately.

When you're ready to switch to the real HypeOracle (which uses the Hyperliquid precompile), run the SwitchToHypeOracle script.

## Test Domains

The deployment reserves test domains (test1 through test10) as follows:

- Odd-numbered domains (test1, test3, etc.) for `0xc2AbE12785B69349b9C85F9b6812D8894C8AB945`
- Even-numbered domains (test2, test4, etc.) for your deployer address

Only the owner of a reserved name can register it using the `registerReserved` function.
