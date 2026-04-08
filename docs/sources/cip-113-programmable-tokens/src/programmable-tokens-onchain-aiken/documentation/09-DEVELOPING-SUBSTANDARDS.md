# Developing a New Substandard

This guide is for developers who want to create new substandards for CIP-113 programmable tokens. A substandard defines the rules that govern how a specific programmable token can be issued, transferred, and managed by third parties.

**Target audience**: Cardano developers familiar with Aiken and the UTXO model who want to implement custom token compliance logic (e.g., BaFin, CMTA, or other regulatory frameworks).

---

## Table of Contents

1. [What is a Substandard?](#what-is-a-substandard)
2. [What's Already Deployed — The Core Infrastructure](#whats-already-deployed--the-core-infrastructure)
3. [What You Must Implement](#what-you-must-implement)
4. [The Withdraw-Zero Pattern](#the-withdraw-zero-pattern)
5. [Global State](#global-state)
6. [Token Lifecycle from the Substandard's Perspective](#token-lifecycle-from-the-substandards-perspective)
7. [Upgradeability](#upgradeability)
8. [Walkthrough: Dummy Substandard](#walkthrough-dummy-substandard)
9. [Walkthrough: Freeze-and-Seize Substandard](#walkthrough-freeze-and-seize-substandard)
10. [Off-Chain Integration (Mesh SDK)](#off-chain-integration-mesh-sdk)
11. [Testing Your Substandard](#testing-your-substandard)

---

## What is a Substandard?

CIP-113 follows a layered design. The **core standard** provides shared infrastructure — a token registry, a custody model, and a validation coordinator — that is deployed once and used by all programmable tokens. **Substandards** are pluggable policy modules that define the actual rules a specific token must obey.

Think of the core standard as the operating system and a substandard as an application that runs on it. Different tokens can use different substandards depending on their compliance requirements:

- A stablecoin might use a **freeze-and-seize** substandard for sanctions compliance
- A tokenized security might use a **whitelist** substandard for investor accreditation
- A regulated fund token might use a **BaFin** or **CMTA** substandard for jurisdiction-specific rules

The current implementations include:

| Substandard | Purpose | Complexity |
|-------------|---------|------------|
| **Dummy** | Minimal reference implementation | Very low — checks a redeemer value |
| **Freeze-and-Seize** | Denylist-aware transfers, token seizure | Medium — on-chain blacklist linked list |

The goal is for the community to build many more substandards for various regulatory frameworks and use cases.

---

## What's Already Deployed — The Core Infrastructure

As a substandard developer, you do **not** need to implement or modify the core CIP-113 infrastructure. The following components are deployed once by the protocol operator and shared by all programmable tokens.

Throughout this document we use two abbreviations:

- **Programmable Logic Base (PLB)** — the spending validator that custodies all programmable token UTxOs
- **Programmable Logic Global (PLG)** — the stake validator that coordinates all validation

```
┌─────────────────────────────────────────────────────────────┐
│                    CORE INFRASTRUCTURE                       │
│                 (Already deployed — don't touch)             │
│                                                             │
│  ┌─────────────────────┐  ┌──────────────────────────────┐  │
│  │ Programmable Logic   │  │ Programmable Logic Global     │  │
│  │ Base (PLB)           │  │ (PLG)                         │  │
│  │ Spending validator   │──│ Stake validator               │  │
│  │ Custodies all tokens │  │ Coordinates all validation    │  │
│  └─────────────────────┘  └──────────┬───────────────────┘  │
│                                      │                       │
│  ┌─────────────────────┐  ┌──────────┴───────────────────┐  │
│  │ Registry             │  │ Issuance Infrastructure       │  │
│  │ (mint + spend)       │  │ (issuance_mint,               │  │
│  │ Sorted linked list   │  │  issuance_cbor_hex,           │  │
│  │ of registered tokens │  │  protocol_params, always_fail)│  │
│  └─────────────────────┘  └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴──────────┐
                    │  YOUR SUBSTANDARD   │
                    │                    │
                    │  - Issuance logic  │
                    │  - Transfer logic  │
                    │  - 3rd party logic │
                    │  - State mgmt (opt)│
                    └────────────────────┘
```

### What each core component does

| Component | What it does | Why you don't touch it |
|-----------|-------------|----------------------|
| **Programmable Logic Base (PLB)** | Spending validator that custodies all programmable token UTxOs. Delegates to PLG. | Every token holder's UTxO lives at a PLB address. It's shared and immutable. |
| **Programmable Logic Global (PLG)** | Stake validator (withdraw-zero) that coordinates validation. Looks up the registry, checks ownership, invokes your substandard's validators. | This is the orchestrator. It calls *your* validators — you don't call it. |
| **Registry** | On-chain sorted linked list of all registered programmable token policies. Each entry stores which substandard validators govern that token. | Your token gets registered here, but you don't modify the registry contracts. |
| **Issuance infrastructure** | `issuance_mint` (parameterized per token), `issuance_cbor_hex_mint`, `protocol_params_mint`, `always_fail` | Handles the mechanics of minting. Your issuance logic validator is invoked *by* `issuance_mint`. |

**Key insight**: Your substandard validators are invoked by the core infrastructure, not the other way around. The PLG looks up your token in the registry, finds your validator credentials, and checks that they are present in the transaction's withdrawals.

---

## What You Must Implement

A substandard consists of **three withdraw-zero validators** (stake validators invoked via 0-ADA withdrawals):

### 1. Issuance Logic (withdraw)

Invoked when tokens are **minted or burned**. The `issuance_mint` validator checks that your issuance logic credential is present in the transaction's withdrawals:

```aiken
// From issuance_mint.ak (core infrastructure):
// list.has(invoked_scripts, minting_logic_cred)
```

Your issuance logic validator decides **who can mint and burn** tokens. This could be:
- A specific admin key must sign
- A multisig of N-of-M keys
- A DAO governance script
- Any custom logic

### 2. Transfer Logic (withdraw)

Invoked when an **owner transfers** their tokens. The PLG looks up `transfer_logic_script` from the registry and verifies it's in the transaction's withdrawals.

Your transfer logic validator decides **what conditions must be met for a transfer**. This could be:
- Check sender/recipient against a blacklist (freeze-and-seize)
- Verify both parties are on a whitelist (KYC/accreditation)
- Enforce time-locks or vesting schedules
- Any custom validation

### 3. Third-Party Transfer Logic (withdraw)

Invoked when a **third party** (not the token owner) moves tokens. The PLG looks up `third_party_transfer_logic_script` from the registry. This is used for administrative actions like:
- Seizing tokens from a sanctioned address
- Forced transfers by court order
- Emergency recovery operations

### Summary

```
┌──────────────────────────────────────────────────────────┐
│              YOUR SUBSTANDARD (3 validators)              │
│                                                          │
│  ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ │
│  │ Issuance Logic  │ │ Transfer Logic  │ │ 3rd Party    │ │
│  │ (withdraw)      │ │ (withdraw)      │ │ Logic        │ │
│  │                 │ │                 │ │ (withdraw)   │ │
│  │ Who can         │ │ Rules for       │ │ Admin        │ │
│  │ mint/burn?      │ │ owner transfers │ │ operations   │ │
│  └────────────────┘ └────────────────┘ └──────────────┘ │
│                                                          │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ State Management (optional)                          │ │
│  │ Blacklists, whitelists, config NFTs, etc.            │ │
│  │ Additional mint + spend validators as needed         │ │
│  └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

All three are registered in the **RegistryNode** when a token is registered:

```aiken
type RegistryNode {
  key: ByteArray,                              // Token policy ID
  next: ByteArray,                             // Next key (linked list)
  transfer_logic_script: Credential,           // YOUR transfer logic
  third_party_transfer_logic_script: Credential, // YOUR 3rd party logic
  global_state_cs: ByteArray,                  // YOUR global state NFT (optional)
}
```

The `minting_logic_cred` (your issuance logic) is baked into the `issuance_mint` policy as a parameter — it's not stored in the registry node but is fixed at token creation time.

> **Note**: For simple substandards, you can reuse the same validator for multiple purposes. The dummy substandard reuses `transfer` for both transfer and third-party logic. The freeze-and-seize substandard reuses `issuer_admin_contract` for both issuance and third-party logic (seizure is authorized by the same admin credential that controls minting). Design your validators based on which operations share the same authorization model.

---

## The Withdraw-Zero Pattern

All substandard validators use the **withdraw-zero pattern**. This is a Cardano technique where a stake validator is invoked by including a 0-ADA withdrawal in the transaction:

```
Transaction withdrawals:
  - (programmable_logic_global, 0 ADA)    ← Core coordinator
  - (your_issuance_logic,       0 ADA)    ← Your validator (for minting)
  - (your_transfer_logic,       0 ADA)    ← Your validator (for transfers)
```

### Why stake validators instead of spending validators?

- **Spending validators** run once **per input** — if a transaction consumes 10 UTxOs, the spending validator executes 10 times
- **Stake validators** (via withdrawal) run **once per transaction** — regardless of how many inputs

This is critical for performance. Your transfer logic might need to check a blacklist or verify signatures. Running that once per transaction instead of once per input saves significant execution units.

### What your withdraw handler receives

```aiken
withdraw(redeemer: YourRedeemerType, account: Credential, self: Transaction) {
  // redeemer  — your custom data (proofs, signatures, whatever you need)
  // account   — the credential this withdrawal is for (your validator's own credential)
  // self      — the full transaction context (inputs, outputs, withdrawals, etc.)
}
```

Your validator has full access to the transaction via `self`. It can inspect inputs, outputs, reference inputs, other withdrawals, signatories, mints — anything needed to enforce your rules.

### How it fits together

1. A user builds a transfer transaction
2. The transaction includes a withdrawal for your transfer logic validator (0 ADA)
3. The PLB spending validator checks that PLG is in the withdrawals
4. The PLG withdrawal validator looks up the token in the registry
5. The PLG verifies that your `transfer_logic_script` is also in the withdrawals
6. Your transfer logic withdrawal validator runs and either succeeds or fails
7. If all validators pass, the transaction is valid

---

## Global State

Most real-world substandards need on-chain state — blacklists, whitelists, configuration parameters, admin keys, etc. The CIP-113 registry supports this via the `global_state_cs` field in `RegistryNode`.

### How it works

`global_state_cs` is a **currency symbol** (policy ID) that your substandard uses to manage its on-chain state. The pattern is:

1. **Create a minting policy** for your state NFTs/tokens (e.g., blacklist node tokens, whitelist node tokens, config NFTs)
2. **Create a spending validator** that guards the UTxOs holding your state
3. **Store the minting policy ID** as `global_state_cs` when registering the token
4. **Read state via reference inputs** — your transfer logic validator reads state UTxOs without consuming them

### Example: Blacklist (Freeze-and-Seize)

The freeze-and-seize substandard uses `global_state_cs` to point to a blacklist:

```
global_state_cs = blacklist_mint policy ID

On-chain state:
  [BlacklistNode UTxO] → [BlacklistNode UTxO] → [BlacklistNode UTxO] → ...
  Each marked with an NFT from blacklist_mint
  Each guarded by blacklist_spend
```

During a transfer, the transfer logic validator:
1. Reads blacklist nodes as **reference inputs** (not consumed)
2. Checks that sender/recipient credentials are NOT in the blacklist
3. Uses covering-node proofs for O(1) non-membership verification

### Common state patterns

| Pattern | State Structure | Use Case |
|---------|----------------|----------|
| **Linked list** | Sorted linked list of credentials/keys | Blacklists, whitelists |
| **Config NFT** | Single UTxO with configuration datum | Admin keys, thresholds, parameters |
| **Counter** | UTxO with incrementing value | Rate limiting, supply caps |

### State management validators

If your substandard has on-chain state, you'll typically need additional validators beyond the three withdraw validators:

- **State minting policy** — controls creation/deletion of state entries (e.g., `blacklist_mint`)
- **State spending validator** — guards state UTxOs, usually just checks that the minting policy is active (e.g., `blacklist_spend`)

These are standard Aiken validators, not withdraw-zero validators. They follow typical Cardano patterns.

---

## Token Lifecycle from the Substandard's Perspective

### 1. Registration

When a new programmable token is registered, a `RegistryNode` entry is created in the on-chain registry containing:

- Your **transfer logic** credential
- Your **third-party transfer logic** credential
- Your **global state** currency symbol (if applicable)

The **issuance logic** credential is baked into the `issuance_mint` policy as a parameter at token creation time.

Registration is handled by the core infrastructure (`registry_mint`). You don't need to implement anything for this step — but your validators must be compiled and their script hashes known at registration time.

### 2. Minting

```
issuance_mint fires → checks your issuance logic is in withdrawals → your issuance logic runs
```

Your **issuance logic withdraw** validator is invoked. It should verify that the minting is authorized (e.g., admin signature, governance approval).

Tokens are minted to the PLB address with the recipient's stake credential. The `issuance_mint` validator enforces this — your substandard doesn't need to check it.

### 3. Transfer (Owner-Initiated)

```
PLB delegates to PLG → PLG looks up registry → PLG checks your transfer logic in withdrawals → your transfer logic runs
```

Your **transfer logic withdraw** validator is invoked. It receives the full transaction context and must verify that the transfer meets your rules (e.g., not blacklisted, on whitelist, within limits).

The PLG handles:
- Ownership verification (sender's stake credential signed the transaction)
- Value preservation (tokens stay at PLB addresses)
- Registry lookup

Your validator only needs to enforce your **custom rules**.

### 4. Third-Party Transfer (Admin/Compliance)

```
PLB delegates to PLG → PLG looks up registry → PLG checks your 3rd party logic in withdrawals → your 3rd party logic runs
```

Your **third-party transfer logic withdraw** validator is invoked. This path does NOT require the token owner's signature — it's for administrative actions like seizure or forced transfers.

### 5. Burning

```
issuance_mint fires → checks your issuance logic is in withdrawals → your issuance logic runs
```

Same as minting. Your **issuance logic withdraw** validator is invoked with a negative mint quantity. The same validator handles both minting and burning — you can differentiate by inspecting `self.mint` in the transaction.

### Lifecycle diagram

```
Registration ──→ Minting ──→ Transfer ──→ ... ──→ Burning
                   │            │
                   │            │
              Your issuance   Your transfer      Your issuance
              logic runs      logic runs          logic runs
                   │
                   └──→ Third-Party Transfer
                              │
                        Your 3rd party
                        logic runs
```

---

## Upgradeability

Once a token is registered, its validator credentials in the `RegistryNode` are **immutable**. The current registry implementation supports insertion (`RegistryInsert`) but not updates. This means:

**You cannot upgrade a substandard in-place for an already-registered token.**

If you need to change a substandard's logic after tokens are already in circulation, the migration path is:

1. **Pause the old token** — if your substandard supports pausing (e.g., via a global state flag), pause transfers first
2. **Deploy the new substandard** — compile and register new validator scripts
3. **Register a new token** — create a new `RegistryNode` entry with the new policy and substandard validators
4. **Migrate balances** — use either:
   - **ThirdPartyAct** on the old token to move balances from holders to a migration address, then mint equivalent new tokens
   - **Burn old + mint new** in coordinated transactions
5. **Decommission the old token** — the old registry entry remains but the token is effectively deprecated

This is an intentional design choice: immutability of validation rules provides predictability for token holders. They know exactly what rules apply to their tokens and those rules cannot change without their participation in a migration.

**Recommendation**: Design your substandard with upgradeability in mind from the start. Consider including a global state config NFT that can modify behavior (e.g., thresholds, admin keys) without changing the validator logic itself.

---

## Walkthrough: Dummy Substandard

The dummy substandard (`src/substandards/dummy/`) is the simplest possible implementation. It's a great starting point for understanding the structure.

### File structure

```
substandards/dummy/
├── aiken.toml
├── validators/
│   └── transfer.ak      ← All three validators in one file
└── lib/                  ← (empty — no custom types needed)
```

### The validators

```aiken
// substandards/dummy/validators/transfer.ak

validator issue {
  withdraw(redeemer: Int, _account: Credential, _self: Transaction) {
    trace @"withdraw"
    redeemer == 100
  }
  else(_) {
    trace @"fallback"
    False
  }
}

validator transfer {
  withdraw(redeemer: Int, _account: Credential, _self: Transaction) {
    trace @"withdraw"
    redeemer == 200
  }
  else(_) {
    trace @"fallback"
    False
  }
}
```

### What's happening

- **`issue`** — The issuance logic. Succeeds if the redeemer equals 100. That's it. Anyone who knows to pass 100 as the redeemer can mint or burn.
- **`transfer`** — The transfer logic. Succeeds if the redeemer equals 200. Any transfer that passes 200 as the redeemer is allowed.
- **Third-party logic** — The dummy substandard reuses `transfer` for third-party operations. At registration time, the same script credential is used for both `transfer_logic_script` and `third_party_transfer_logic_script`.

### Key takeaways

1. **Minimal structure**: Two `withdraw` validators in a single file — that's the absolute minimum
2. **No state**: No `global_state_cs` needed (set to empty bytes at registration)
3. **No transaction inspection**: The validators don't even look at the transaction — they just check a magic number
4. **Separate compile targets**: `issue` and `transfer` compile to separate scripts with separate script hashes

This is obviously not secure for production use, but it demonstrates the interface contract clearly.

---

## Walkthrough: Freeze-and-Seize Substandard

The freeze-and-seize substandard (`src/substandards/freeze-and-seize/`) is a real-world implementation for regulated stablecoins. It maintains an on-chain blacklist and validates every transfer against it.

### File structure

```
substandards/freeze-and-seize/
├── aiken.toml
├── validators/
│   ├── example_transfer_logic.ak   ← Transfer + third-party + issuance logic
│   ├── blacklist_mint.ak           ← Blacklist linked list management
│   └── blacklist_spend.ak          ← Guards blacklist node UTxOs
└── lib/
    ├── types.ak                    ← BlacklistNode, BlacklistProof, etc.
    ├── linked_list.ak              ← Blacklist-specific linked list ops
    └── utils.ak                    ← Utility functions
```

### The three withdraw validators

All three are in `example_transfer_logic.ak`:

#### Issuance logic: `issuer_admin_contract`

```aiken
validator issuer_admin_contract(permitted_cred: Credential) {
  withdraw(_redeemer: Data, _account: Credential, self: Transaction) {
    when permitted_cred is {
      VerificationKey(pkh) ->
        list.has(self.extra_signatories, pkh)
      Script(script_hash) -> {
        let script_cred = Script(script_hash)
        list.any(self.withdrawals, fn(wdrl) {
          let Pair(cred, _amount) = wdrl
          cred == script_cred
        })
      }
    }
  }
}
```

**What it does**: Parameterized by a credential. Minting/burning is only allowed if that credential has authorized the transaction — either via signature (for a key) or via withdrawal invocation (for a script).

#### Transfer logic: `transfer`

```aiken
validator transfer(
  programmable_logic_base_cred: Credential,
  blacklist_node_cs: PolicyId,
) {
  withdraw(proofs: List<BlacklistProof>, account: Credential, self: Transaction) {
    let witnesses =
      extract_required_witnesses(self.inputs, programmable_logic_base_cred)
    and {
      is_rewarding_script(self.redeemers, account),
      validate_witnesses(blacklist_node_cs, proofs, self.reference_inputs, witnesses),
    }
  }
}
```

**What it does**:
1. Extracts all stake credentials from programmable token inputs (the "witnesses")
2. For each witness, requires a `NonmembershipProof` — a reference to a blacklist covering node that proves the credential is NOT blacklisted
3. Validates each proof: `node.key < credential_hash < node.next`
4. If any credential IS on the blacklist, the transaction fails

**Parameterization**: Takes the PLB credential (to identify programmable inputs) and the blacklist minting policy ID (to verify blacklist node authenticity).

#### Third-party logic: `issuer_admin_contract` (reused)

The freeze-and-seize substandard reuses `issuer_admin_contract` for third-party operations — seizure is authorized by the same admin credential that controls minting. This is a deliberate design choice: the entity that can mint tokens is also the entity that can seize them.

### State management: Blacklist

The blacklist is a sorted linked list stored on-chain, managed by two additional validators:

#### `blacklist_mint`

Manages the linked list through three redeemers:

| Redeemer | Operation | Authorization |
|----------|-----------|--------------|
| `BlacklistInit` | Create origin node | One-shot (consumes a specific UTxO) |
| `BlacklistInsert { key }` | Add credential to blacklist | Manager must sign |
| `BlacklistRemove { key }` | Remove credential from blacklist | Manager must sign |

The validator enforces linked list invariants: sorted order, covering node correctness, single-mint per operation.

#### `blacklist_spend`

A minimal guard that only allows spending blacklist node UTxOs when `blacklist_mint` is active in the same transaction:

```aiken
validator blacklist_spend(blacklist_cs: PolicyId) {
  spend(_datum, _redeemer, _own_ref, self: Transaction) {
    to_dict(self.mint) |> has_key(blacklist_cs)
  }
}
```

This pattern delegates all logic to the minting policy — the spending validator just ensures the minting policy is running.

### How it all connects

```
Transfer transaction:
  Withdrawals:
    - (programmable_logic_global, 0)           ← Core coordinator
    - (transfer [PLB_cred, blacklist_cs], 0)   ← Your transfer logic

  Reference inputs:
    - Protocol params UTxO
    - Registry node UTxO (contains transfer_logic_script = transfer's credential)
    - Blacklist node UTxO(s) (covering nodes for non-membership proofs)

Blacklist management transaction:
  Mints:
    - blacklist_mint: BlacklistInsert { key: <credential_to_ban> }
  Inputs:
    - Covering node UTxO (consumed and updated)
  Outputs:
    - Updated covering node UTxO
    - New blacklist node UTxO
  Signatories:
    - Manager key
```

### Key takeaways

1. **Parameterized validators**: Transfer logic takes PLB credential and blacklist policy ID as parameters — different deployments can have different blacklists
2. **Reference inputs for state**: Blacklist is read via reference inputs, not consumed. Multiple transfers can read the same blacklist concurrently
3. **Separated concerns**: Blacklist management (mint/spend) is independent from transfer validation. You can add/remove blacklist entries without affecting transfers in progress
4. **Covering-node proofs**: O(1) non-membership verification using the sorted linked list structure

---

## Off-Chain Integration (Mesh SDK)

This section shows how to build transactions for your substandard using the [Mesh SDK](https://meshjs.dev/) (`@meshsdk/core`).

### Minting tokens

A minting transaction requires your **issuance logic withdrawal** plus the `issuance_mint` minting policy:

```typescript
import { MeshTxBuilder, integer, conStr0, conStr1, byteString, stringToHex } from "@meshsdk/core";

const txBuilder = new MeshTxBuilder({ fetcher: provider, submitter: provider, evaluator: provider });

const unsignedTx = await txBuilder
  // 1. Your issuance logic withdrawal (withdraw-zero)
  .withdrawalPlutusScriptV3()
  .withdrawal(yourIssuanceLogic.rewardAddress, "0")
  .withdrawalScript(yourIssuanceLogic.cbor)
  .withdrawalRedeemerValue(yourIssuanceRedeemer, "JSON")    // e.g., integer(100) for dummy

  // 2. The issuance_mint minting policy
  .mintPlutusScriptV3()
  .mint(quantity, issuanceMint.policyId, stringToHex(assetName))
  .mintingScript(issuanceMint.cbor)
  .mintRedeemerValue(
    conStr0([conStr1([byteString(yourIssuanceLogic.policyId)])]),
    "JSON"
  )

  // 3. Output to PLB address with recipient's stake credential
  .txOut(programmableLogicAddress, [
    { unit: "lovelace", quantity: "1500000" },
    { unit: issuanceMint.policyId + stringToHex(assetName), quantity },
  ])
  .txOutInlineDatumValue(conStr0([]), "JSON")

  .txInCollateral(collateral.input.txHash, collateral.input.outputIndex)
  .selectUtxosFrom(walletUtxos)
  .changeAddress(changeAddress)
  .complete();
```

### Transferring tokens

A transfer transaction requires your **transfer logic withdrawal** plus the **PLG withdrawal**, and reference inputs for the protocol params and registry:

```typescript
import { MeshTxBuilder, conStr0, integer, list } from "@meshsdk/core";
import { sortTxInputRefs } from "../utils/script-utils";

// Sort reference inputs — redeemer indices are based on sorted order
const allRefInputs = [
  { txHash: protocolParamsUtxo.input.txHash, outputIndex: protocolParamsUtxo.input.outputIndex },
  { txHash: registryNodeUtxo.input.txHash, outputIndex: registryNodeUtxo.input.outputIndex },
];
const sortedRefInputs = sortTxInputRefs(allRefInputs);

// Compute registry proof index from sorted position
const registryIndex = sortedRefInputs.findIndex(
  (ri) => ri.txHash === registryNodeUtxo.input.txHash
       && ri.outputIndex === registryNodeUtxo.input.outputIndex
);

const registryProof = conStr0([integer(registryIndex)]);       // TokenExists { node_idx }
const plgRedeemer = conStr0([list([registryProof])]);          // TransferAct { proofs }
const transferRedeemer = integer(200);                          // Your substandard's redeemer

const txBuilder = new MeshTxBuilder({ fetcher: provider, submitter: provider, evaluator: provider });

// 1. Spend token UTxOs from PLB address
for (const utxo of selectedUtxos) {
  txBuilder
    .spendingPlutusScriptV3()
    .txIn(utxo.input.txHash, utxo.input.outputIndex)
    .txInScript(logicBase.cbor)
    .txInRedeemerValue(conStr0([]), "JSON")
    .txInInlineDatumPresent();
}

txBuilder
  // 2. Your transfer logic withdrawal
  .withdrawalPlutusScriptV3()
  .withdrawal(yourTransferLogic.rewardAddress, "0")
  .withdrawalScript(yourTransferLogic.cbor)
  .withdrawalRedeemerValue(transferRedeemer, "JSON")

  // 3. PLG withdrawal
  .withdrawalPlutusScriptV3()
  .withdrawal(logicGlobal.rewardAddress, "0")
  .withdrawalScript(logicGlobal.cbor)
  .withdrawalRedeemerValue(plgRedeemer, "JSON")
  .requiredSignerHash(senderStakeCredential)

  // 4. Outputs
  .txOut(recipientProgrammableAddress, recipientAssets)
  .txOutInlineDatumValue(conStr0([]), "JSON");

// 5. If there's change, return it to sender's programmable address
if (returningAmount > 0) {
  txBuilder
    .txOut(senderProgrammableAddress, returningAssets)
    .txOutInlineDatumValue(conStr0([]), "JSON");
}

// 6. Reference inputs (sorted)
for (const ref of sortedRefInputs) {
  txBuilder.readOnlyTxInReference(ref.txHash, ref.outputIndex);
}

txBuilder
  .txInCollateral(collateral.input.txHash, collateral.input.outputIndex)
  .selectUtxosFrom(walletUtxos)
  .changeAddress(changeAddress);

const unsignedTx = await txBuilder.complete();
```

### Key off-chain patterns

#### Building programmable logic addresses

Recipients receive tokens at the PLB address with their stake credential:

```typescript
import { buildBaseAddress, CredentialType, deserializeAddress, Hash28ByteBase16 } from "@meshsdk/core-cst";

const recipientBase = deserializeAddress(recipientAddress).asBase();
const recipientStakeCred = recipientBase.getStakeCredential().hash;

const programmableAddress = buildBaseAddress(
  networkId,                                           // 0 = testnet, 1 = mainnet
  logicBase.policyId as Hash28ByteBase16,             // PLB script hash (payment credential)
  recipientStakeCred,                                  // Recipient's stake credential
  CredentialType.ScriptHash,                           // Payment is a script
  CredentialType.KeyHash                               // Stake is a key
).toAddress().toBech32();
```

#### Reference inputs and redeemer indices

Reference inputs are **sorted canonically** by the ledger (by transaction hash, then output index). Redeemer indices in proofs must reference the **sorted** position:

```typescript
function sortTxInputRefs(inputs: { txHash: string; outputIndex: number }[]) {
  return [...inputs].sort((a, b) => {
    const hashCmp = a.txHash.localeCompare(b.txHash);
    if (hashCmp !== 0) return hashCmp;
    return a.outputIndex - b.outputIndex;
  });
}
```

#### Substandard-specific reference inputs

If your substandard uses global state (e.g., blacklist nodes), those UTxOs must also be included as reference inputs. Remember to include them in the sorted reference input list when computing proof indices.

#### Parameterizing substandard scripts

If your validators take parameters (like the freeze-and-seize `transfer` takes `programmable_logic_base_cred` and `blacklist_node_cs`), use `applyParamsToScript`:

```typescript
import { applyParamsToScript, scriptHash } from "@meshsdk/core";

const cbor = applyParamsToScript(
  validatorCompiledCode,                    // From your blueprint (plutus.json)
  [scriptHash(plbScriptHash), scriptHash(blacklistPolicyId)],
  "JSON"
);
// Note: applyParamsToScript output is already valid CBOR — do NOT wrap it again
```

For non-parameterized validators (like the dummy substandard), the raw compiled code from the blueprint needs manual CBOR wrapping:

```typescript
import * as cbor from "cbor";
const wrappedCbor = cbor.encode(Buffer.from(scriptBytes, "hex")).toString("hex");
```

---

## Testing Your Substandard

### Unit testing withdraw validators

Test your validators in isolation using Aiken's built-in test framework. Create mock transactions that exercise your validation logic:

```aiken
// Example: testing a transfer logic validator
test transfer_allows_valid_transfer() {
  let mock_tx = Transaction {
    inputs: [...],
    reference_inputs: [...],
    outputs: [...],
    withdrawals: [Pair(my_transfer_credential, 0)],
    extra_signatories: [admin_pkh],
    ..transaction.placeholder
  }

  // Call your withdraw handler directly
  my_transfer.transfer.withdraw(my_redeemer, my_credential, mock_tx)
}

test transfer_rejects_blacklisted_sender() fail {
  let mock_tx = Transaction {
    // ... transaction with a blacklisted sender credential
    ..transaction.placeholder
  }
  my_transfer.transfer.withdraw(my_redeemer, my_credential, mock_tx)
}
```

### Testing state management

Test your minting and spending validators for linked list operations:

```aiken
test blacklist_insert_maintains_sorted_order() {
  // Build a transaction that inserts a new node
  // Verify the covering node is updated correctly
  // Verify the new node has correct key and next pointers
}
```

### Integration testing

For full integration tests that exercise the core infrastructure + your substandard together, see the test files in the core project:

- `validators/programmable_logic_global.test.ak` — Tests the full transfer/third-party flow with mock substandard validators
- `validators/programmable_logic/benchmarks.ak` — Performance benchmarks for transfer flows

### Running tests

```bash
# In your substandard directory
cd src/substandards/your-substandard/
aiken check

# Run specific test
aiken check -m validators/your_transfer_logic

# Watch mode
aiken check --watch
```

---

**Previous**: [Integration Guides](./08-INTEGRATION-GUIDES.md) | **Back to**: [README](../README.md)
