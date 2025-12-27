# Authorization-Governed Secure Vault System

## Overview

This project implements a secure, authorization-governed vault system for controlled asset withdrawals on a blockchain network.
The design intentionally separates asset custody from permission validation to reflect real-world decentralized architectures and reduce security risk.

Funds can only be withdrawn from the vault after a valid, one-time authorization generated off-chain is verified on-chain.

---

## System Architecture

The system consists of two on-chain smart contracts:

### SecureVault
- Holds native blockchain currency (ETH)
- Accepts deposits from any address
- Executes withdrawals only after authorization validation
- Does not perform cryptographic verification

### AuthorizationManager
- Validates off-chain generated authorizations
- Verifies cryptographic signatures
- Tracks and consumes authorizations exactly once
- Acts as the sole authority for withdrawal permissions

This separation ensures that compromising one component does not automatically compromise asset custody.

---

## High-Level Flow

1. Any user deposits ETH into the SecureVault
2. An off-chain system generates a signed withdrawal authorization
3. A withdrawal request is submitted to the vault
4. The vault requests validation from the AuthorizationManager
5. If valid:
   - The authorization is consumed
   - Internal vault state is updated
   - Funds are transferred to the recipient
6. Reuse of the same authorization permanently fails

---

## Authorization Design

### Off-Chain Authorization

Each authorization is generated off-chain and signed by a trusted signer.
The signed message deterministically binds the following parameters:

- Vault address
- Blockchain network (chain ID)
- Recipient address
- Withdrawal amount
- Unique nonce

### Message Construction

keccak256(
  vault_address,
  chain_id,
  recipient,
  amount,
  nonce
)

This prevents:
- Cross-vault replay
- Cross-chain replay
- Amount or recipient manipulation
- Authorization reuse

---

## Replay Protection

Replay protection is enforced on-chain using:

mapping(bytes32 => bool) usedAuthorizations;

Once an authorization is successfully verified:
- It is permanently marked as consumed
- Any further attempt to reuse it reverts deterministically

---

## Contract Responsibilities

### SecureVault
- Holds ETH
- Emits deposit and withdrawal events
- Requests authorization validation
- Updates internal accounting before transferring value

### AuthorizationManager
- Verifies ECDSA signatures
- Confirms authorization uniqueness
- Consumes authorizations atomically
- Emits authorization consumption events

---

## Security Guarantees and Invariants

The system guarantees:

- Each authorization produces exactly one state transition
- Vault balance can never become negative
- Unauthorized withdrawals always revert
- Cross-contract calls cannot produce duplicated effects
- Initialization logic executes only once
- State is updated before value transfer
- System behavior remains deterministic under repeated or adversarial calls

---

## Observability

The system emits events for all critical actions:

- Deposits
- Authorization consumption
- Withdrawals

These events allow complete on-chain auditing and off-chain monitoring.

---

## Local Deployment Using Docker

### Requirements
- Docker
- Docker Compose

### Run the System

docker-compose up

This process:
1. Starts a local blockchain node
2. Compiles the smart contracts
3. Deploys the AuthorizationManager
4. Deploys the SecureVault with the authorization manager address
5. Outputs deployed contract addresses and network identifier

---

## Deployment Details

Contracts are deployed in the following order:

1. AuthorizationManager
2. SecureVault (with AuthorizationManager reference)

Deployment logs include:
- Contract addresses
- Network chain ID

---

## Validation and Testing

Validation can be performed using:
- Automated tests (optional)
- Manual interaction via Hardhat console or scripts

Expected behaviors:
- Valid authorization results in successful withdrawal
- Reused authorization reverts
- Invalid signature reverts
- Modified recipient or amount reverts

---

## Assumptions and Limitations

- A single trusted signer is used for authorization issuance
- Only native blockchain currency (ETH) is supported
- Authorization issuance logic is off-chain and not included
- Contracts are not upgradeable by design

---

## Design Rationale

This architecture mirrors patterns used in:

- DAO treasury systems
- Custodial withdrawal pipelines
- Bridges and relayers
- Exchange settlement systems

Separating custody from authorization minimizes trust concentration and reduces the impact of potential vulnerabilities.

---

## Summary

This project demonstrates:

- Secure multi-contract system design
- One-time authorization enforcement
- Deterministic state transitions
- Replay-safe off-chain permission validation
- Production-grade Web3 security practices
