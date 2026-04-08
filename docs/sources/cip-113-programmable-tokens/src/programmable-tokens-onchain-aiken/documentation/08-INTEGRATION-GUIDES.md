# Integration Guides

This document provides integration guidance for three key audiences: **wallet developers**, **indexers and explorers**, and **dApp developers**. Each section explains what programmable tokens mean for your domain, what changes relative to standard native tokens, and what to watch out for.

Before reading this guide, familiarity with the [Architecture](./02-ARCHITECTURE.md) document is recommended — in particular the ownership model, validator architecture, and withdraw-zero pattern.

---

## Table of Contents

1. [Understanding Programmable Addresses](#understanding-programmable-addresses)
2. [For Wallet Developers](#for-wallet-developers)
3. [For Indexers and Explorers](#for-indexers-and-explorers)
4. [For dApp Developers](#for-dapp-developers)

---

## Understanding Programmable Addresses

Before diving into each audience, it's essential to understand how programmable token addresses work — because this is where the biggest integration differences lie.

### Address Structure

All programmable tokens are held at addresses with a **shared payment credential** (the `programmable_logic_base` script hash) and a **unique stake credential** that determines ownership:

```
Programmable Address = programmable_logic_base (shared) + owner_credential (unique)
                       ──────────────────────────────────  ──────────────────────────
                       Payment credential                  Stake credential slot
                       Same for ALL holders                Determines who owns the UTxO
```

### Credential Flexibility

The stake credential slot is **polymorphic** — it can hold three types of credentials:

| Credential Type | Source | Authorization Method | Use Case |
|----------------|--------|---------------------|----------|
| User's **stake** key hash | Stake verification key | Signature from stake key | Preferred for standard wallets — aligns with Cardano's address model |
| User's **payment** key hash | Payment verification key | Signature from payment key | Required for enterprise wallets (e.g., CEXes) that lack stake credentials |
| **Script** hash | Smart contract | Script invocation via withdraw-zero | Required when a dApp or smart contract holds programmable tokens |

The on-chain validators do not distinguish between payment and stake key hashes. They only check whether the credential is a `VerificationKey` (requires signature) or `Script` (requires withdrawal invocation):

```aiken
// From programmable_logic_global.ak — credential-agnostic authorization
when stake_cred is {
  VerificationKey(pkh) -> is_signed_by(tx, pkh)    // Any key hash, payment or stake
  Script(_hash) -> is_script_invoked(tx, stake_cred) // Script via withdraw-zero
}
```

**The choice of which credential to place in the stake slot is a protocol-level and off-chain design decision**, not an on-chain constraint. Different tokens or deployments may adopt different conventions. Using the stake key is preferred because it aligns with Cardano's existing address model, but using the payment key is equally valid on-chain and becomes mandatory for enterprise addresses.

### Implications

This flexibility means:

- **A single user might hold programmable tokens at different addresses** depending on which credential the issuing protocol chose (payment vs stake key).
- **Wallets must know the convention** used by a given token to construct the correct query address.
- **Indexers must be prepared** for the stake credential slot to contain either a payment key hash, a stake key hash, or a script hash.

---

## For Wallet Developers

### Balance Resolution

Programmable token balances cannot be queried the same way as regular native tokens. With standard tokens, you query by payment address. With programmable tokens, all holders share the same payment credential — what differs is the stake credential.

**To display a user's programmable token balance:**

1. Determine which credential the token protocol uses (payment key or stake key — stake key is the default convention).
2. Construct the full address: `addr(programmable_logic_base_hash, user_credential)`.
3. Query all UTxOs at that address.
4. Sum the programmable token quantities across those UTxOs.

If a user may hold tokens under both their payment and stake credentials (different protocols, or mixed conventions), the wallet should query both addresses:

```
Address A = addr(programmable_logic_base, user_stake_credential)
Address B = addr(programmable_logic_base, user_payment_credential)

Total balance = tokens at Address A + tokens at Address B
```

**Important**: The `programmable_logic_base` hash is a protocol-level constant. It's the same for all programmable tokens within a given CIP-113 deployment. Wallets can obtain it from the protocol parameters reference UTxO or from off-chain configuration.

### Building Transfers

Building a programmable token transfer differs from a standard native token transfer in several ways:

#### 1. Authorization: Stake Key (or Payment Key) Signature

The owner authorizes spending by signing with whichever key corresponds to the credential in the stake slot:

- If stake key was used as the owner credential → **sign with the stake key**
- If payment key was used as the owner credential → **sign with the payment key**

This is different from standard transactions where the payment key always authorizes spending.

#### 2. Required Withdrawals (Withdraw-Zero Pattern)

The transaction must include zero-ADA withdrawals to invoke the validation chain:

```
withdrawals:
  - (programmable_logic_global, 0 ADA)    // Core CIP-113 validation
  - (transfer_logic_script,     0 ADA)    // Token-specific rules (e.g., denylist check)
```

The `transfer_logic_script` for a given token can be looked up from the on-chain registry.

#### 3. Required Reference Inputs

The transaction must include reference inputs (not consumed, just read):

- **Protocol parameters UTxO** — contains the `ProgrammableLogicGlobalParams` datum with the registry node currency symbol and programmable logic credential.
- **Registry node UTxO** — the registry entry for the token being transferred, containing the transfer logic script credential.

#### 4. Registry Proofs

The global validator needs a proof for each non-ADA policy in the transaction inputs. For programmable tokens, this is a `TokenExists` proof pointing to the registry node index. For any non-programmable tokens in the same UTxO (including ADA), a `TokenDoesNotExist` covering-node proof is needed.

#### 5. Output Construction

The output must go to the recipient's programmable address:

```
Output:
  address: addr(programmable_logic_base, recipient_credential)
  value: transferred tokens + minimum ADA
  datum: (as required by the specific protocol)
```

The payment credential stays the same (`programmable_logic_base`). Only the stake credential changes to the recipient's.

#### Transaction Skeleton

```
Inputs:
  - sender's programmable token UTxO

Reference Inputs:
  - protocol parameters UTxO (has protocol_params NFT)
  - registry node UTxO for the token's policy (has registry_node NFT)

Outputs:
  - addr(programmable_logic_base, recipient_credential) + tokens

Withdrawals:
  - (programmable_logic_global, 0)
  - (transfer_logic_script, 0)

Redeemer (for programmable_logic_global):
  TransferAct { proofs: [TokenExists { node_idx: <registry ref input index> }] }

Required Signatories:
  - sender's key (whichever key matches their credential in the stake slot)

Collateral:
  - standard collateral UTxO (for script execution)
```

### Token Discovery

To determine whether a token is programmable:

1. Look up the token's policy ID in the on-chain registry (sorted linked list of `RegistryNode` UTxOs at the registry address, each marked with an NFT from the `registry_node_cs` policy).
2. If a node with `key == policy_id` exists, the token is programmable.
3. The node's `transfer_logic_script` and `third_party_transfer_logic_script` fields indicate what substandard governs the token.

### Stake Delegation

In general, programmable token addresses will hold minimal ADA (just the minimum UTxO requirement), so delegation rewards are negligible. However, delegation is technically possible and depends on the credential type in the stake slot:

- **Stake key as owner credential**: Delegation works as normal — the stake key can sign delegation certificates to any pool.
- **Payment key as owner credential**: The payment key can still sign a delegation certificate for the stake address derived from it, since the ledger only requires a valid signature from the credential owner.
- **Script as owner credential**: The script must handle the delegation and withdrawal purposes. See [For dApp Developers](#for-dapp-developers).

### Common Pitfalls

| Pitfall | Explanation |
|---------|-------------|
| Querying by payment credential only | Returns ALL programmable token UTxOs (all holders), not just the user's. Always query by the full address including stake credential. |
| Assuming payment key signs the spend | The credential in the stake slot determines authorization. If the stake key is the owner, the stake key must sign — not the payment key. |
| Forgetting withdraw-zero invocations | The transaction will fail if the `programmable_logic_global` and `transfer_logic_script` withdrawals are missing. |
| Missing reference inputs | Both protocol params and registry node UTxOs must be included as reference inputs. Without them, the global validator cannot find its parameters or the token's transfer logic. |
| Not registering the stake address | The script stake address for `programmable_logic_global` and the `transfer_logic_script` must be registered on-chain before use. If not registered, the withdraw-zero invocation will fail at the ledger level. |
| Wrong credential convention | If the token protocol uses payment keys but the wallet constructs the address with the stake key (or vice versa), the balance will appear as zero and transfers will fail. |

---

## For Indexers and Explorers

Indexers and explorers share the core concern of reading and interpreting on-chain state. The primary difference is presentation: explorers display to humans, indexers store for API consumers. The underlying data access patterns are the same.

### Balance Tracking

#### Resolving Ownership

All programmable tokens live at addresses sharing the `programmable_logic_base` payment credential. To determine who owns what:

1. **Query all UTxOs** at the `programmable_logic_base` payment credential.
2. **Group by stake credential** — each unique stake credential represents a distinct owner.
3. **Sum token quantities** per stake credential per policy ID.

This gives you an "account-like" view of programmable token holdings.

#### Script Owners

The stake credential can be a **script hash**, not just a verification key hash. This happens when a smart contract (DEX, lending protocol, DAO treasury, etc.) holds programmable tokens. Indexers must:

- Identify script credentials (the `Script` variant) as a distinct owner type.
- Display or label them appropriately (e.g., "Smart Contract" rather than a wallet address).
- Not assume all owners are human wallet holders.

#### Credential Type Ambiguity

A `VerificationKey` credential hash in the stake slot could originate from either a payment key or a stake key. **The on-chain data does not distinguish between the two** — both appear as a 28-byte blake2b-224 hash under the `VerificationKey` constructor. Indexers cannot determine the source from the programmable address alone.

In practice:
- If the hash matches a known stake key hash from the chain's registration records, it's likely a stake key.
- If it matches a known payment key hash from other transaction witnesses, it's likely a payment key.
- Cross-referencing with known address mappings (e.g., from transaction witness sets or stake address registrations) can help disambiguate, but is not always possible.

### Transaction History

#### By Stake Address (Standard Case)

When the owner credential is a stake key, querying transaction history is straightforward:

- Filter transactions that consume or produce UTxOs at `addr(programmable_logic_base, stake_credential)`.
- This aligns with existing indexer patterns for stake address queries.

#### By Payment Key in the Stake Slot (Enterprise Address / CEX Pattern)

When an enterprise wallet (e.g., a CEX) uses its payment key as the owner credential, transaction history queries become less intuitive:

- The entity's payment key hash sits in the **stake credential position** of the programmable address.
- To find their programmable token transactions, you must query by this payment key hash **as a stake credential**, not as a payment credential.
- This inverts the usual mental model where "payment key = payment side, stake key = staking side."

**Example:**

```
CEX has payment key hash: abc123...

Standard (non-programmable) address:
  addr(abc123..., <no stake>)         -- enterprise address, query by payment cred

Programmable token address:
  addr(programmable_logic_base, abc123...)  -- abc123 is now in the stake slot!

To find CEX's programmable tokens:
  Query UTxOs where payment_cred = programmable_logic_base AND stake_cred = abc123...
```

This means indexers serving enterprise clients need to:
- Accept queries by a credential hash that might appear in the stake slot.
- Not assume that a payment key hash will only appear as a payment credential.
- Potentially offer a "query by owner credential" API that checks the stake slot of programmable addresses regardless of the credential's original role.

#### Identifying Transfer vs. Seizure Transactions

Programmable token transactions come in two flavors, distinguishable by the redeemer used:

| Transaction Type | Redeemer | Characteristics |
|-----------------|----------|-----------------|
| **Transfer** (`TransferAct`) | `TransferAct { proofs }` | Owner-authorized. Stake credential owner signed or invoked. Input and output may have different stake credentials. |
| **Seizure** (`ThirdPartyAct`) | `ThirdPartyAct { ... }` | Admin-authorized. No owner signature required. Output preserves the victim's address but removes seized tokens. |

Explorers should display these differently — a seizure is not a voluntary transfer and should be flagged as an administrative/compliance action.

### Registry State

The on-chain registry is a sorted linked list of `RegistryNode` UTxOs. Indexers should track:

- **Registered tokens**: Each node's `key` is a registered programmable token policy ID.
- **Transfer logic**: Each node's `transfer_logic_script` indicates the substandard governing the token.
- **Third-party logic**: Each node's `third_party_transfer_logic_script` indicates the admin/compliance script.
- **Global state**: Each node's `global_state_cs` may point to additional on-chain state (e.g., a denylist).

#### Compliance Events (Freeze-and-Seize Substandard)

For tokens using the freeze-and-seize substandard, indexers should additionally track:

- **Denylist changes**: Insertions (`BlacklistInsert`) and removals (`BlacklistRemove`) on the blacklist linked list.
- **Frozen addresses**: Current denylist membership indicates frozen/sanctioned credentials.
- **Seizure events**: `ThirdPartyAct` transactions where tokens are removed from a holder's UTxO.

### Common Pitfalls

| Pitfall | Explanation |
|---------|-------------|
| Attributing all tokens to the script address | Without stake-credential-level grouping, all programmable tokens appear to belong to one giant script address. Always decompose by stake credential. |
| Missing script owners | If only `VerificationKey` credentials are indexed, script-held tokens (dApps, DAOs) will be invisible. |
| Confusing payment keys in stake slots | A credential hash in the stake slot may be a payment key hash. Don't assume it corresponds to a stake address registered on-chain. |
| Treating seizures as transfers | `ThirdPartyAct` transactions are admin actions, not user-initiated transfers. They should be displayed differently and flagged for compliance. |
| Ignoring registry changes | New token registrations change which policies are programmable. An indexer that snapshots the registry once will miss newly registered tokens. |

---

## For dApp Developers

If your dApp (DEX, lending protocol, DAO treasury, escrow, etc.) needs to **hold or manage programmable tokens**, the integration model is fundamentally different from regular native tokens. The core issue: your dApp's smart contract must be the "owner" of the programmable token UTxOs, which means its script hash occupies the stake credential slot.

### Script as Owner: The Fundamental Shift

When a dApp holds programmable tokens:

```
Programmable Address = addr(programmable_logic_base, dapp_script_hash)
                                                     ─────────────────
                                                     Your dApp's script
                                                     is the "owner"
```

To authorize spending from this address, the on-chain validator requires:

```aiken
Script(_hash) -> is_script_invoked(tx, stake_cred)
```

This means your dApp's script must be **invokable as a stake validator via the withdraw-zero pattern**. Specifically:

1. **Your script must implement the `withdraw` purpose** — it will be invoked with a zero-ADA withdrawal, not as a spending validator.
2. **Your script's stake address must be registered on-chain** — the Cardano ledger requires stake address registration before any withdrawal (even zero-ADA) can occur.
3. **Your script authorizes spending** — when the programmable logic global validator sees your script hash in the stake slot, it checks that your script's credential appears in the transaction's withdrawals.

### Transaction Building

A dApp interaction with programmable tokens involves a more complex transaction than a wallet transfer, because multiple validation layers must be composed:

```
Withdrawals (all zero-ADA):
  - (programmable_logic_global, 0)        // Core CIP-113 validation
  - (transfer_logic_script, 0)            // Token-specific rules
  - (dapp_script, 0)                      // Your dApp's authorization

Reference Inputs:
  - protocol parameters UTxO
  - registry node UTxO for the token

Inputs:
  - programmable token UTxO(s) owned by dapp_script
  - (possibly) dApp's own state UTxOs

Outputs:
  - new programmable token UTxO(s) with updated ownership
  - (possibly) updated dApp state UTxOs

Redeemers:
  - programmable_logic_global: TransferAct { proofs: [...] }
  - dapp_script (withdraw): your dApp's redeemer
  - transfer_logic_script (withdraw): as required by the substandard
```

Note the three simultaneous withdraw-zero invocations. Each runs independently and must pass for the transaction to succeed.

### What Your Script Must Handle

Your dApp's stake validator (the `withdraw` handler) is the gatekeeper for all spending of programmable tokens held by your dApp. It must:

1. **Validate the business logic** — whatever your dApp's purpose is (swap, lend, vote, etc.), this is where you enforce it.
2. **Not interfere with the programmable logic chain** — your script doesn't need to re-validate registry lookups or transfer logic. The `programmable_logic_global` and `transfer_logic_script` handle that. Your script just needs to approve that the transaction is a legitimate dApp operation.

### Stake Address Registration

Before your dApp can hold or spend programmable tokens, its script stake address must be registered on-chain. This is a one-time setup step:

1. Build a transaction that includes a stake address registration certificate for your script's credential.
2. The registration requires a deposit (currently 2 ADA on mainnet).
3. Once registered, the withdraw-zero pattern can be used to invoke your script.

**If the stake address is not registered, any transaction attempting to withdraw from it (even 0 ADA) will be rejected by the ledger** — not by the validator, but by the ledger rules themselves. This is a common source of confusion.

### Delegation and Withdrawal

Since your script occupies the stake credential slot, it is technically a "staking" credential from the ledger's perspective. This means:

- **Delegation**: Your script can delegate to a stake pool if it implements delegation authorization in its certificate handler. In practice, the ADA in programmable token UTxOs is minimal (just the minimum UTxO requirement), so delegation rewards are negligible.
- **Reward withdrawal**: If rewards do accumulate, your script must authorize withdrawal. This interacts with the withdraw-zero pattern — your script's `withdraw` handler will be invoked for both zero-ADA programmable-token operations and actual reward withdrawals. Make sure your handler can distinguish between the two (e.g., by checking the withdrawal amount).

### Execution Budget Considerations

Programmable token transactions invoke multiple validators in a single transaction:

- `programmable_logic_base` (spend): runs per input
- `programmable_logic_global` (withdraw): runs once
- `transfer_logic_script` (withdraw): runs once
- Your dApp script (withdraw): runs once

Plan your execution unit budget accordingly. The global validator performs registry lookups and value summation, which can be expensive for transactions with many inputs or many distinct policy IDs. Test with realistic transaction sizes during development.

### Composability Patterns

#### Receiving Programmable Tokens

When your dApp receives programmable tokens (e.g., a user deposits into a pool):

- The output must be at `addr(programmable_logic_base, dapp_script_hash)`.
- Your dApp's script hash is the owner — later withdrawals require your script's authorization.
- The sender's transaction handles the transfer validation. Your dApp doesn't need to be invoked during deposit, only during withdrawal.

#### Releasing Programmable Tokens

When your dApp releases programmable tokens (e.g., a user withdraws from a pool):

- Your dApp's script is invoked via withdraw-zero to authorize the spend.
- The output goes to `addr(programmable_logic_base, recipient_credential)`.
- The full validation chain runs: base → global → transfer logic → your script.

#### Holding Mixed Assets

A dApp UTxO at `addr(programmable_logic_base, dapp_script_hash)` can hold both programmable and non-programmable tokens. The global validator handles this gracefully — non-programmable tokens are proven absent from the registry via `TokenDoesNotExist` proofs and skipped.

### Common Pitfalls

| Pitfall | Explanation |
|---------|-------------|
| Not implementing `withdraw` purpose | Your script must be a stake validator (or multi-purpose validator with a `withdraw` handler). A pure spending validator cannot authorize programmable token operations. |
| Forgetting stake address registration | The script's stake address must be registered on-chain before any withdraw-zero invocation. Without registration, transactions fail at the ledger level — no validator error message, just a cryptic ledger rejection. |
| Conflating zero-ADA and real withdrawals | If your script's `withdraw` handler is invoked for both programmable-token authorization (0 ADA) and actual reward withdrawal, it must handle both cases correctly. Check the withdrawal amount. |
| Not budgeting execution units | Multiple validator invocations in one transaction can exceed default budgets. Profile your transactions on testnet/preview. |
| Assuming direct UTxO spending | You don't spend programmable token UTxOs with your spending validator. You authorize via withdraw-zero. The `programmable_logic_base` is the spending validator — it just delegates to the global coordinator. |

---

**Next**: [Developing Substandards](./09-DEVELOPING-SUBSTANDARDS.md) | **Back to**: [README](../README.md)
