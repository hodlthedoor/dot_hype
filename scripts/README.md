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

# DotHype Merkle Proof Generator

This directory contains scripts to generate Merkle proofs for whitelisted addresses in the DotHype domain registration system.

## Requirements

- Node.js (v14 or higher)
- npm

## Setup

Install the required dependencies:

```bash
cd scripts
npm install
```

## Generating Merkle Proofs

1. Modify the `addresses` array in `generate-merkle-proofs.js` to include the Ethereum addresses you want to whitelist.

2. Run the script:

```bash
npm run generate
```

This will output:

- The Merkle root to set in the smart contract
- Solidity code to use in your tests, including pre-computed proofs
- A verification example to check if an address is in the Merkle tree

## Using in Production

For production use, you would typically:

1. Generate the Merkle tree with all whitelisted addresses
2. Deploy the smart contract with the generated Merkle root
3. Share the specific proof with each user (via your frontend or API)
4. Users submit their proof when calling the `registerWithMerkleProof` function

## Generating Proofs for Specific Addresses

You can modify the script to output proofs for specific addresses. Example modification:

```javascript
// Add this function to the script
function generateProofForAddress(address) {
  const { merkleTree, leafNodes } = generateMerkleTree(addresses);
  const addressIndex = addresses.findIndex(
    (addr) => addr.toLowerCase() === address.toLowerCase()
  );

  if (addressIndex === -1) {
    console.log(`Address ${address} not found in whitelist`);
    return null;
  }

  const proof = generateProof(merkleTree, leafNodes[addressIndex]);
  console.log(`Proof for ${address}:`, proof);
  return proof;
}

// Call it with a specific address
generateProofForAddress("0x1234...");
```

## Security Considerations

- Merkle proofs are safe to distribute publicly, as they cannot be used to generate proofs for addresses not in the tree
- The Merkle root is the only data that needs to be stored on-chain
- Each proof is specific to a single address and cannot be reused for other addresses
