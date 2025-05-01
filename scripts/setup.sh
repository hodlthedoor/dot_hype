#!/bin/bash

# DotHype Setup Script
# This script sets up the environment for DotHype deployment and usage

# Text styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  DotHype Environment Setup  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo

# Make all scripts executable
echo -e "${BOLD}${BLUE}Making scripts executable...${NC}"
chmod +x scripts/*.sh
echo -e "${GREEN}Done${NC}"
echo

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo -e "${BOLD}${RED}Error:${NC} Foundry is not installed or not in PATH"
    echo -e "Please install Foundry: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# Update Foundry
echo -e "${BOLD}${BLUE}Updating Foundry...${NC}"
foundryup
echo

# Install dependencies
echo -e "${BOLD}${BLUE}Installing dependencies...${NC}"
forge install
echo

# Build project
echo -e "${BOLD}${BLUE}Building project...${NC}"
forge build --use hyperliquid-deploy
echo

echo -e "${BOLD}${GREEN}Setup complete!${NC}"
echo
echo -e "Available scripts:"
echo -e "  ${BOLD}./scripts/deploy.sh${NC} - Interactive deployment"
echo -e "  ${BOLD}./scripts/verify.sh${NC} - Verify contracts"
echo -e "  ${BOLD}./scripts/register.sh${NC} - Register a domain"
echo -e "  ${BOLD}./scripts/lookup.sh${NC} - Look up domain information"
echo

# Make this script executable
chmod +x scripts/setup.sh 