# MultiDAO Ventures Smart Contract

## Overview
A comprehensive Stacks blockchain DAO contract that combines multiple DeFi functionalities into a single smart contract.

## Features
- 🏛️ **DAO Governance**: Complete proposal and voting system
- 🎫 **NFT Membership**: Role-based access control with NFT integration
- 🏦 **Vault Management**: Secure STX token storage and management
- 💰 **Investment Pool**: Collective investment capabilities
- 🌉 **Cross-chain Registry**: Asset registration across multiple chains
- 🎯 **Bounty System**: Reward system for contributors
- 📍 **Staking Mechanism**: Token staking functionality

## Contract Functions

### Role Management
- `set-role`: Assign roles to users (founder, guardian, member, investor)
- `get-role`: Query user roles
- `is-valid-role`: Validate role assignments

### Vault Operations
- `deposit-vault`: Deposit STX tokens into the vault
- `vault-status`: Check current vault balance

### Proposal System
- `create-proposal`: Submit new proposals
- `vote-proposal`: Cast votes on active proposals
- `execute-proposal`: Implement approved proposals

### Asset Registry
- `register-asset`: Register cross-chain assets

## Development
```bash
# Install dependencies
npm install

# Run tests
clarinet test

# Check contract
clarinet check
```

## Deployment
Contract is deployed on Stacks blockchain:
- Contract ID: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.multidaoventures`

## Requirements
- Clarinet v1.0.0 or higher
- Node.js v14+ (for development)
- Stacks Wallet for interaction

## Security
- Role-based access control
- Multi-signature approval system
- Bounded lists for vote storage
- Protected treasury operations



---
*Note: This is a complex smart contract. Please review thoroughly before deployment and use at your own risk.*
