
block toggle for hyperliquid:

https://hyperevm-block-toggle.vercel.app/

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# dotHYPE

A native naming service for the Hyperliquid ecosystem focused on fairness, simplicity, and identity cohesion.

## Project Overview

dotHYPE provides a naming registry for the Hyperliquid ecosystem with the following features:

- .hype domain name registration and management
- Address resolution for registered names
- Metadata storage for user profiles
- Dutch auction system for premium names
- Integration with the Hyperliquid ecosystem

## Development Phases

### Phase 1: Core Naming System & SDK Integration

- Core registry/resolver contract
- Metadata & resolution
- Payment & revenue handling
- SDK integration tools
- Admin & upgradeability

### Phase 2: Dutch Auction Module

- Auction contract implementation
- Frontend support
- Auction supply control

### Phase 3: Public Launch

- Production deployment
- Public-facing frontend
- Post-launch support

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm (for SDK development)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/dot_hype.git
cd dot_hype
```

2. Install dependencies:

```bash
forge install
```

3. Build the project:

```bash
forge build
```

4. Run tests:

```bash
forge test
```

## Deployment to Hyperliquid

The DotHype contracts need to be deployed in a specific sequence to the Hyperliquid blockchain. Due to gas constraints on Hyperliquid, we use a step-by-step deployment process.

### Option 1: Interactive Deployment Script (Recommended)

Run the interactive deployment script which will guide you through each step:

```bash
./scripts/deploy.sh
```

This script will:

1. Deploy the Registry
2. Deploy the MockOracle (fixed pricing)
3. Deploy the HypeOracle (Hyperliquid pricing)
4. Deploy the Controller (using MockOracle initially)
5. Deploy the Resolver
6. Set the Controller in the Registry
7. Configure pricing in the Controller

The script saves contract addresses to a `.env` file for future use.

### Option 2: Manual Deployment

For manual deployment, follow these steps:

1. Set up environment variables:

```bash
export PRIVATE_KEY=your_private_key
export RPC_URL=https://rpc.hyperliquid-testnet.xyz/evm
```

2. Deploy each contract individually using the minimal deployment scripts:

```bash
# Deploy the Registry
forge script script/MinimalDeploy.s.sol:MinimalDeployRegistry --rpc-url $RPC_URL --broadcast --verify --use hyperliquid-deploy

# Save the address
export REGISTRY_ADDRESS=<deployed_address>

# Continue with other contracts...
```

For detailed manual deployment steps, see the [deployment guide](script/README.md).

### Contract Verification

After deployment, verify all contracts with:

```bash
./scripts/verify.sh
```

### Switching Oracles

The system initially deploys with the MockOracle (fixed pricing) for simplicity. To switch to the HypeOracle (which uses the Hyperliquid precompile for real-time HYPE pricing):

```bash
forge script script/SwitchToHypeOracle.s.sol --rpc-url $RPC_URL --broadcast
```

## Project Structure

- `src/`: Smart contract source files
  - `core/`: Core registry and resolver contracts
  - `auction/`: Dutch auction implementation
  - `revenue/`: Treasury and revenue handling
  - `interfaces/`: Contract interfaces
  - `libraries/`: Utility libraries
- `test/`: Contract test files
- `script/`: Deployment scripts
- `scripts/`: Helper bash scripts for deployment and verification

## License

This project is licensed under the MIT License - see the LICENSE file for details.
