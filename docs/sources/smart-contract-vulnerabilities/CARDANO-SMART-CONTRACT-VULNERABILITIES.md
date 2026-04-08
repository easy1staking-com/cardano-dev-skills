# Cardano Smart Contract Vulnerabilities — Comprehensive Reference

A comprehensive catalogue of known vulnerability classes for Cardano/Plutus/Aiken smart contracts on the eUTxO model. Compiled from public audits (Anastasia Labs CF-IBC audit), the Cardano Developer Portal security section, and community security research.

---

## Table of Contents

1. [Double Satisfaction](#1-double-satisfaction)
2. [Missing UTxO Authentication](#2-missing-utxo-authentication)
3. [Token Dust Attack (UTxO Value Size Spam)](#3-token-dust-attack-utxo-value-size-spam)
4. [Other Redeemer](#4-other-redeemer)
5. [Other Token Name](#5-other-token-name)
6. [Unbounded Datum](#6-unbounded-datum)
7. [Unbounded Value](#7-unbounded-value)
8. [Unbounded Inputs](#8-unbounded-inputs)
9. [UTxO Contention](#9-utxo-contention)
10. [Arbitrary Datum (UTxO Datum Injection)](#10-arbitrary-datum-utxo-datum-injection)
11. [Infinite Mint / Unauthorized Minting](#11-infinite-mint--unauthorized-minting)
12. [Locked Value (Locked ADA / Locked Non-ADA)](#12-locked-value-locked-ada--locked-non-ada)
13. [Unauthorized Data Modification](#13-unauthorized-data-modification)
14. [Time Handling Vulnerabilities](#14-time-handling-vulnerabilities)
15. [Insufficient Staking Control](#15-insufficient-staking-control)
16. [Foreign UTxO Tokens](#16-foreign-utxo-tokens)
17. [Cheap Spam / DDoS on Protocol](#17-cheap-spam--ddos-on-protocol)
18. [Incorrect Parameterized Scripts](#18-incorrect-parameterized-scripts)
19. [Multisig / PK Attack](#19-multisig--pk-attack)
20. [Datum Hijacking](#20-datum-hijacking)
21. [Logic Bugs in Redeemer Validation](#21-logic-bugs-in-redeemer-validation)
22. [Reference Input Manipulation](#22-reference-input-manipulation)
23. [Missing Withdrawal Validation (Withdraw-Zero Trick)](#23-missing-withdrawal-validation-withdraw-zero-trick)
24. [Transaction Ordering / Front-Running](#24-transaction-ordering--front-running)
25. [Execution Budget Exhaustion](#25-execution-budget-exhaustion)
26. [Incomplete Output Validation](#26-incomplete-output-validation)

---

## 1. Double Satisfaction

**Severity**: Critical
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist, Tweag/MLabs research

### Description

In the eUTxO model, every validator in a transaction sees the **same** transaction context — the same inputs, outputs, mints, and withdrawals. When a transaction spends from two or more script UTxOs whose validators each expect "there exists an output paying X to address Y", a **single output** can satisfy both validators simultaneously.

### Example

Suppose two script UTxOs each hold 100 ADA and their validators each check: "an output pays at least 100 ADA back to the script address." An attacker constructs a transaction spending both UTxOs (receiving 200 ADA) but only creating **one** output of 100 ADA back to the script. Both validators see that output and pass, but the attacker pockets the other 100 ADA.

### Mitigation

- **Uniqueness tokens (NFTs)**: Require each script UTxO to carry a unique NFT. The validator checks that the *specific* output containing its NFT has the correct value. Since the NFT can only appear in one output, double satisfaction is impossible.
- **One-input-per-script rule**: Design validators so only one UTxO from the script can be consumed per transaction.
- **Tag outputs to inputs**: Require the redeemer to specify which output index corresponds to which input, and verify one-to-one mapping.
- **`expect` exact output value**: Instead of checking "at least X", check that the continuing output contains the exact expected value (minus any legitimate withdrawals).

### Real-World Impact

This is one of the most common vulnerability classes found in Cardano audits. It has been exploited in DEX and lending protocol designs.

---

## 2. Missing UTxO Authentication

**Severity**: Critical
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist

### Description

Anyone can send a UTxO to any script address with any datum. If a validator doesn't authenticate that the UTxO it's consuming was produced by a legitimate transaction, an attacker can create a **fake** UTxO at the script address with a crafted datum, then spend it to extract value or bypass logic.

### Example

A lending protocol stores loan state in a datum. The validator only checks the datum content but not whether the UTxO was created by the protocol. An attacker creates a UTxO at the script address with a forged datum saying "loan is repaid" and claims the collateral.

### Mitigation

- **Validity tokens (NFTs/state tokens)**: Every legitimate protocol UTxO must carry a minted token with a policy that can only be minted by the protocol's own minting policy. Validators check for the presence of this token.
- **Thread tokens**: Use a "thread token" pattern — an NFT minted at initialization that must be present in every valid state UTxO.
- **Parameterize with minting policy hash**: Pass the minting policy hash as a parameter and verify the UTxO carries a token from that policy.

---

## 3. Token Dust Attack (UTxO Value Size Spam)

**Severity**: Critical
**eUTxO-specific**: Yes
**Sources**: CF-IBC Audit (ID-501), Anastasia Labs checklist, Cardano Developer Portal ("Token Security", "Unbounded Value")

### Description

Cardano UTxOs can carry multiple native assets. If a script UTxO's validator doesn't restrict which tokens can be present, an attacker can add many tiny-quantity tokens ("dust tokens") to the UTxO. This:

1. **Increases transaction fees** for any future spend (larger UTxO = more bytes).
2. **Exhausts execution budgets** — iterating over a large value to find a specific token.
3. **Makes the UTxO unspendable** — if the value exceeds the max transaction size or execution limits, the UTxO is permanently locked.

### Example (from CF-IBC Audit)

```aiken
// VULNERABLE: only checks for presence, not exclusivity
pub fn contain_auth_token(output: Output, token: AuthToken) -> Bool {
  value.quantity_of(output.value, token.policy_id, token.name) == 1
}
```

This allows any number of additional tokens alongside the auth token.

### Mitigation

```aiken
// SAFE: checks that only ADA + auth token are present
pub fn contains_only_auth_token(output: Output, token: AuthToken) -> Bool {
  value.without_lovelace(output.value) ==
    value.from_asset(token.policy_id, token.name, 1)
}
```

- **Strip lovelace, compare exactly**: `value.without_lovelace(output.value) == expected_assets`
- **Count unique policies**: Assert the number of distinct policy IDs in the value.
- **Upper bound on value size**: Set a max number of distinct assets in protocol UTxOs.

---

## 4. Other Redeemer

**Severity**: Critical
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist

### Description

When a script is used at multiple UTxOs (or as both a spend and mint/withdraw validator), each invocation has its own redeemer. If the validator doesn't check **which redeemer** was used for the current purpose, an attacker can use an unexpected redeemer to bypass validation logic.

### Example

A validator supports `Redeemer::Claim` (which requires proof of ownership) and `Redeemer::Update` (which requires a signature). If the check for `Claim` is more lenient, an attacker uses `Claim` when `Update` was intended. Alternatively, if the same script hash is used as both a minting policy and a spending validator, an attacker triggers the minting validation path when the spend path should run.

### Mitigation

- **Match redeemer to purpose**: Always pattern-match on `ScriptContext.purpose` and ensure the correct redeemer variant is used.
- **Separate validators for separate purposes**: Use different script hashes for spend, mint, and withdraw unless there's a strong reason to combine them.
- **Exhaustive redeemer checks**: In Aiken, use `expect` or `when/is` with all variants handled — don't use catch-all `_` for redeemer pattern matching.

---

## 5. Other Token Name

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist

### Description

A minting policy validates that a specific token name can be minted. But if it doesn't check **all** token names being minted under its policy ID, an attacker can mint additional unauthorized tokens in the same transaction.

### Example

A policy checks: "exactly 1 of token name `STATE_TOKEN` is minted." But it doesn't verify that no other token names are minted under the same policy. The attacker mints `STATE_TOKEN` (passes validation) **and** `ATTACKER_TOKEN` (unchecked) in the same mint field.

### Mitigation

- **Check the entire mint for your policy**: Flatten the minted value for your policy ID and verify it contains exactly the expected tokens.

```aiken
// Check that ONLY the expected token name is minted under this policy
let minted = value.from_minted_value(tx.mint)
let policy_tokens = value.tokens(minted, own_policy_id)
expect dict.to_pairs(policy_tokens) == [(expected_name, expected_qty)]
```

- **Alternatively, check the count of distinct asset names** under your policy.

---

## 6. Unbounded Datum

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist

### Description

If protocol state stored in a datum can grow without limit (e.g., a list that gets appended to indefinitely), eventually:

1. The datum size exceeds the maximum transaction size (~16 KB).
2. Deserializing the datum exhausts the execution budget.
3. The UTxO becomes unspendable — the funds are permanently locked.

### Example

A protocol stores a list of all registered users in the datum. After thousands of registrations, the datum becomes too large to fit in a transaction, permanently locking the UTxO.

### Mitigation

- **Bounded data structures**: Use fixed-size datums. Store counts/hashes instead of full lists.
- **Off-chain indexing**: Keep large datasets off-chain; store only Merkle roots or hashes on-chain.
- **Linked-list pattern**: Split state across multiple UTxOs using a linked-list pattern (each UTxO points to the next), so no single datum grows unboundedly.
- **Hard cap**: Enforce a maximum size in the validator before allowing datum growth.

---

## 7. Unbounded Value

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist

### Description

Similar to unbounded datums, but for the `Value` field of a UTxO. If a protocol accumulates many different native tokens in a single UTxO (e.g., a liquidity pool receiving many token types), the serialized value can exceed transaction limits.

### Mitigation

- **Cap the number of distinct assets** in any protocol UTxO.
- **Reject unknown tokens**: Validators should ensure continuing outputs contain only expected assets (see Token Dust Attack).
- **Split state**: Use multiple UTxOs to avoid concentrating too many assets in one.

---

## 8. Unbounded Inputs

**Severity**: Medium
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal

### Description

If a validator requires consuming many UTxOs simultaneously (e.g., collecting all staking rewards, processing a batch), the transaction may exceed the maximum input count or execution budget.

### Mitigation

- **Batched processing**: Design protocols so operations can be performed in chunks across multiple transactions.
- **Reduce fan-in**: Avoid designs that require consuming many UTxOs atomically.

---

## 9. UTxO Contention

**Severity**: Medium–High
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist, CF-IBC Audit (ID-502)

### Description

When multiple users need to spend the same UTxO (e.g., a global state UTxO), only one transaction per block can succeed. Others are rejected. This creates a bottleneck and degrades throughput under load.

### CF-IBC Audit Example (ID-502)

The IBC `HandlerDatum` maintained global counters for client/connection/channel IDs. Every TAO component creation required spending the same Handler UTxO, creating a severe contention bottleneck. A malicious actor could also exploit this for DoS by continuously spending the handler UTxO.

### Mitigation

- **Eliminate global state**: Use unique identifiers derived from transaction inputs (e.g., `hash(txHash + outputIndex)`) instead of global counters.
- **Parallel state UTxOs**: Distribute state across multiple UTxOs so different users can operate on different ones.
- **Batching**: Allow off-chain aggregation and batch on-chain updates.
- **Reference inputs (CIP-31)**: Read shared state without consuming it, reducing contention (though writes still require consumption).

---

## 10. Arbitrary Datum (UTxO Datum Injection)

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist

### Description

When tokens are sent to a script address (e.g., by another script or a user), the datum attached to that UTxO may not be validated. If the spending validator later trusts the datum content, an attacker can craft a UTxO with a malicious datum.

### Mitigation

- **Validate datum on output**: If your script produces outputs to a script address, validate the datum before creating the output.
- **Validate datum on input**: Never trust datum content without verification. Cross-check datum fields against expected values, signatures, or proofs.
- **Combine with UTxO authentication** (see #2): Authenticate that the UTxO was produced by a trusted source.

---

## 11. Infinite Mint / Unauthorized Minting

**Severity**: Critical
**eUTxO-specific**: No (but eUTxO-flavored)
**Sources**: Anastasia Labs audit checklist, CF-IBC Audit (ID-203)

### Description

A minting policy that doesn't properly restrict **who** can mint and **when** allows an attacker to create unlimited tokens. This can crash the token's economy or enable exploits in protocols that trust token quantities.

### CF-IBC Audit Example (ID-203 — Unintended Voucher Minting)

The voucher minting policy allowed minting during both acknowledgement results and errors, but should have only allowed minting on errors (refund case). This enabled draining locked tokens by repeatedly sending and "refunding."

### Mitigation

- **One-shot minting**: Use the "one-shot" pattern — check that a specific UTxO is consumed, making the mint unrepeatable.
- **Admin signatures**: Require a specific key signature for minting.
- **Strict redeemer checks**: Validate the exact circumstances under which minting is allowed (e.g., only on error acknowledgements, not success).
- **Close the policy**: For fixed-supply tokens, burn the minting capability after initial mint.

---

## 12. Locked Value (Locked ADA / Locked Non-ADA)

**Severity**: Medium–Critical
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal, Anastasia Labs audit checklist, CF-IBC Audit (ID-505)

### Description

Value sent to a script address can become permanently unrecoverable if:

1. No valid redeemer or transaction can satisfy the validator's conditions.
2. The minimum ADA requirement locks dust amounts that can never be retrieved.
3. A bug prevents the last tokens from being withdrawn (e.g., division rounding errors in pools).
4. Script execution budget is exhausted before validation completes.

### CF-IBC Audit Example (ID-505)

If an IBC channel was incorrectly opened or closed, escrowed assets could become permanently locked with no validator path to recover them.

### Mitigation

- **Emergency recovery path**: Include an admin-controlled escape hatch for recovering locked funds (with appropriate access controls).
- **Minimum remaining balance checks**: Ensure protocol math doesn't leave unrecoverable dust.
- **Audit all validator paths**: Verify that for every way tokens can enter a script, there's a way to get them out.
- **Test edge cases**: Zero balances, minimum ADA, last-token-withdrawal.

---

## 13. Unauthorized Data Modification

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: Anastasia Labs audit checklist

### Description

When a script UTxO is spent and a continuing output is created with an updated datum, the validator must ensure that **only authorized fields** were changed and that the changes are valid. If the validator checks some fields but not others, an attacker can modify unchecked fields.

### Mitigation

- **Whitelist allowed changes**: Explicitly enumerate which datum fields can change under each redeemer, and assert all other fields are identical.
- **Derive new datum deterministically**: Compute the expected new datum from the old datum + redeemer, and assert the output datum matches exactly.

---

## 14. Time Handling Vulnerabilities

**Severity**: Medium
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal

### Description

Cardano transactions have a validity range (`valid_from`, `valid_to`) expressing an **interval**, not a point in time. Validators receive `tx.validity_range` which is a `PosixTimeRange`. Common mistakes:

1. **Using the wrong bound**: Checking `valid_from` when `valid_to` should be used (or vice versa).
2. **Off-by-one errors**: Intervals are typically half-open `[from, to)`. Mixing inclusive/exclusive bounds causes edge-case exploits.
3. **Missing bound**: If `valid_to` is `+Infinity`, a deadline check using `valid_to` is meaningless.
4. **Slot-to-time conversion**: The slot length can change across hard forks; hardcoded conversions break.

### Mitigation

- **Require finite bounds**: Assert that the relevant validity bound is set (not `+/-Infinity`).
- **Use the correct bound for the check**:
  - "Must happen before deadline" → check `valid_to < deadline` (if tx is valid, it's definitely before deadline)
  - "Must happen after start" → check `valid_from >= start`
- **Test boundary conditions**: Test at exactly the deadline, one slot before, one slot after.

---

## 15. Insufficient Staking Control

**Severity**: Medium
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal

### Description

Script addresses can have staking credentials. If the staking credential isn't properly controlled, attackers can:

1. **Redirect staking rewards**: Register the script address with their own staking credential and collect rewards.
2. **Use the withdraw-zero trick** (see #23) maliciously if not accounted for.
3. **Deregister stake credentials**: Causing protocol disruptions if the script relies on being staked.

### Mitigation

- **Explicitly set staking credentials**: Use a known credential (admin key or script) for the staking part of script addresses.
- **Validate stake operations**: If your protocol interacts with staking, validate delegation and withdrawal operations.

---

## 16. Foreign UTxO Tokens

**Severity**: Medium–High
**eUTxO-specific**: Yes
**Sources**: Anastasia Labs audit checklist, CF-IBC Audit (ID-504)

### Description

When a validator checks the value of a continuing output, it might only verify specific tokens (e.g., "at least 100 ADA and 1 auth token"). If an attacker adds other protocol-relevant tokens to the same UTxO (e.g., tokens from a different part of the protocol), those tokens become locked or their presence confuses other validators.

### CF-IBC Audit Example (ID-504)

The transfer module escrow could accumulate tokens from multiple channels/ports. If a token on one channel had the same denomination as another channel, an exploit could drain tokens belonging to the other channel.

### Mitigation

- **Exact value matching**: Check that the output contains exactly the expected assets and nothing more.
- **Separate escrow per context**: Don't mix tokens from different protocol contexts in the same UTxO.
- **Namespace tokens**: Use unique identifiers (port-channel pairs, etc.) to prevent cross-context confusion.

---

## 17. Cheap Spam / DDoS on Protocol

**Severity**: Medium–High
**eUTxO-specific**: Partially
**Sources**: Cardano Developer Portal, CF-IBC Audit (ID-502, ID-506)

### Description

If protocol operations are cheap to trigger but expensive to process, an attacker can spam the protocol. On Cardano specifically:

- **Global state contention** (see #9): Spamming transactions that spend the global state UTxO, preventing legitimate users from interacting.
- **Creating many protocol UTxOs**: If creation is cheap, an attacker can create thousands of UTxOs the protocol must track.
- **Channel/connection flooding** (ID-506): Creating many dummy channels to waste protocol resources.

### Mitigation

- **Require deposits**: Make protocol operations require a non-trivial ADA deposit, refundable only on legitimate completion.
- **Rate limiting via design**: Use designs that don't have a single contention point.
- **Prune/expire stale state**: Allow cleaning up old/abandoned protocol state.

---

## 18. Incorrect Parameterized Scripts

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: Anastasia Labs audit checklist

### Description

Parameterized scripts (validators that take compile-time parameters) can have incorrect parameter application. Common issues:

1. **Wrong parameter order**: Parameters applied in wrong order, producing a valid but incorrect script hash.
2. **Double CBOR encoding**: Applying parameters already CBOR-encodes the result; manually encoding again produces wrong bytecode.
3. **Parameter type mismatch**: A parameter is the wrong type but still deserializes without error (e.g., wrong hash used).
4. **Stale parameters**: Using parameters from a different deployment, producing an address that doesn't match on-chain.

### Mitigation

- **Verify script hashes**: After parameterization, compare the resulting script hash against the expected on-chain hash.
- **Don't double-encode**: `applyParamsToScript` output is already valid CBOR.
- **Use typed parameters**: Leverage Aiken's type system to prevent parameter mismatches.
- **Fetch from authoritative source**: Always get script bytecode from the deployment API, not static config files.

---

## 19. Multisig / PK Attack

**Severity**: Medium
**eUTxO-specific**: No
**Sources**: Anastasia Labs audit checklist

### Description

In multi-signature schemes on Cardano, common vulnerabilities include:

1. **Insufficient signer threshold**: Requiring too few signatures for critical operations.
2. **Key reuse across purposes**: Using the same key pair for multiple protocol roles.
3. **Missing signer verification**: Checking that N signatures exist but not verifying they're from distinct authorized keys.

### Mitigation

- **Verify distinct signatories**: When checking `tx.extra_signatories`, ensure the required keys are distinct.
- **Minimum threshold**: Use Cardano's native multi-sig with appropriate thresholds.
- **Separate keys per role**: Use different key hashes for different protocol roles (admin, operator, etc.).

---

## 20. Datum Hijacking

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: MLabs audit guidelines, community research

### Description

A validator checks that a continuing output goes to the correct script address and has a valid datum, but an attacker redirects the output to their own script address (which has the same validation rules or a trivially satisfiable validator). The attacker's script can then spend the funds freely.

### Mitigation

- **Verify exact output address**: Check that the continuing output goes to exactly the expected script address (derived from the known script hash).
- **Include address in datum verification**: If the protocol uses reference scripts, verify the script hash matches.

---

## 21. Logic Bugs in Redeemer Validation

**Severity**: Variable (Medium–Critical)
**eUTxO-specific**: No
**Sources**: General audit practice

### Description

Standard programming logic errors in validator code:

- **Off-by-one errors**: `>=` vs `>`, incorrect loop bounds.
- **Integer overflow/underflow**: Aiken uses arbitrary-precision integers, but Plutus V1/V2 also have Integer which doesn't overflow. However, logic can still be wrong (e.g., negative amounts).
- **Missing negation**: `and` vs `or`, inverted boolean checks.
- **Incomplete pattern matching**: Using `_` catch-all that accepts unexpected redeemer variants.
- **Short-circuit evaluation**: In Aiken, `and { ... }` short-circuits. If conditions are ordered wrong, critical checks may be skipped.

### Mitigation

- **Exhaustive pattern matching**: Handle all redeemer/datum variants explicitly.
- **Property-based testing**: Use QuickCheck-style testing to explore edge cases.
- **Formal verification**: For critical validators, consider formal verification tools.

---

## 22. Reference Input Manipulation

**Severity**: Medium
**eUTxO-specific**: Yes (Plutus V2+)
**Sources**: Community research, CIP-31

### Description

Reference inputs (CIP-31) allow reading a UTxO without consuming it. Vulnerabilities arise when:

1. **Unauthenticated reference inputs**: The validator reads data from a reference input but doesn't verify the reference UTxO is legitimate (e.g., at the correct address, with correct authentication token).
2. **Stale reference data**: The reference input may contain outdated state if the referenced UTxO has been spent and recreated between transaction construction and validation.
3. **Reference input substitution**: An attacker provides a different UTxO as a reference input with crafted data.

### Mitigation

- **Authenticate reference inputs**: Verify the reference UTxO carries the expected authentication token and is at the expected address.
- **Bind to specific UTxO**: If possible, specify the exact UTxO reference (tx hash + index) in the redeemer or datum.

---

## 23. Missing Withdrawal Validation (Withdraw-Zero Trick)

**Severity**: Medium
**eUTxO-specific**: Yes
**Sources**: CF-IBC Audit (ID-202), community patterns

### Description

The "withdraw-zero" trick is a Cardano design pattern where a staking script is used as a global validator by adding a zero-ADA withdrawal to the transaction. The staking script executes and can enforce global invariants. However:

1. **Not using the trick when needed**: If validators need to enforce cross-input or global invariants but don't use a global validation mechanism, they may have incomplete checks.
2. **Missing withdrawal in transaction**: If the protocol expects a withdrawal to trigger global validation but doesn't enforce its presence, an attacker can omit it.
3. **Incorrect withdrawal redeemer index**: The redeemer index for withdrawals must match the canonical (sorted) ordering of reward addresses in the transaction.

### CF-IBC Audit Example (ID-202)

The audit recommended using the withdraw-zero pattern for protocol token minting policies to avoid having the minting policies execute independently without global state validation.

### Mitigation

- **Enforce withdrawal presence**: If your protocol uses the withdraw-zero pattern, validators should check that the withdrawal is present in the transaction.
- **Sort withdrawal addresses**: When building transactions with multiple withdrawals, sort reward addresses and assign redeemer indices accordingly (MeshSDK has a known bug here — see project MEMORY.md).

---

## 24. Transaction Ordering / Front-Running

**Severity**: Medium
**eUTxO-specific**: Partially
**Sources**: General blockchain security, Cardano Developer Portal

### Description

While Cardano's eUTxO model is less susceptible to front-running than account-based models (because transactions are deterministic), issues still arise:

1. **Block producer ordering**: Block producers choose transaction order within a block. A malicious producer could prioritize their own transactions.
2. **Contention races**: When multiple users compete for the same UTxO, submission timing matters (see #9).
3. **Sandwich attacks**: In DEX transactions, an attacker can observe a pending swap and submit transactions before and after it to profit.

### Mitigation

- **Deterministic execution**: Cardano transactions have deterministic outcomes, which inherently limits front-running.
- **Limit slippage**: DEX protocols should allow users to set slippage limits.
- **Batching**: Process multiple operations in a single transaction to reduce ordering sensitivity.

---

## 25. Execution Budget Exhaustion

**Severity**: Medium–High
**eUTxO-specific**: Yes
**Sources**: Cardano Developer Portal ("Token Security"), audit practice

### Description

Cardano transactions have strict execution budget limits (CPU steps and memory units). If a validator's worst-case execution cost exceeds these limits, the UTxO becomes unspendable. Causes include:

1. **Large data structures**: Iterating over large lists in datums or values.
2. **Expensive cryptographic operations**: Multiple signature verifications or hash computations.
3. **Nested loops**: Quadratic or worse complexity in validator logic.
4. **Unbounded recursion**: Recursive functions without depth limits.

### Mitigation

- **Benchmark validators**: Test with maximum expected data sizes and verify execution stays within limits.
- **Use efficient algorithms**: Prefer `O(n)` over `O(n^2)`. Use indexed lookups (via redeemer hints) instead of linear search.
- **Limit data size**: Enforce bounds on datum lists, value sizes, etc. (see #6, #7).
- **Optimize hot paths**: Use Aiken's built-in optimizations and avoid unnecessary computations.

---

## 26. Incomplete Output Validation

**Severity**: High
**eUTxO-specific**: Yes
**Sources**: General audit practice

### Description

A validator checks that a continuing output exists with the right datum and value but doesn't verify:

1. **Output address**: The output goes to the correct script address (not a different address controlled by the attacker).
2. **Number of outputs**: The validator expects one continuing output but the attacker creates multiple, splitting value.
3. **Output ordering**: The validator assumes a specific output index but the attacker reorders outputs.
4. **Reference script**: If using reference scripts, the validator doesn't verify the attached script hash.

### Mitigation

- **Verify address, value, AND datum** of every continuing output.
- **Use redeemer to specify output indices**: Have the redeemer declare which output corresponds to the continuing UTxO, then verify all properties.
- **Count outputs**: If exactly one continuing output is expected, verify there's exactly one output to the script address.

---

## Appendix A: Vulnerability Checklist (from Anastasia Labs Audit Methodology)

The following checklist was used in the CF-IBC security audit and represents a comprehensive assessment framework:

| # | Vulnerability Class | Severity Potential |
|---|---|---|
| 1 | UTxO Value Size Spam (Token Dust Attack) | Critical |
| 2 | Large Datum or Unbounded Protocol Datum | High |
| 3 | eUTxO Concurrency DoS | Medium–High |
| 4 | Unauthorized Data Modification | High |
| 5 | Multisig PK Attack | Medium |
| 6 | Infinite Mint | Critical |
| 7 | Incorrect Parameterized Scripts | High |
| 8 | Other Redeemer | Critical |
| 9 | Other Token Name | High |
| 10 | Arbitrary UTxO Datum | High |
| 11 | Unbounded Protocol Value | High |
| 12 | Foreign UTxO Tokens | Medium–High |
| 13 | Double or Multiple Satisfaction | Critical |
| 14 | Locked ADA | Medium–Critical |
| 15 | Locked Non-ADA Values | Medium–Critical |
| 16 | Missing UTxO Authentication | Critical |
| 17 | UTxO Contention | Medium–High |

## Appendix B: Cardano Developer Portal Categories

Source: https://developers.cardano.org/docs/build/smart-contracts/advanced/security/overview

| # | Category | Key Concern |
|---|---|---|
| 1 | Double Satisfaction | Shared tx context lets one output satisfy multiple validators |
| 2 | Missing UTxO Authentication | Fake UTxOs at script addresses |
| 3 | Time Handling | Interval vs point-in-time misuse |
| 4 | Token Security | Dust attacks, validation token weaknesses |
| 5 | Unbounded Value | Growing value locks UTxOs |
| 6 | Unbounded Datum | Growing datum locks UTxOs |
| 7 | Unbounded Inputs | Too many inputs exceed limits |
| 8 | Other Redeemer | Wrong redeemer bypasses logic |
| 9 | Other Token Name | Unauthorized token names minted |
| 10 | Arbitrary Datum | Invalid datums at script addresses |
| 11 | UTxO Contention | Race conditions on shared state |
| 12 | Cheap Spam | Low-cost protocol disruption |
| 13 | Insufficient Staking Control | Staking reward theft |
| 14 | Locked Value | Permanently inaccessible funds |

## Appendix C: References

1. **Anastasia Labs CF-IBC Audit Report v1** (December 2024) — Security audit of Cardano Foundation IBC implementation. Contains 38 findings across critical, major, medium, minor, and informational severity.
2. **Cardano Developer Portal — Smart Contract Security Overview**: https://developers.cardano.org/docs/build/smart-contracts/advanced/security/overview
3. **Well-Typed / Tweag — Common Plutus Vulnerabilities**: Research on double satisfaction, datum hijacking, and other eUTxO-specific attack vectors.
4. **MLabs Plutus Audit Guidelines**: Industry-standard checklist for Plutus/Aiken smart contract security reviews.
5. **CIP-31 (Reference Inputs)**: https://cips.cardano.org/cip/CIP-0031 — Introduces reference inputs and their security considerations.
6. **Anastasia Labs Blog — Cardano Smart Contract Security**: Best practices for eUTxO validator design.
