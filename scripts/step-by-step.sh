#!/bin/bash

# DotHype Step-by-Step Deployment
# This script guides you through the step-by-step deployment of DotHype

# Text styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${BOLD}${RED}Error:${NC} .env file not found."
    exit 1
fi

# Check for RPC_URL
if [ -z "$RPC_URL" ]; then
    RPC_URL="https://rpc.hyperliquid-testnet.xyz/evm"
    echo -e "${BOLD}${BLUE}Using default RPC URL:${NC} $RPC_URL"
fi

# Common script arguments
SCRIPT_ARGS="--rpc-url $RPC_URL --chain-id 998 --verify --verifier sourcify --broadcast -vvv"

# Function to display steps
step() {
    echo -e "${BOLD}${BLUE}Step $1:${NC} $2"
}

# Function to display success messages
success() {
    echo -e "${BOLD}${GREEN}Success:${NC} $1"
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

# Clear screen and show welcome
clear
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  DotHype Step-by-Step Deployment  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo

# Check for registry and oracle addresses
if [ -z "$REGISTRY_ADDRESS" ] || [ -z "$MOCK_ORACLE_ADDRESS" ]; then
    echo -e "${BOLD}${RED}Error:${NC} REGISTRY_ADDRESS and MOCK_ORACLE_ADDRESS must be set in your .env file."
    echo "Current values:"
    echo "REGISTRY_ADDRESS=$REGISTRY_ADDRESS"
    echo "MOCK_ORACLE_ADDRESS=$MOCK_ORACLE_ADDRESS"
    
    if confirm "Would you like to update them now?"; then
        node scripts/update-env.js
        # Reload env after update
        source .env
    else
        exit 1
    fi
fi

# Display existing addresses
echo -e "${BOLD}Current Contract Addresses:${NC}"
echo "REGISTRY_ADDRESS=$REGISTRY_ADDRESS"
echo "MOCK_ORACLE_ADDRESS=$MOCK_ORACLE_ADDRESS"
echo "CONTROLLER_ADDRESS=$CONTROLLER_ADDRESS"
echo "METADATA_ADDRESS=$METADATA_ADDRESS"
echo "RESOLVER_ADDRESS=$RESOLVER_ADDRESS"
echo

# Step 1: Deploy Controller
step "1" "Deploy Controller"
if [ -z "$CONTROLLER_ADDRESS" ]; then
    if confirm "Ready to deploy the Controller?"; then
        forge script script/StepByStepSetup.s.sol:DeployController $SCRIPT_ARGS
        
        echo -e "${BOLD}Enter the deployed Controller address:${NC}"
        read -r controller_address
        export CONTROLLER_ADDRESS=$controller_address
        
        # Update .env
        if [ -f .env ]; then
            if grep -q "^CONTROLLER_ADDRESS=" .env; then
                sed -i.bak "s/^CONTROLLER_ADDRESS=.*/CONTROLLER_ADDRESS=$controller_address/" .env && rm .env.bak
            else
                echo "CONTROLLER_ADDRESS=$controller_address" >> .env
            fi
        else
            echo "CONTROLLER_ADDRESS=$controller_address" > .env
        fi
        
        success "Controller address set to $controller_address"
    else
        echo -e "${BOLD}${YELLOW}Skipping Controller deployment${NC}"
    fi
else
    success "Controller already deployed at $CONTROLLER_ADDRESS"
    
    if confirm "Deploy a new Controller instead?"; then
        forge script script/StepByStepSetup.s.sol:DeployController $SCRIPT_ARGS
        
        echo -e "${BOLD}Enter the new Controller address:${NC}"
        read -r controller_address
        export CONTROLLER_ADDRESS=$controller_address
        
        # Update .env
        if [ -f .env ]; then
            sed -i.bak "s/^CONTROLLER_ADDRESS=.*/CONTROLLER_ADDRESS=$controller_address/" .env && rm .env.bak
        fi
        
        success "Controller address updated to $controller_address"
    fi
fi
echo

# Step 2: Deploy Metadata
step "2" "Deploy Metadata"
if [ -z "$METADATA_ADDRESS" ]; then
    if confirm "Ready to deploy the Metadata contract?"; then
        forge script script/StepByStepSetup.s.sol:DeployMetadata $SCRIPT_ARGS
        
        echo -e "${BOLD}Enter the deployed Metadata address:${NC}"
        read -r metadata_address
        export METADATA_ADDRESS=$metadata_address
        
        # Update .env
        if [ -f .env ]; then
            if grep -q "^METADATA_ADDRESS=" .env; then
                sed -i.bak "s/^METADATA_ADDRESS=.*/METADATA_ADDRESS=$metadata_address/" .env && rm .env.bak
            else
                echo "METADATA_ADDRESS=$metadata_address" >> .env
            fi
        else
            echo "METADATA_ADDRESS=$metadata_address" > .env
        fi
        
        success "Metadata address set to $metadata_address"
    else
        echo -e "${BOLD}${YELLOW}Skipping Metadata deployment${NC}"
    fi
else
    success "Metadata already deployed at $METADATA_ADDRESS"
    
    if confirm "Deploy a new Metadata contract instead?"; then
        forge script script/StepByStepSetup.s.sol:DeployMetadata $SCRIPT_ARGS
        
        echo -e "${BOLD}Enter the new Metadata address:${NC}"
        read -r metadata_address
        export METADATA_ADDRESS=$metadata_address
        
        # Update .env
        if [ -f .env ]; then
            sed -i.bak "s/^METADATA_ADDRESS=.*/METADATA_ADDRESS=$metadata_address/" .env && rm .env.bak
        fi
        
        success "Metadata address updated to $metadata_address"
    fi
fi
echo

# Step 3: Deploy Resolver
step "3" "Deploy Resolver"
if [ -z "$RESOLVER_ADDRESS" ]; then
    if confirm "Ready to deploy the Resolver?"; then
        forge script script/StepByStepSetup.s.sol:DeployResolver $SCRIPT_ARGS
        
        echo -e "${BOLD}Enter the deployed Resolver address:${NC}"
        read -r resolver_address
        export RESOLVER_ADDRESS=$resolver_address
        
        # Update .env
        if [ -f .env ]; then
            if grep -q "^RESOLVER_ADDRESS=" .env; then
                sed -i.bak "s/^RESOLVER_ADDRESS=.*/RESOLVER_ADDRESS=$resolver_address/" .env && rm .env.bak
            else
                echo "RESOLVER_ADDRESS=$resolver_address" >> .env
            fi
        else
            echo "RESOLVER_ADDRESS=$resolver_address" > .env
        fi
        
        success "Resolver address set to $resolver_address"
    else
        echo -e "${BOLD}${YELLOW}Skipping Resolver deployment${NC}"
    fi
else
    success "Resolver already deployed at $RESOLVER_ADDRESS"
    
    if confirm "Deploy a new Resolver instead?"; then
        forge script script/StepByStepSetup.s.sol:DeployResolver $SCRIPT_ARGS
        
        echo -e "${BOLD}Enter the new Resolver address:${NC}"
        read -r resolver_address
        export RESOLVER_ADDRESS=$resolver_address
        
        # Update .env
        if [ -f .env ]; then
            sed -i.bak "s/^RESOLVER_ADDRESS=.*/RESOLVER_ADDRESS=$resolver_address/" .env && rm .env.bak
        fi
        
        success "Resolver address updated to $resolver_address"
    fi
fi
echo

# Step 4: Setup Registry (Controller + Metadata)
step "4" "Setup Registry (set Controller and Metadata)"
if [ -z "$CONTROLLER_ADDRESS" ] || [ -z "$METADATA_ADDRESS" ]; then
    echo -e "${BOLD}${RED}Error:${NC} CONTROLLER_ADDRESS and METADATA_ADDRESS must be set before continuing."
    echo "Please complete steps 1 and 2 first."
else
    if confirm "Ready to set up the Registry with Controller and Metadata?"; then
        forge script script/StepByStepSetup.s.sol:SetupRegistry $SCRIPT_ARGS
        success "Registry setup completed"
    else
        echo -e "${BOLD}${YELLOW}Skipping Registry setup${NC}"
    fi
fi
echo

# Step 5: Configure Pricing
step "5" "Configure Pricing"
if [ -z "$CONTROLLER_ADDRESS" ]; then
    echo -e "${BOLD}${RED}Error:${NC} CONTROLLER_ADDRESS must be set before continuing."
    echo "Please complete step 1 first."
else
    if confirm "Ready to configure pricing in the Controller?"; then
        forge script script/StepByStepSetup.s.sol:SetupPricing $SCRIPT_ARGS
        success "Pricing configuration completed"
    else
        echo -e "${BOLD}${YELLOW}Skipping pricing configuration${NC}"
    fi
fi
echo

# Display summary
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo -e "${BOLD}${GREEN}  Deployment Summary  ${NC}"
echo -e "${BOLD}${GREEN}=======================================${NC}"
echo
echo -e "${BOLD}Registry:${NC}    $REGISTRY_ADDRESS"
echo -e "${BOLD}Controller:${NC}  $CONTROLLER_ADDRESS"
echo -e "${BOLD}Metadata:${NC}    $METADATA_ADDRESS"
echo -e "${BOLD}Resolver:${NC}    $RESOLVER_ADDRESS"
echo -e "${BOLD}MockOracle:${NC}  $MOCK_ORACLE_ADDRESS"
echo
echo -e "${BOLD}${GREEN}Deployment completed!${NC}"
echo

# Offer to verify contracts
if confirm "Would you like to verify the contracts?"; then
    echo -e "Verifying Registry..."
    forge verify-contract --chain-id 998 --verifier sourcify $REGISTRY_ADDRESS src/core/DotHypeRegistry.sol:DotHypeRegistry
    
    if [ ! -z "$CONTROLLER_ADDRESS" ]; then
        echo -e "Verifying Controller..."
        forge verify-contract --chain-id 998 --verifier sourcify $CONTROLLER_ADDRESS src/core/DotHypeController.sol:DotHypeController
    fi
    
    if [ ! -z "$METADATA_ADDRESS" ]; then
        echo -e "Verifying Metadata..."
        forge verify-contract --chain-id 998 --verifier sourcify $METADATA_ADDRESS src/core/DotHypeMetadata.sol:DotHypeMetadata
    fi
    
    if [ ! -z "$RESOLVER_ADDRESS" ]; then
        echo -e "Verifying Resolver..."
        forge verify-contract --chain-id 998 --verifier sourcify $RESOLVER_ADDRESS src/core/DotHypeResolver.sol:DotHypeResolver
    fi
    
    if [ ! -z "$MOCK_ORACLE_ADDRESS" ]; then
        echo -e "Verifying MockOracle..."
        forge verify-contract --chain-id 998 --verifier sourcify $MOCK_ORACLE_ADDRESS script/MinimalDeploy.s.sol:MockOracle
    fi
    
    success "Contract verification completed"
fi

# Make the script executable
chmod +x scripts/step-by-step.sh 