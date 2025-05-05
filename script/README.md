# Deployment Scripts for DotHype

This directory contains deployment scripts for the DotHype naming service contracts.

## Deploy Onchain Metadata Contract

The `DeployOnchainMetadata.s.sol` script deploys the new onchain metadata contract and updates the registry to use it for all .hype domains.

### Prerequisites

1. Set up your environment variables in a `.env` file:

   ```
   PRIVATE_KEY=your_private_key_here
   REGISTRY_ADDRESS=0x29ecB1E27a15037442cC97256f05F45f55EF10d0
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   ```

2. Make sure you have Foundry installed and updated.

### Deployment Steps

1. Load your environment variables:

   ```bash
   source .env
   ```

2. Run the script on the target network (e.g., Hyperliquid testnet):

   ```bash
   forge script script/DeployOnchainMetadata.s.sol \
     --rpc-url https://rpc.hyperliquid-testnet.xyz/evm \
     --chain-id 998 \
     --broadcast \
     --verify \
     --verifier sourcify
   ```

3. For mainnet deployment:
   ```bash
   forge script script/DeployOnchainMetadata.s.sol \
     --rpc-url <MAINNET_RPC_URL> \
     --chain-id <MAINNET_CHAIN_ID> \
     --broadcast \
     --verify \
     --verifier sourcify
   ```

### What the Script Does

1. Deploys the `DotHypeOnchainMetadata` contract with dynamic SVG generation
2. Updates the existing registry to use the new metadata provider
3. Outputs verification instructions for the contract

### After Deployment

Once deployed, all .hype domains will automatically use the new onchain metadata, which includes:

- Fully on-chain SVG images
- Dynamic styling based on domain name length
- The Hyperliquid logo integrated into the design
- Custom colors and styling

This provides a permanent, immutable metadata solution for all .hype domains without relying on any external servers.

## Customizing the Metadata

After deployment, the contract owner can customize various aspects of the metadata:

1. Background color: `setBackgroundColor(string calldata _backgroundColor)`
2. Text color: `setTextColor(string calldata _textColor)`
3. Accent color: `setAccentColor(string calldata _accentColor)`
4. Logo color: `setLogoColor(string calldata _logoColor)`
5. Circle color: `setCircleColor(string calldata _circleColor)`
6. Font sizes: `setFontSizes(uint256 _mainFontSize, uint256 _secondaryFontSize)`
7. Font family: `setFontFamily(string calldata _fontFamily)`
8. Design settings: `setDesignSettings(uint256 _logoSize, uint256 _circleRadius)`

These functions can be called through a contract management interface or directly using Etherscan.
