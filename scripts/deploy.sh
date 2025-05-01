#!/bin/bash

# DotHype Interactive Deployment Script
# This script guides you through deploying the DotHype contracts to Hyperliquid

# Text styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display steps
step() {
    echo -e "${BOLD}${BLUE}Step $1:${NC} $2"
}

# Function to display success messages
success() {
    echo -e "${BOLD}${GREEN}Success:${NC} $1"
}

# Function to display warnings
warning() {
    echo -e "${BOLD}${YELLOW}Warning:${NC} $1"
}

# Function to display errors
error() {
    echo -e "${BOLD}${RED}Error:${NC} $1"
}

# Function to get user confirmation
confirm() {
    echo -e "${BOLD}${YELLOW}$1 [y/N]${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to set environment variable
set_env() {
    local var_name="$1"
    local var_value="$2"
    
    export "$var_name"="$var_value"
    # Also persist to a .env file for later use
    if [ -f .env ]; then
        if grep -q "^$var_name=" .env; then
            # Update existing variable
            sed -i.bak "s/^$var_name=.*/$var_name=$var_value/" .env && rm .env.bak
        else
            # Add new variable
            echo "$var_name=$var_value" >> .env
        fi
    else
        # Create new .env file
        echo "$var_name=$var_value" > .env
    fi
    
    success "Set $var_name=$var_value"
}

# Function to load environment variables
load_env() {
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
    fi
}

# Initialize
clear
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  DotHype Deployment for Hyperliquid  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo

# Load any existing environment variables
load_env

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "Enter your ${BOLD}private key${NC} (without 0x prefix):"
    read -r pk
    set_env "PRIVATE_KEY" "$pk"
fi

# Set RPC URL if not already set
if [ -z "$RPC_URL" ]; then
    set_env "RPC_URL" "https://rpc.hyperliquid-testnet.xyz/evm"
fi

# Optimize for deployment
warning "Using optimized compiler settings for minimal gas usage"
FORGE_PROFILE="--use hyperliquid-deploy"

# Step 1: Deploy Registry
step "1" "Deploy the DotHype Registry"
if [ -z "$REGISTRY_ADDRESS" ]; then
    if confirm "Ready to deploy the Registry?"; then
        echo "Deploying Registry..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployRegistry $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the registry address from the output
        registry_address=$(echo "$output" | grep -A1 "DotHypeRegistry deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$registry_address" ]; then
            set_env "REGISTRY_ADDRESS" "$registry_address"
        else
            error "Failed to extract Registry address. Please set it manually."
            echo "Enter Registry address:"
            read -r addr
            set_env "REGISTRY_ADDRESS" "$addr"
        fi
    else
        echo "Enter existing Registry address:"
        read -r addr
        set_env "REGISTRY_ADDRESS" "$addr"
    fi
else
    success "Registry already deployed at $REGISTRY_ADDRESS"
    if confirm "Deploy a new Registry instead?"; then
        echo "Deploying new Registry..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployRegistry $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the registry address from the output
        registry_address=$(echo "$output" | grep -A1 "DotHypeRegistry deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$registry_address" ]; then
            set_env "REGISTRY_ADDRESS" "$registry_address"
        fi
    fi
fi

# Step 2: Deploy MockOracle
step "2" "Deploy the MockOracle (fixed pricing)"
if [ -z "$MOCK_ORACLE_ADDRESS" ]; then
    if confirm "Ready to deploy the MockOracle?"; then
        echo "Deploying MockOracle..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployMockOracle $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the oracle address from the output
        oracle_address=$(echo "$output" | grep -A1 "MockOracle deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$oracle_address" ]; then
            set_env "MOCK_ORACLE_ADDRESS" "$oracle_address"
        else
            error "Failed to extract MockOracle address. Please set it manually."
            echo "Enter MockOracle address:"
            read -r addr
            set_env "MOCK_ORACLE_ADDRESS" "$addr"
        fi
    else
        echo "Enter existing MockOracle address:"
        read -r addr
        set_env "MOCK_ORACLE_ADDRESS" "$addr"
    fi
else
    success "MockOracle already deployed at $MOCK_ORACLE_ADDRESS"
    if confirm "Deploy a new MockOracle instead?"; then
        echo "Deploying new MockOracle..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployMockOracle $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the oracle address from the output
        oracle_address=$(echo "$output" | grep -A1 "MockOracle deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$oracle_address" ]; then
            set_env "MOCK_ORACLE_ADDRESS" "$oracle_address"
        fi
    fi
fi

# Step 3: Deploy HypeOracle
step "3" "Deploy the HypeOracle (Hyperliquid pricing)"
if [ -z "$HYPE_ORACLE_ADDRESS" ]; then
    if confirm "Ready to deploy the HypeOracle?"; then
        echo "Deploying HypeOracle..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployHypeOracle $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the oracle address from the output
        oracle_address=$(echo "$output" | grep -A1 "HypeOracle deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$oracle_address" ]; then
            set_env "HYPE_ORACLE_ADDRESS" "$oracle_address"
        else
            error "Failed to extract HypeOracle address. Please set it manually."
            echo "Enter HypeOracle address:"
            read -r addr
            set_env "HYPE_ORACLE_ADDRESS" "$addr"
        fi
    else
        echo "Enter existing HypeOracle address:"
        read -r addr
        set_env "HYPE_ORACLE_ADDRESS" "$addr"
    fi
else
    success "HypeOracle already deployed at $HYPE_ORACLE_ADDRESS"
    if confirm "Deploy a new HypeOracle instead?"; then
        echo "Deploying new HypeOracle..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployHypeOracle $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the oracle address from the output
        oracle_address=$(echo "$output" | grep -A1 "HypeOracle deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$oracle_address" ]; then
            set_env "HYPE_ORACLE_ADDRESS" "$oracle_address"
        fi
    fi
fi

# Step 4: Deploy Controller
step "4" "Deploy the DotHype Controller"
if [ -z "$CONTROLLER_ADDRESS" ]; then
    if confirm "Ready to deploy the Controller using the MockOracle?"; then
        echo "Deploying Controller..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployController $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the controller address from the output
        controller_address=$(echo "$output" | grep -A1 "Controller deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$controller_address" ]; then
            set_env "CONTROLLER_ADDRESS" "$controller_address"
        else
            error "Failed to extract Controller address. Please set it manually."
            echo "Enter Controller address:"
            read -r addr
            set_env "CONTROLLER_ADDRESS" "$addr"
        fi
    else
        echo "Enter existing Controller address:"
        read -r addr
        set_env "CONTROLLER_ADDRESS" "$addr"
    fi
else
    success "Controller already deployed at $CONTROLLER_ADDRESS"
    if confirm "Deploy a new Controller instead?"; then
        echo "Deploying new Controller..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployController $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the controller address from the output
        controller_address=$(echo "$output" | grep -A1 "Controller deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$controller_address" ]; then
            set_env "CONTROLLER_ADDRESS" "$controller_address"
        fi
    fi
fi

# Step 5: Deploy Resolver
step "5" "Deploy the DotHype Resolver"
if [ -z "$RESOLVER_ADDRESS" ]; then
    if confirm "Ready to deploy the Resolver?"; then
        echo "Deploying Resolver..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployResolver $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the resolver address from the output
        resolver_address=$(echo "$output" | grep -A1 "Resolver deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$resolver_address" ]; then
            set_env "RESOLVER_ADDRESS" "$resolver_address"
        else
            error "Failed to extract Resolver address. Please set it manually."
            echo "Enter Resolver address:"
            read -r addr
            set_env "RESOLVER_ADDRESS" "$addr"
        fi
    else
        echo "Enter existing Resolver address:"
        read -r addr
        set_env "RESOLVER_ADDRESS" "$addr"
    fi
else
    success "Resolver already deployed at $RESOLVER_ADDRESS"
    if confirm "Deploy a new Resolver instead?"; then
        echo "Deploying new Resolver..."
        output=$(forge script script/MinimalDeploy.s.sol:MinimalDeployResolver $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
        echo "$output"
        
        # Extract the resolver address from the output
        resolver_address=$(echo "$output" | grep -A1 "Resolver deployed at:" | tail -n1 | tr -d '[:space:]')
        
        if [ -n "$resolver_address" ]; then
            set_env "RESOLVER_ADDRESS" "$resolver_address"
        fi
    fi
fi

# Step 6: Set Controller in Registry
step "6" "Set Controller in Registry"
if confirm "Ready to set the Controller in the Registry?"; then
    echo "Setting Controller..."
    output=$(forge script script/MinimalDeploy.s.sol:SetController $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
    echo "$output"
    success "Controller set in Registry"
fi

# Step 7: Configure Pricing
step "7" "Configure Pricing"
if confirm "Ready to configure pricing in the Controller?"; then
    echo "Setting pricing..."
    output=$(forge script script/MinimalDeploy.s.sol:SetPricing $FORGE_PROFILE --rpc-url $RPC_URL --broadcast 2>&1)
    echo "$output"
    success "Pricing configured"
fi

# Deployment Summary
echo
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  Deployment Summary  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo
echo -e "${BOLD}Registry:${NC}    $REGISTRY_ADDRESS"
echo -e "${BOLD}Controller:${NC}  $CONTROLLER_ADDRESS"
echo -e "${BOLD}Resolver:${NC}    $RESOLVER_ADDRESS"
echo -e "${BOLD}MockOracle:${NC}  $MOCK_ORACLE_ADDRESS"
echo -e "${BOLD}HypeOracle:${NC}  $HYPE_ORACLE_ADDRESS"
echo
echo -e "${BOLD}${GREEN}Deployment completed successfully!${NC}"
echo
echo -e "To switch from MockOracle to HypeOracle later, run:"
echo -e "${BOLD}forge script script/SwitchToHypeOracle.s.sol --rpc-url \$RPC_URL --broadcast${NC}"
echo

# Make the script executable
chmod +x scripts/deploy.sh 