# Vault Authorization System

A two‑contract system that separates **fund custody** from **authorization logic**.  
The `SecureVault` contract holds funds and executes withdrawals, while the `AuthorizationManager` validates off‑chain authorizations, tracks their usage, and guarantees that each authorization can be consumed at most once.

---

## Project Structure

contracts/
AuthorizationManager.sol // validates and tracks authorizations
SecureVault.sol // holds funds and processes withdrawals

scripts/
deploy.js // deploys AuthorizationManager and SecureVault

tests/
system.spec.js // end‑to‑end tests for deposits and withdrawals

docker-compose.yml // runs a local blockchain node (Anvil/Hardhat compatible)
hardhat.config.js // Hardhat configuration (Solidity 0.8.28, localhost network)
package.json // project dependencies and scripts
README.md // this file
Key points:

- The vault never does signature checks itself; it delegates all authorization decisions to the `AuthorizationManager` contract.
- Authorizations are **single‑use** and bound to a specific vault, recipient, amount, and network.
- All important actions (deposits, authorization consumption, withdrawals) emit events so behavior is observable.


## Contracts Overview

### AuthorizationManager

Responsibilities:

- Validate whether a withdrawal is permitted for:
  - a specific vault instance  
  - a specific recipient  
  - a specific amount  
  - a specific network (chain id)  
  - a unique authorization identifier  
- Ensure each authorization is used **at most once**.
- Emit an event when an authorization is consumed.

Core ideas:

- Maintains a mapping of `authorizationId => used` to prevent replay.
- Verifies that the message signed off‑chain matches:
  - the vault address  
  - the intended recipient  
  - the withdrawal amount  
  - the chain id  
  - the unique authorization identifier

If any check fails, `verifyAuthorization` returns false or reverts; the vault must then refuse the withdrawal.

### SecureVault

Responsibilities:

- Hold pooled native currency (ETH).
- Accept deposits from any address via `receive()`.
- Execute withdrawals **only after** the `AuthorizationManager` confirms validity.
- Maintain internal accounting so each successful withdrawal updates state exactly once.

Flow:

1. Anyone sends ETH to the vault → `receive()` records the deposit and emits a `Deposit` event.  
2. A user attempts to withdraw with an authorization → `withdraw` calls `AuthorizationManager.verifyAuthorization`.  
3. If authorized:
   - The vault updates its internal accounting.
   - Transfers the requested amount to the recipient.
   - Emits a `Withdrawal` event.

If authorization fails or has been used before, the withdrawal reverts and no state changes occur.

---

## Manual Authorization Flow (How It Is Generated and Consumed)

This section explains the intended off‑chain/on‑chain flow of a withdrawal authorization.

### 1. Off‑chain authorization generation

1. **Context is fixed off‑chain**  
   A trusted backend or “issuer” decides to allow a withdrawal with parameters:
   - `vault` – address of the deployed `SecureVault`
   - `recipient` – address that will receive funds
   - `amount` – exact withdrawal amount
   - `chainId` – network identifier (e.g. `31337` for local Hardhat)
   - `authId` – unique authorization identifier (e.g. random 32‑byte value or incrementing id)

2. **Message is constructed deterministically**  
   The backend builds a message (or struct) encoding all of the above fields in a fixed order. This ensures:
   - The authorization cannot be reused on another vault.
   - The authorization cannot be reused on another network.
   - The authorization is specific to a single recipient and amount.

3. **Issuer signs the message off‑chain**  
   Using a private key controlled by the authorization service, the backend signs the message and obtains:
   - `signature` (e.g. ECDSA signature bytes)

4. **Authorization package is sent to the user**  
   The user receives:
   - `vault` address  
   - `recipient` (their own address)  
   - `amount`  
   - `authId`  
   - `signature`

This package is never stored in the vault contract; it is provided by the caller on each withdrawal attempt.

### 2. On‑chain authorization verification and consumption

When the user calls `SecureVault.withdraw(...)`, the following happens:

1. **User calls `withdraw` with authorization data**

vault.withdraw(
recipient,
amount,
authId,
signature
);

The vault itself does not inspect the signature; it only forwards relevant data to `AuthorizationManager`.

2. **Vault delegates to `AuthorizationManager.verifyAuthorization`**

Inside `withdraw`, the vault calls:

bool ok = authManager.verifyAuthorization(
vaultAddress,
recipient,
amount,
authId,
signature
);

`verifyAuthorization` performs:

- Reconstructs the signed message from `(vaultAddress, recipient, amount, chainId, authId)`.
- Recovers the signer from `signature`.
- Checks that the signer is the trusted authorization issuer.
- Ensures `authId` is **not** marked as used yet.

3. **Single‑use enforcement**

- If `authId` has already been consumed, `verifyAuthorization` reverts or returns false.
- If checks pass, `verifyAuthorization`:
  - Marks `authId` as used in its internal mapping.
  - Emits an `AuthorizationUsed` event with the id and context.

This guarantees each authorization can only trigger **one successful state transition** in the vault.

4. **Vault updates state and transfers funds**

Only if `verifyAuthorization` returns true:

- Vault updates internal accounting (e.g. `totalWithdrawn`).
- Vault transfers `amount` of ETH to `recipient`.
- Vault emits a `Withdrawal` event containing recipient, amount, and `authId`.

If `verifyAuthorization` fails or reverts, the entire `withdraw` transaction reverts. No funds move and no internal accounting changes, ensuring safety under unexpected calls or replay attempts.

---

## Running Locally

### 1. Install dependencies

npm install


### 2. Run tests

npx hardhat test


The system test (`tests/system.spec.js`) covers:

- A successful deposit and balance/accounting update.
- A failing withdrawal path (e.g. missing or invalid authorization), demonstrating that unauthorized attempts revert and do not affect state.

### 3. Start a local blockchain (Hardhat node)

In one terminal:

npx hardhat node

This starts a JSON‑RPC node at `http://127.0.0.1:8545` with deterministic accounts and chain id `31337`.

### 4. Deploy contracts and view addresses

In a second terminal:

npx hardhat run scripts/deploy.js --network localhost


Example output:

Network: localhost
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
AuthorizationManager deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
SecureVault deployed to: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512


From this:

- **Network identifier**: `31337` (Hardhat local network).
- **AuthorizationManager address**: `0x5FbDB2315678afecb367f032d93F642f64180aa3`.
- **SecureVault address**: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`.

These values will change if you restart the node and redeploy, but the script always prints the current ones.

---

## Summary of Guarantees

- Deposits are tracked and observable via `Deposit` events.
- Withdrawals succeed only when:
  - an off‑chain authorization exists, and  
  - `AuthorizationManager.verifyAuthorization` confirms it.
- Each authorization (`authId`) is single‑use:
  - Marked as consumed during verification.
  - Any reuse attempt reverts.
- All critical state updates occur before value transfer.
- Behavior is observable via events for deposits, authorization use, and withdrawals.