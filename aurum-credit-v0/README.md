
# Aurum Credit v0

Gold-unit lending protocol on Ethereum L2 with multi-collateral support and Dutch auction liquidations.

## Overview

Aurum Credit is a decentralized lending protocol that allows users to borrow against their crypto assets denominated in gold ounces (ozt). The protocol supports multiple collateral types including PAXG, XAUt, WETH, WBTC, and USDC.

## Features

- **Multi-collateral Vault**: Support for multiple asset types with configurable haircuts
- **ozt-denominated Loans**: Borrowing denominated in gold ounces
- **Oracle Router**: XAU/USD × asset/USD pricing with medianizer and deviation/staleness guards
- **Dutch Auction Liquidations**: Efficient price discovery through descending price auctions
- **Insurance Fund**: Protocol fee collection and backstop mechanism
- **Access Controls**: Role-based permission system

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Vault       │◄──►│      Loan       │◄──►│ OracleRouter    │
│ (Multi-Collat)  │    │  (ozt-denom)    │    │ (XAU/USD feeds) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ AuctionHouse    │    │ InsuranceFund   │    │ AccessControls  │
│ (Dutch auctions)│    │ (Fee collection)│    │ (Role management)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Quick Start

### Prerequisites

- Node.js 18+
- Foundry
- Anvil (local Ethereum node)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd aurum-credit-v0

# Install dependencies
npm install

# Install Foundry dependencies
cd contracts && forge install
```

### Running Locally

```bash
# Start local node
anvil

# Deploy contracts
npm run deploy:local

# Start frontend
npm run dev
```

## Contracts

### Core Contracts

- `Vault.sol`: Multi-collateral vault management
- `Loan.sol`: ozt-denominated loan logic
- `OracleRouter.sol`: Price feed aggregation and validation
- `AuctionHouse.sol`: Dutch auction liquidation mechanism
- `InsuranceFund.sol`: Protocol fee collection and insurance
- `AccessControls.sol`: Role-based access control

## Security

- Reentrancy guards on all external functions
- Checked math operations using OpenZeppelin's SafeMath
- Pause functionality for oracle and auction failures
- Comprehensive test coverage including fuzz testing

## Testing

```bash
# Run all tests
npm test

# Run contract tests only
npm run test:contracts

# Run frontend tests only
npm run test:frontend
```

## License

MIT
