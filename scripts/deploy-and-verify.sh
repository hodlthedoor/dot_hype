#!/bin/bash

# Exit if any command fails
set -e

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: PRIVATE_KEY environment variable not set"
  echo "Please set it with: export PRIVATE_KEY=your_private_key_here"
  exit 1
fi

# Define network
NETWORK="hyperliquid-testnet"
CHAIN_ID=998

echo "=== Deploying TestContract ==="
echo ""

# Method 1: Using Forge Script
echo "Method 1: Using Forge Script"
forge script script/DeployTestContract.s.sol --network $NETWORK --broadcast --verify

echo ""
echo "=== Alternative Method ==="
echo ""

# Method 2: Using Forge Create
echo "Method 2: Using Forge Create directly"
echo "Running: forge create --network $NETWORK src/test/TestContract.sol:TestContract --constructor-args \"Hello, Hyperliquid!\" 42 --verify"
CONTRACT_ADDRESS=$(forge create --network $NETWORK \
  src/test/TestContract.sol:TestContract \
  --constructor-args "Hello, Hyperliquid!" 42 \
  --private-key $PRIVATE_KEY \
  --verify \
  | grep "Deployed to:" | awk '{print $3}')

# The forge create with --verify should handle verification automatically,
# but in case it doesn't, or you want to verify later:
echo ""
echo "If verification failed, you can run this command manually:"
echo "forge verify-contract $CONTRACT_ADDRESS src/test/TestContract.sol:TestContract \\"
echo "--constructor-args \$(cast abi-encode \"constructor(string,uint256)\" \"Hello, Hyperliquid!\" 42) \\"
echo "--network $NETWORK --verifier sourcify"

echo ""
echo "=== Deployment Complete ==="
echo "Contract address: $CONTRACT_ADDRESS" 