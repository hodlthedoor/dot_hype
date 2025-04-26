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

## Project Structure

- `src/`: Smart contract source files
  - `core/`: Core registry and resolver contracts
  - `auction/`: Dutch auction implementation
  - `revenue/`: Treasury and revenue handling
  - `interfaces/`: Contract interfaces
  - `libraries/`: Utility libraries
- `test/`: Contract test files
- `script/`: Deployment scripts
- `sdk/`: JavaScript/TypeScript SDK (to be implemented)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
