---
title: sdk/builders/phases/utils.ts
nav_order: 145
parent: Modules
---

## utils overview

Shared utilities for transaction builder phases

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utilities](#utilities)
  - [calculateCertificateBalance](#calculatecertificatebalance)
  - [calculateProposalDeposits](#calculateproposaldeposits)
  - [calculateWithdrawals](#calculatewithdrawals)
  - [voterToKey](#votertokey)

---

# utilities

## calculateCertificateBalance

Calculate certificate deposits and refunds from a list of certificates.

Certificates with deposits (money OUT):

- RegCert: Stake registration deposit
- RegDrepCert: DRep registration deposit
- RegPoolCert: Pool registration deposit (PoolRegistration)
- StakeRegDelegCert: Combined stake registration + delegation deposit
- VoteRegDelegCert: Combined vote registration + delegation deposit
- StakeVoteRegDelegCert: Combined stake + vote registration + delegation deposit

Certificates with refunds (money IN):

- UnregCert: Stake deregistration refund
- UnregDrepCert: DRep deregistration refund
- PoolRetirement: Pool retirement (no refund in Conway era; pool deposits are burned)

**Signature**

```ts
export declare function calculateCertificateBalance(
  certificates: ReadonlyArray<Certificate.Certificate>,
  poolDeposits: ReadonlyMap<string, bigint>
): { deposits: bigint; refunds: bigint }
```

Added in v2.0.0

## calculateProposalDeposits

Calculate total proposal deposits from proposal procedures.

Each proposal requires a deposit (govActionDeposit) which is tracked in the
ProposalProcedure structure. This deposit is deducted from transaction inputs
during balancing.

**Signature**

```ts
export declare function calculateProposalDeposits(
  proposalProcedures: { readonly procedures: ReadonlyArray<{ readonly deposit: bigint }> } | undefined
): bigint
```

Added in v2.0.0

## calculateWithdrawals

Calculate total withdrawal amount from a map of reward accounts to withdrawal amounts.

**Signature**

```ts
export declare function calculateWithdrawals(withdrawals: ReadonlyMap<unknown, bigint>): bigint
```

Added in v2.0.0

## voterToKey

Convert a Voter to a unique string key for redeemer tracking.

Key formats:

- Constitutional Committee: `cc:{credentialHex}`
- DRep (KeyHash): `drep:{keyHashHex}`
- DRep (ScriptHash): `drep:{scriptHashHex}`
- DRep (Special): `drep:AlwaysAbstainDRep` or `drep:AlwaysNoConfidenceDRep`
- Stake Pool: `pool:{poolKeyHashHex}`

This is used for:

1. Tracking redeemers by voter in Vote.ts
2. Computing vote redeemer indices in TxBuilderImpl.ts (assembly)
3. Mapping evaluation results back to voters in Evaluation.ts

The key format must match the sorting order used by Cardano ledger for
redeemer indexing (lexicographic sort of voter keys).

**Signature**

```ts
export declare function voterToKey(voter: {
  readonly _tag: "ConstitutionalCommitteeVoter" | "DRepVoter" | "StakePoolVoter"
  readonly credential?: { readonly hash: Uint8Array }
  readonly drep?: {
    readonly _tag: "KeyHashDRep" | "ScriptHashDRep" | "AlwaysAbstainDRep" | "AlwaysNoConfidenceDRep"
    readonly keyHash?: { readonly hash: Uint8Array }
    readonly scriptHash?: { readonly hash: Uint8Array }
  }
  readonly poolKeyHash?: { readonly hash: Uint8Array }
}): string
```

Added in v2.0.0
