# Morpho Blue Overview

## Project Name
Morpho Blue

## Description
Morpho Blue is a noncustodial lending protocol implemented for the Ethereum Virtual Machine. It offers a trustless primitive with increased efficiency and flexibility compared to existing lending platforms. The protocol provides:
- Permissionless risk management
- Permissionless market creation
- Oracle agnostic pricing
- Higher collateralization factors
- Improved interest rates
- Lower gas consumption

The protocol is designed to be simple, immutable, and governance-minimized, serving as a base layer for other applications to build upon.

## Key Features
- **Singleton Implementation**: All markets live in one smart contract
- **Isolated Markets**: Each market has one loan token, one collateral token, one oracle, one IRM, and one LLTV
- **Callbacks**: Supply, supplyCollateral, repay, and liquidate functions support callbacks
- **Free Flash Loans**: No fee flash loan functionality
- **Account Management**: EIP-712 authorization system for position management delegation
- **Bad Debt Accounting**: Losses are socialized proportionately among lenders

## Entry Points
| Contract | File | Purpose |
|----------|------|---------|
| Morpho | `src/Morpho.sol` | Main protocol contract - singleton holding all markets |

## Architecture
Morpho Blue uses a minimal, immutable design:
- Single deployable contract (Morpho.sol)
- Internal libraries for math, utilities, and events
- External dependencies via interfaces (IRM, Oracle, ERC20)
- Periphery libraries for integrators

## Solidity Version
0.8.19

## License
BUSL-1.1 (with GPL-2.0-or-later for interfaces, libraries, mocks, and tests)
