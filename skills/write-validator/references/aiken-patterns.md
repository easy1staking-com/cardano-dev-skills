# Common Aiken Validator Patterns

Reusable code structures for common Cardano validator designs in Aiken.

## Vesting Validator

Lock funds until a deadline, then allow the beneficiary to claim.

```aiken
type VestingDatum {
  beneficiary: VerificationKeyHash,
  owner: VerificationKeyHash,
  deadline: POSIXTime,
}

type VestingRedeemer {
  Claim
  Cancel
}

validator vesting {
  spend(
    datum: Option<VestingDatum>,
    redeemer: VestingRedeemer,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum
    when redeemer is {
      Claim -> {
        let signed = list.has(tx.extra_signatories, d.beneficiary)
        let after_deadline =
          interval.is_entirely_after(tx.validity_range, d.deadline)
        signed && after_deadline
      }
      Cancel -> {
        list.has(tx.extra_signatories, d.owner)
      }
    }
  }
}
```

Key points:
- Check both signer AND deadline for Claim
- Use `is_entirely_after` to prevent time range manipulation
- Separate owner for Cancel so the funder can reclaim if needed
- No continuing output needed (funds leave the script entirely)

## Marketplace (Buy/Sell)

List an asset for sale at a fixed price.

```aiken
type ListingDatum {
  seller: Address,
  price: Int,
  policy_id: PolicyId,
  asset_name: AssetName,
}

type ListingRedeemer {
  Buy
  Cancel
}

validator marketplace {
  spend(
    datum: Option<ListingDatum>,
    redeemer: ListingRedeemer,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum
    when redeemer is {
      Buy -> {
        // Find seller payment output by address (not index)
        let seller_paid =
          list.any(
            tx.outputs,
            fn(output) {
              output.address == d.seller &&
              value.lovelace_of(output.value) >= d.price
            },
          )
        seller_paid
      }
      Cancel -> {
        // Extract payment key hash from seller address
        expect VerificationKeyCredential(seller_pkh) =
          d.seller.payment_credential
        list.has(tx.extra_signatories, seller_pkh)
      }
    }
  }
}
```

Key points:
- Find seller output by full address (payment + staking), not by index
- Beware double satisfaction when multiple listings exist -- each Buy must pay its own seller independently
- Consider adding NFT authentication to prevent datum hijacking
- Check full address to prevent staking credential theft

## Multisig

Require M-of-N signatures to spend.

```aiken
type MultisigDatum {
  signers: List<VerificationKeyHash>,
  required: Int,
}

type MultisigRedeemer {
  Spend
}

validator multisig {
  spend(
    datum: Option<MultisigDatum>,
    redeemer: MultisigRedeemer,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum
    when redeemer is {
      Spend -> {
        let valid_count =
          list.foldl(
            d.signers,
            0,
            fn(signer, acc) {
              if list.has(tx.extra_signatories, signer) {
                acc + 1
              } else {
                acc
              }
            },
          )
        valid_count >= d.required
      }
    }
  }
}
```

Key points:
- Keep the signers list bounded (e.g., max 10) to prevent unbounded datum
- Consider adding a deadline or expiration for time-limited authorization
- Consider adding an Update action to rotate signers (with current threshold approval)

## Token Minting Policy

One-time mint tied to a UTxO for uniqueness (CIP-68 compatible).

```aiken
type MintRedeemer {
  Mint
  Burn
}

validator token_mint(utxo_ref: OutputReference) {
  mint(redeemer: MintRedeemer, policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      Mint -> {
        // Consume specific UTxO to guarantee one-time mint
        let utxo_consumed =
          list.any(
            tx.inputs,
            fn(input) { input.output_reference == utxo_ref },
          )
        // Verify exact mint quantity under this policy
        let minted = value.from_minted_value(tx.mint)
        let tokens_under_policy =
          minted
            |> value.tokens(policy_id)
            |> dict.to_pairs
        // Example: allow exactly one token name with quantity 1
        let exactly_one =
          tokens_under_policy == [Pair(expected_name, 1)]
        utxo_consumed && exactly_one
      }
      Burn -> {
        let minted = value.from_minted_value(tx.mint)
        let all_negative =
          minted
            |> value.tokens(policy_id)
            |> dict.to_pairs
            |> list.all(fn(pair) { pair.2nd < 0 })
        all_negative
      }
    }
  }
}
```

Key points:
- Consuming a specific UTxO guarantees the policy can only mint once
- Always verify exact quantities and token names minted under your policy
- Separate Mint and Burn redeemer actions with different validation
- For fungible tokens with ongoing minting, use admin signature instead of UTxO consumption

## Staking Validator (Withdraw-Zero Pattern)

Use a staking validator as a shared checker for batch operations.

```aiken
validator shared_logic {
  withdraw(redeemer: BatchRedeemer, _credential: Credential, tx: Transaction) {
    // Shared validation runs once per transaction
    // instead of once per input -- saves execution cost
    validate_batch(redeemer, tx)
  }
}

// In the spending validator:
validator my_spending(staking_script_hash: ScriptHash) {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum
    // Verify the staking validator ran by checking for its withdrawal
    let staking_cred = Inline(ScriptCredential(staking_script_hash))
    let staking_ran = dict.has_key(tx.withdrawals, staking_cred)
    // Do input-specific checks here (cheap, per-input)
    staking_ran && check_input_specific(d, tx)
  }
}
```

Key points:
- The staking validator runs once per transaction, reducing total cost for batch operations
- The spending validator MUST verify the withdrawal exists in `tx.withdrawals`
- The staking validator MUST perform real validation (never just return True)
- Use this pattern for DEX order matching, batch settlements, and similar operations

## State Machine

Track state transitions with an authentication NFT.

```aiken
type State {
  Initialized
  Active
  Completed
}

type StateDatum {
  state: State,
  owner: VerificationKeyHash,
  data: Int,
  auth_token: AssetName,
}

type StateRedeemer {
  Activate
  Complete
  Cancel
}

fn valid_transition(from: State, action: StateRedeemer) -> Option<State> {
  when (from, action) is {
    (Initialized, Activate) -> Some(Active)
    (Active, Complete) -> Some(Completed)
    (Initialized, Cancel) -> None
    (Active, Cancel) -> None
    _ -> fail @"Invalid state transition"
  }
}

validator state_machine(auth_policy: PolicyId) {
  spend(
    datum: Option<StateDatum>,
    redeemer: StateRedeemer,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum
    // Resolve own input and address
    expect Some(own_input) = transaction.find_input(tx.inputs, own_ref)
    let own_address = own_input.output.address
    // Verify auth token is present in input
    expect
      value.quantity_of(own_input.output.value, auth_policy, d.auth_token) == 1
    when valid_transition(d.state, redeemer) is {
      Some(new_state) -> {
        // Find continuing output by auth token (not by index)
        expect Some(cont_output) =
          list.find(
            tx.outputs,
            fn(o) {
              o.address == own_address &&
              value.quantity_of(o.value, auth_policy, d.auth_token) == 1
            },
          )
        // Extract and verify datum transition
        expect InlineDatum(raw) = cont_output.datum
        expect cont_datum: StateDatum = raw
        // Check: state transitions correctly, immutable fields unchanged
        cont_datum.state == new_state &&
        cont_datum.owner == d.owner &&
        cont_datum.auth_token == d.auth_token
      }
      None -> {
        // Terminal action: no continuing output, owner must sign
        list.has(tx.extra_signatories, d.owner)
      }
    }
  }
}
```

Key points:
- Define valid transitions explicitly -- reject anything not listed
- Auth token prevents datum hijacking and enables output lookup by token
- Check that immutable fields (owner, auth_token) remain unchanged
- Handle terminal states (Cancel) separately -- no continuing output required
- Find continuing output by auth token presence, never by output index
