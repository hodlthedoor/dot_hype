#!/bin/bash

# DotHype Contract Verification Script
# This script verifies all deployed contracts on Hyperliquid via Sourcify

# Text styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${BOLD}${RED}Error:${NC} .env file not found. Please run the deployment script first."
    exit 1
fi

# Check required environment variables
if [ -z "$REGISTRY_ADDRESS" ] || [ -z "$CONTROLLER_ADDRESS" ] || [ -z "$RESOLVER_ADDRESS" ] || [ -z "$MOCK_ORACLE_ADDRESS" ] || [ -z "$HYPE_ORACLE_ADDRESS" ]; then
    echo -e "${BOLD}${RED}Error:${NC} Missing contract addresses in .env file. Please run deployment script first."
    exit 1
fi

echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  DotHype Contract Verification  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo

# Verify Registry
echo -e "${BOLD}${BLUE}Verifying Registry at ${REGISTRY_ADDRESS}${NC}"
forge verify-contract --chain hyperliquid-testnet $REGISTRY_ADDRESS src/core/DotHypeRegistry.sol:DotHypeRegistry
echo

# Verify Controller
echo -e "${BOLD}${BLUE}Verifying Controller at ${CONTROLLER_ADDRESS}${NC}"
forge verify-contract --chain hyperliquid-testnet $CONTROLLER_ADDRESS src/core/DotHypeController.sol:DotHypeController
echo

# Verify Resolver
echo -e "${BOLD}${BLUE}Verifying Resolver at ${RESOLVER_ADDRESS}${NC}"
forge verify-contract --chain hyperliquid-testnet $RESOLVER_ADDRESS src/core/DotHypeResolver.sol:DotHypeResolver
echo

# Verify MockOracle
echo -e "${BOLD}${BLUE}Verifying MockOracle at ${MOCK_ORACLE_ADDRESS}${NC}"
forge verify-contract --chain hyperliquid-testnet $MOCK_ORACLE_ADDRESS script/MinimalDeploy.s.sol:MockOracle
echo

# Verify HypeOracle
echo -e "${BOLD}${BLUE}Verifying HypeOracle at ${HYPE_ORACLE_ADDRESS}${NC}"
forge verify-contract --chain hyperliquid-testnet $HYPE_ORACLE_ADDRESS src/core/HypeOracle.sol:HypeOracle
echo

echo -e "${BOLD}${GREEN}Contract verification complete!${NC}"

# Make the script executable
chmod +x scripts/verify.sh 