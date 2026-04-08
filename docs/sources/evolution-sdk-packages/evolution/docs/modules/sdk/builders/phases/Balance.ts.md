---
title: sdk/builders/phases/Balance.ts
nav_order: 137
parent: Modules
---

## Balance overview

Balance Verification Phase

Verifies that transaction inputs exactly equal outputs + change + fees.
Handles three scenarios: balanced (complete), shortfall (retry), or excess (burn/drain).

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [executeBalance](#executebalance)

---

# utils

## executeBalance

Balance Verification Phase

Verifies that transaction inputs exactly equal outputs + change + fees.
Handles three scenarios: balanced (complete), shortfall (retry), or excess (burn/drain).

**Decision Flow:**

```
Calculate Delta: inputs - outputs - change - fees
  ↓
Delta == 0?
  ├─ YES → BALANCED: Complete transaction
  └─ NO → Check delta value
          ↓
       Delta > 0 (Excess)?
          ├─ YES → Check strategy
          │         ├─ DrainTo mode? → Merge into target output → Complete
          │         ├─ Burn mode? → Accept as implicit fee → Complete
          │         └─ Neither? → ERROR (bug in change creation)
          └─ NO (Delta < 0, Shortfall) → Return to changeCreation
```

**Key Principles:**

- Delta must equal exactly 0 (balanced) or negative (shortfall) in normal flow
- Positive delta only occurs in burn/drainTo strategies (controlled scenarios)
- Shortfall means change was underestimated; retry with adjusted fee
- DrainTo merges excess into a specified output for exact balancing
- Burn strategy treats excess as implicit fee (leftover becomes network fee)
- Native assets in delta indicate a bug (should never happen with proper change creation)
- This is the final verification gate before transaction completion

**Signature**

```ts
export declare const executeBalance: () => Effect.Effect<
  PhaseResult,
  TransactionBuilderError,
  PhaseContextTag | TxContext | BuildOptionsTag
>
```
