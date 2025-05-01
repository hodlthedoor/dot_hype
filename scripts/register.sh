#!/bin/bash

# DotHype Domain Registration Script
# This script registers a .hype domain name

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
if [ -z "$CONTROLLER_ADDRESS" ]; then
    echo -e "${BOLD}${RED}Error:${NC} Missing CONTROLLER_ADDRESS in .env file. Please run deployment script first."
    exit 1
fi

# RPC URL
if [ -z "$RPC_URL" ]; then
    RPC_URL="https://rpc.hyperliquid-testnet.xyz/evm"
fi

# Function to display success messages
success() {
    echo -e "${BOLD}${GREEN}Success:${NC} $1"
}

# Function to display errors
error() {
    echo -e "${BOLD}${RED}Error:${NC} $1"
}

# Check for domain name argument
if [ $# -lt 1 ]; then
    echo -e "${BOLD}Usage:${NC} $0 <domain_name> [duration_days]"
    echo
    echo -e "Example:"
    echo -e "  $0 mydomain 365"
    exit 1
fi

DOMAIN_NAME=$1

# Check for duration argument
if [ $# -ge 2 ]; then
    DURATION_DAYS=$2
else
    DURATION_DAYS=365
fi

echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  DotHype Domain Registration  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo
echo -e "Registering ${BOLD}${DOMAIN_NAME}.hype${NC} for ${BOLD}${DURATION_DAYS} days${NC}"
echo

# Set environment variables for the script
export DOMAIN_NAME=$DOMAIN_NAME
export DURATION_DAYS=$DURATION_DAYS

# Run the forge script
forge script script/RegisterDomain.s.sol --rpc-url $RPC_URL --broadcast

echo
echo -e "${BOLD}${GREEN}Registration process complete!${NC}"
echo -e "You can check your domain at: https://explorer.hyperliquid.xyz/address/$CONTROLLER_ADDRESS"

# Make the script executable
chmod +x scripts/register.sh 