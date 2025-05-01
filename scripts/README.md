# Deployment and Verification Testing

This directory contains scripts to test the deployment and verification of contracts on Hyperliquid.

## Prerequisites

- Ensure you have Foundry installed
- Set your private key as an environment variable:
  ```
  export PRIVATE_KEY=your_private_key_here
  ```
- Make sure you have ETH/HYPE on the account for transaction fees

## Deployment Methods

### Method 1: Using the Shell Script

This is the simplest approach that handles everything for you:

```bash
# Make the script executable
chmod +x scripts/deploy-and-verify.sh

# Run the script
./scripts/deploy-and-verify.sh
```

### Method 2: Using Forge Script

```bash
forge script script/DeployTestContract.s.sol --network hyperliquid-testnet --broadcast --verify
```

### Method 3: Direct Forge Create

```bash
forge create --network hyperliquid-testnet \
  src/test/TestContract.sol:TestContract \
  --constructor-args "Hello, Hyperliquid!" 42 \
  --private-key $PRIVATE_KEY \
  --verify
```

## Manual Verification

If automatic verification fails, you can manually verify the contract:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/test/TestContract.sol:TestContract \
  --constructor-args $(cast abi-encode "constructor(string,uint256)" "Hello, Hyperliquid!" 42) \
  --network hyperliquid-testnet \
  --verifier sourcify
```

## Testing Other Contracts

To test deployment and verification of other contracts:

1. Update the deployment script with your contract and constructor arguments
2. Update the verification commands with the correct contract path and arguments

## Troubleshooting

- If verification fails, check if the Sourcify service is available
- Ensure the correct constructor arguments are provided
- Make sure your foundry.toml has the correct verification settings
- Check that the network configuration in foundry.toml is correct
