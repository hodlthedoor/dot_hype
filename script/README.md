# DotHype Deployment Script

This directory contains deployment scripts for the DotHype domain system.

## Available Scripts

- `DeployDotHype.s.sol`: Main deployment script that deploys all core contracts with configured pricing.

## Deployment Instructions

### Prerequisites

1. Make sure you have Foundry installed:

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. Set up environment variables:
   ```bash
   export PRIVATE_KEY=your_private_key_here
   export RPC_URL=your_rpc_url_here
   ```

### Deploying to Hyperliquid Testnet

```bash
forge script script/DeployDotHype.s.sol:DeployDotHype --rpc-url $RPC_URL --broadcast --verify
```

### Deploying to Hyperliquid Mainnet

```bash
forge script script/DeployDotHype.s.sol:DeployDotHype --rpc-url $RPC_URL --broadcast --verify
```

## Contract Configuration

The deployment script sets up the following:

1. **HypeOracle**: Used for USD to HYPE conversion
2. **DotHypeRegistry**: Main registry for domain names
3. **DotHypeResolver**: Resolver for domain name lookups
4. **DotHypeOnlineMetadata**: Metadata provider for domains
5. **DotHypeDutchAuction**: Controller with Dutch auction functionality

### Pricing Configuration

Domain registration prices:

- 1 character: $0
- 2 characters: $0
- 3 characters: $10
- 4 characters: $2
- 5+ characters: $0.50

Domain renewal prices:

- 1 character: $15
- 2 characters: $10
- 3 characters: $8
- 4 characters: $1.60
- 5+ characters: $0.40

## Post-Deployment Tasks

After deployment, you may want to:

1. Transfer ownership of contracts to a multisig
2. Configure additional reserved names
3. Set up Dutch auctions for premium domains
4. Verify contracts on explorers

## Contract Verification

Contracts can be verified on Hyperliquid explorers using:

```bash
forge verify-contract --chain hyperliquid-testnet <CONTRACT_ADDRESS> <CONTRACT_NAME>
```
