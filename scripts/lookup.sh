#!/bin/bash

# DotHype Domain Lookup Script
# This script looks up information about a .hype domain name

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
if [ -z "$REGISTRY_ADDRESS" ] || [ -z "$RESOLVER_ADDRESS" ]; then
    echo -e "${BOLD}${RED}Error:${NC} Missing contract addresses in .env file. Please run deployment script first."
    exit 1
fi

# RPC URL
if [ -z "$RPC_URL" ]; then
    RPC_URL="https://rpc.hyperliquid-testnet.xyz/evm"
fi

# Check for domain name argument
if [ $# -lt 1 ]; then
    echo -e "${BOLD}Usage:${NC} $0 <domain_name>"
    echo
    echo -e "Example:"
    echo -e "  $0 mydomain"
    exit 1
fi

DOMAIN_NAME=$1

echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  DotHype Domain Lookup  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo
echo -e "Looking up ${BOLD}${DOMAIN_NAME}.hype${NC}"
echo

# Set environment variables for the script
export DOMAIN_NAME=$DOMAIN_NAME

# Run the forge script
forge script script/LookupDomain.s.sol --rpc-url $RPC_URL

# Make the script executable
chmod +x scripts/lookup.sh 