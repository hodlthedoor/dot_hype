# DotHype

A native naming service for the Hyperliquid ecosystem.

## Deployed Contracts

### Hyperliquid Chain (Chain ID: 999)

- **HypeOracle**: `0x09fAB7D96dB646a0f164E3EA84782B45F650Fb51`

  - Price oracle for converting USD to HYPE using Hyperliquid's precompile

- **DotHypeRegistry**: `0x505b7A6345adF0C89749fC5d631941FdfC73460F`

  - Core registry contract for .hype domains

- **DotHypeResolver**: `0xBEd1199B206d777B2C9522618B7580D2B48F5a10`

  - Resolver contract for domain records

- **DotHypeOnchainMetadataV2**: `0x309961D545A8c8498Cc691a0054f6CddDbc1CB8f`

  - On-chain metadata for domains

- **DotHypeDutchAuction**: `0xCd0A58e078c57B69A3Da6703213aa69085E2AC65`
  - Dutch auction implementation for domains

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm

### Setup

1. Clone the repository:

```bash
git clone https://github.com/hyperliquid-dex/dot_hype.git
cd dot_hype
```

2. Install dependencies:

```bash
forge install
```

3. Build the contracts:

```bash
forge build
```

4. Run tests:

```bash
forge test
```

### Block Toggle Tool

For testing on Hyperliquid's testnet, use the block toggle tool:
https://hyperevm-block-toggle.vercel.app/

## License

MIT License
