# Step-by-Step Guide: React/Wagmi/TypeScript/Tailwind DApp for DotHype Smart Contracts

## Overview

This guide will help you build a modern web application to interact with the DotHype domain registration smart contracts, specifically focusing on wallet connection and merkle proof minting functionality.

## Contract Analysis Summary

Based on the smart contract analysis, here are the key contracts and functions:

- **DotHypeController**: Main controller with `registerWithMerkleProof()` function
- **DotHypeDutchAuction**: Extension of controller with Dutch auction functionality
- **DotHypeRegistry**: ERC721-based domain registry
- **Merkle Proof System**: Allowlist-based minting with one mint per address

## Step 1: Project Setup and Dependencies

### 1.1 Initialize the Project

```bash
# Create new React app with TypeScript
npx create-react-app dothype-app --template typescript
cd dothype-app

# Install core dependencies
npm install wagmi viem @tanstack/react-query
npm install @rainbow-me/rainbowkit
npm install @tailwindcss/forms @headlessui/react @heroicons/react

# Install development dependencies
npm install -D tailwindcss postcss autoprefixer
npm install -D @types/node

# Initialize Tailwind CSS
npx tailwindcss init -p
```

### 1.2 Configure Tailwind CSS

Update `tailwind.config.js`:

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        "hype-primary": "#6366f1",
        "hype-secondary": "#8b5cf6",
      },
    },
  },
  plugins: [require("@tailwindcss/forms")],
};
```

## Step 2: Smart Contract Integration Setup

### 2.1 Contract ABIs and Addresses

Create `src/contracts/abis.ts`:

```typescript
// You'll need to extract these from your compiled contracts
export const DOT_HYPE_CONTROLLER_ABI = [
  // Include the full ABI from your compiled contract
  {
    inputs: [
      { internalType: "string", name: "name", type: "string" },
      { internalType: "uint256", name: "duration", type: "uint256" },
      { internalType: "bytes32[]", name: "merkleProof", type: "bytes32[]" },
    ],
    name: "registerWithMerkleProof",
    outputs: [
      { internalType: "uint256", name: "tokenId", type: "uint256" },
      { internalType: "uint256", name: "expiry", type: "uint256" },
    ],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "string", name: "name", type: "string" },
      { internalType: "uint256", name: "duration", type: "uint256" },
    ],
    name: "calculatePrice",
    outputs: [{ internalType: "uint256", name: "price", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "user", type: "address" }],
    name: "hasAddressUsedMerkleProof",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "view",
    type: "function",
  },
  // ... add other necessary functions
] as const;

export const DOT_HYPE_REGISTRY_ABI = [
  // Include registry ABI for reading domain info
  // ... add necessary functions
] as const;
```

### 2.2 Contract Addresses Configuration

Create `src/contracts/addresses.ts`:

```typescript
export const CONTRACT_ADDRESSES = {
  // Replace with your actual deployed contract addresses
  HYPERLIQUID_TESTNET: {
    DOT_HYPE_CONTROLLER: "0x...", // Your deployed controller address
    DOT_HYPE_REGISTRY: "0x...", // Your deployed registry address
    DOT_HYPE_DUTCH_AUCTION: "0x...", // Your deployed Dutch auction address
  },
  HYPERLIQUID_MAINNET: {
    DOT_HYPE_CONTROLLER: "0x...",
    DOT_HYPE_REGISTRY: "0x...",
    DOT_HYPE_DUTCH_AUCTION: "0x...",
  },
} as const;

export const SUPPORTED_CHAINS = {
  HYPERLIQUID_TESTNET: {
    id: 998,
    name: "Hyperliquid Testnet",
    network: "hyperliquid-testnet",
    nativeCurrency: {
      decimals: 18,
      name: "Ether",
      symbol: "ETH",
    },
    rpcUrls: {
      default: {
        http: ["https://rpc.hyperliquid-testnet.xyz/evm"],
      },
      public: {
        http: ["https://rpc.hyperliquid-testnet.xyz/evm"],
      },
    },
    blockExplorers: {
      default: {
        name: "Explorer",
        url: "https://explorer.hyperliquid-testnet.xyz",
      },
    },
  },
} as const;
```

## Step 3: Wagmi and RainbowKit Configuration

### 3.1 Wagmi Configuration

Create `src/wagmi.ts`:

```typescript
import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { defineChain } from "viem";

const hyperliquidTestnet = defineChain({
  id: 998,
  name: "Hyperliquid Testnet",
  network: "hyperliquid-testnet",
  nativeCurrency: {
    decimals: 18,
    name: "Ether",
    symbol: "ETH",
  },
  rpcUrls: {
    default: {
      http: ["https://rpc.hyperliquid-testnet.xyz/evm"],
    },
    public: {
      http: ["https://rpc.hyperliquid-testnet.xyz/evm"],
    },
  },
  blockExplorers: {
    default: {
      name: "Explorer",
      url: "https://explorer.hyperliquid-testnet.xyz",
    },
  },
});

export const config = getDefaultConfig({
  appName: "DotHype",
  projectId: "YOUR_WALLETCONNECT_PROJECT_ID", // Get from WalletConnect
  chains: [hyperliquidTestnet],
  ssr: false,
});
```

### 3.2 App Configuration

Update `src/App.tsx`:

```typescript
import "@rainbow-me/rainbowkit/styles.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { config } from "./wagmi";
import "./App.css";
import DomainMinter from "./components/DomainMinter";

const queryClient = new QueryClient();

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <div className="min-h-screen bg-gray-50">
            <header className="bg-white shadow">
              <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex justify-between items-center py-6">
                  <h1 className="text-3xl font-bold text-gray-900">DotHype</h1>
                  <ConnectButton />
                </div>
              </div>
            </header>
            <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
              <DomainMinter />
            </main>
          </div>
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
```

## Step 4: Merkle Proof Generation Utility

### 4.1 Merkle Tree Utilities

Create `src/utils/merkle.ts`:

```typescript
import { keccak256 } from "viem";
import { MerkleTree } from "merkletreejs";

export interface MerkleData {
  root: string;
  proofs: Record<string, string[]>;
}

export function generateMerkleTree(addresses: string[]): MerkleData {
  // Convert addresses to leaf nodes (same as contract)
  const leafNodes = addresses.map((addr) =>
    keccak256(encodePacked(["address"], [addr as `0x${string}`]))
  );

  // Create merkle tree
  const merkleTree = new MerkleTree(leafNodes, keccak256, {
    sortPairs: true,
  });

  const root = merkleTree.getRoot().toString("hex");
  const proofs: Record<string, string[]> = {};

  // Generate proofs for each address
  addresses.forEach((addr, index) => {
    const proof = merkleTree.getProof(leafNodes[index]);
    proofs[addr.toLowerCase()] = proof.map((p) => p.data.toString("hex"));
  });

  return {
    root: `0x${root}`,
    proofs,
  };
}

export function verifyMerkleProof(
  proof: string[],
  leaf: string,
  root: string
): boolean {
  return MerkleTree.verify(
    proof.map((p) => Buffer.from(p.replace("0x", ""), "hex")),
    Buffer.from(leaf.replace("0x", ""), "hex"),
    Buffer.from(root.replace("0x", ""), "hex"),
    keccak256
  );
}

// Helper function to encode packed (you may need to implement this)
function encodePacked(types: string[], values: any[]): `0x${string}` {
  // Implementation depends on your chosen library
  // You might want to use ethers.js or viem utilities
  throw new Error("Implement encodePacked function");
}
```

## Step 5: Custom Hooks for Contract Interactions

### 5.1 Domain Registration Hook

Create `src/hooks/useDomainRegistration.ts`:

```typescript
import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useReadContract,
} from "wagmi";
import { parseEther, formatEther } from "viem";
import { DOT_HYPE_CONTROLLER_ABI } from "../contracts/abis";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";

export function useDomainRegistration() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({ hash });

  const registerWithMerkleProof = async (
    name: string,
    duration: bigint,
    merkleProof: `0x${string}`[],
    price: bigint
  ) => {
    writeContract({
      address: CONTRACT_ADDRESSES.HYPERLIQUID_TESTNET.DOT_HYPE_CONTROLLER,
      abi: DOT_HYPE_CONTROLLER_ABI,
      functionName: "registerWithMerkleProof",
      args: [name, duration, merkleProof],
      value: price,
    });
  };

  return {
    registerWithMerkleProof,
    hash,
    isPending,
    isConfirming,
    isConfirmed,
    error,
  };
}

export function useDomainPrice(name: string, duration: bigint) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.HYPERLIQUID_TESTNET.DOT_HYPE_CONTROLLER,
    abi: DOT_HYPE_CONTROLLER_ABI,
    functionName: "calculatePrice",
    args: [name, duration],
    query: {
      enabled: !!name && duration > 0n,
    },
  });
}

export function useHasUsedMerkleProof(address: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.HYPERLIQUID_TESTNET.DOT_HYPE_CONTROLLER,
    abi: DOT_HYPE_CONTROLLER_ABI,
    functionName: "hasAddressUsedMerkleProof",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });
}
```

## Step 6: Main Domain Minter Component

### 6.1 Domain Minter Component

Create `src/components/DomainMinter.tsx`:

```typescript
import React, { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { formatEther, parseEther } from "viem";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import {
  useDomainRegistration,
  useDomainPrice,
  useHasUsedMerkleProof,
} from "../hooks/useDomainRegistration";

// You'll need to provide this data (whitelist addresses and their proofs)
const MERKLE_DATA = {
  root: "0x...", // Your merkle root
  proofs: {
    // Address -> proof mapping
    "0x...": ["0x...", "0x..."], // Example proof
  },
};

const DomainMinter: React.FC = () => {
  const { address, isConnected } = useAccount();
  const [domainName, setDomainName] = useState("");
  const [duration, setDuration] = useState(365); // days

  const durationInSeconds = BigInt(duration * 24 * 60 * 60);

  const { data: price, isLoading: isPriceLoading } = useDomainPrice(
    domainName,
    durationInSeconds
  );
  const { data: hasUsedProof, isLoading: isCheckingProof } =
    useHasUsedMerkleProof(address);

  const {
    registerWithMerkleProof,
    isPending,
    isConfirming,
    isConfirmed,
    error,
    hash,
  } = useDomainRegistration();

  const isEligible = address && MERKLE_DATA.proofs[address.toLowerCase()];
  const canMint = isEligible && !hasUsedProof;

  const handleMint = async () => {
    if (!address || !canMint || !price) return;

    const proof = MERKLE_DATA.proofs[address.toLowerCase()];
    if (!proof) return;

    try {
      await registerWithMerkleProof(
        domainName,
        durationInSeconds,
        proof as `0x${string}`[],
        price
      );
    } catch (err) {
      console.error("Minting failed:", err);
    }
  };

  const isValidDomain =
    domainName.length >= 3 && /^[a-zA-Z0-9]+$/.test(domainName);

  return (
    <div className="max-w-md mx-auto bg-white rounded-lg shadow-lg p-6">
      <h2 className="text-2xl font-bold text-gray-900 mb-6">
        Mint Your .hype Domain
      </h2>

      {!isConnected ? (
        <div className="text-center">
          <p className="text-gray-600 mb-4">
            Connect your wallet to get started
          </p>
          <ConnectButton />
        </div>
      ) : (
        <div className="space-y-4">
          {/* Eligibility Status */}
          <div className="p-4 rounded-lg bg-gray-50">
            <h3 className="font-semibold text-gray-900 mb-2">
              Eligibility Status
            </h3>
            {isCheckingProof ? (
              <p className="text-gray-600">Checking eligibility...</p>
            ) : isEligible ? (
              hasUsedProof ? (
                <p className="text-red-600">
                  ❌ You have already used your merkle proof
                </p>
              ) : (
                <p className="text-green-600">✅ You are eligible to mint</p>
              )
            ) : (
              <p className="text-red-600">❌ You are not on the allowlist</p>
            )}
          </div>

          {/* Domain Input */}
          <div>
            <label
              htmlFor="domain"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              Domain Name
            </label>
            <div className="relative">
              <input
                type="text"
                id="domain"
                value={domainName}
                onChange={(e) => setDomainName(e.target.value.toLowerCase())}
                placeholder="Enter domain name"
                className="block w-full pr-16 px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-hype-primary focus:border-hype-primary"
              />
              <div className="absolute inset-y-0 right-0 flex items-center pr-3">
                <span className="text-gray-500 text-sm">.hype</span>
              </div>
            </div>
            {domainName && !isValidDomain && (
              <p className="text-red-600 text-sm mt-1">
                Domain must be at least 3 characters and contain only letters
                and numbers
              </p>
            )}
          </div>

          {/* Duration Input */}
          <div>
            <label
              htmlFor="duration"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              Registration Duration
            </label>
            <select
              id="duration"
              value={duration}
              onChange={(e) => setDuration(Number(e.target.value))}
              className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-hype-primary focus:border-hype-primary"
            >
              <option value={365}>1 Year</option>
              <option value={730}>2 Years</option>
              <option value={1095}>3 Years</option>
            </select>
          </div>

          {/* Price Display */}
          {isValidDomain && (
            <div className="p-4 rounded-lg bg-blue-50">
              <h3 className="font-semibold text-gray-900 mb-2">Price</h3>
              {isPriceLoading ? (
                <p className="text-gray-600">Calculating price...</p>
              ) : price ? (
                <p className="text-lg font-bold text-blue-600">
                  {formatEther(price)} ETH
                </p>
              ) : (
                <p className="text-red-600">Unable to calculate price</p>
              )}
            </div>
          )}

          {/* Mint Button */}
          <button
            onClick={handleMint}
            disabled={
              !canMint || !isValidDomain || isPending || isConfirming || !price
            }
            className={`w-full py-3 px-4 rounded-md font-semibold text-white transition-colors ${
              canMint && isValidDomain && price
                ? "bg-hype-primary hover:bg-hype-secondary focus:outline-none focus:ring-2 focus:ring-hype-primary focus:ring-offset-2"
                : "bg-gray-300 cursor-not-allowed"
            }`}
          >
            {isPending
              ? "Preparing Transaction..."
              : isConfirming
              ? "Confirming..."
              : "Mint Domain"}
          </button>

          {/* Transaction Status */}
          {hash && (
            <div className="p-4 rounded-lg bg-green-50">
              <h3 className="font-semibold text-green-900 mb-2">
                Transaction Status
              </h3>
              {isConfirmed ? (
                <p className="text-green-600">✅ Domain minted successfully!</p>
              ) : (
                <p className="text-yellow-600">⏳ Transaction pending...</p>
              )}
              <a
                href={`https://explorer.hyperliquid-testnet.xyz/tx/${hash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-600 hover:underline text-sm"
              >
                View on Explorer
              </a>
            </div>
          )}

          {/* Error Display */}
          {error && (
            <div className="p-4 rounded-lg bg-red-50">
              <h3 className="font-semibold text-red-900 mb-2">Error</h3>
              <p className="text-red-600 text-sm">{error.message}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default DomainMinter;
```

## Step 7: Required Information and Next Steps

### 7.1 Information Needed from You:

1. **Contract Addresses**:

   - Deployed DotHypeController address
   - Deployed DotHypeRegistry address
   - Deployed DotHypeDutchAuction address (if using)

2. **Merkle Tree Data**:

   - Complete list of whitelisted addresses
   - Generated merkle root (set in contract)
   - Merkle proofs for each address

3. **Network Configuration**:

   - Confirm Hyperliquid testnet/mainnet details
   - RPC URLs and block explorer URLs

4. **WalletConnect Project ID**:
   - Sign up at https://cloud.walletconnect.com/
   - Create a project and get the project ID

### 7.2 Additional Development Tasks:

1. **Contract ABI Extraction**:

   ```bash
   # Extract ABIs from compiled contracts
   forge build
   # Copy ABIs from out/ directory to src/contracts/abis.ts
   ```

2. **Merkle Tree Generation Script**:

   ```bash
   # Create a script to generate merkle tree from whitelist
   node scripts/generate-merkle-tree.js
   ```

3. **Environment Variables**:
   Create `.env` file:

   ```
   REACT_APP_WALLETCONNECT_PROJECT_ID=your_project_id
   REACT_APP_CONTROLLER_ADDRESS=0x...
   REACT_APP_REGISTRY_ADDRESS=0x...
   ```

4. **Testing**:

   - Test with testnet first
   - Verify merkle proofs work correctly
   - Test edge cases (already minted, invalid proofs, etc.)

5. **UI/UX Enhancements**:
   - Add domain availability checking
   - Show user's owned domains
   - Add domain search functionality
   - Implement responsive design
   - Add loading states and error handling

### 7.3 Deployment Preparation:

1. **Build and Deploy**:

   ```bash
   npm run build
   # Deploy to your preferred hosting service (Vercel, Netlify, etc.)
   ```

2. **Security Considerations**:
   - Ensure merkle proofs are properly validated
   - Test with multiple wallet types
   - Verify contract interactions work correctly

This comprehensive guide provides a solid foundation for your React/Wagmi/TypeScript/Tailwind application. Your development team can use this as a starting point and customize it based on your specific requirements and design preferences.

## Additional Notes

### Missing Dependencies

You may need to install additional packages:

```bash
npm install merkletreejs
npm install buffer # For browser compatibility
```

### Browser Compatibility

Add to your `src/index.tsx` or create a `polyfills.ts` file:

```typescript
import { Buffer } from "buffer";
window.Buffer = Buffer;
```

### Contract ABI Generation

To extract the full ABIs from your compiled contracts:

```bash
# After running forge build
cat out/DotHypeController.sol/DotHypeController.json | jq '.abi' > src/contracts/DotHypeController.abi.json
```

### Environment Configuration

Update your `.env` file with actual values:

```env
REACT_APP_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id
REACT_APP_CONTROLLER_ADDRESS=0xYourControllerAddress
REACT_APP_REGISTRY_ADDRESS=0xYourRegistryAddress
REACT_APP_MERKLE_ROOT=0xYourMerkleRoot
```
