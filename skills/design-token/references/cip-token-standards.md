# Cardano Token Standards: CIP-25, CIP-68, CIP-113

Comparison of Cardano Improvement Proposals for native token metadata.

## Quick Comparison

| Feature | CIP-25 | CIP-68 | CIP-113 |
|---------|--------|--------|---------|
| Metadata location | Transaction metadata (label 721) | Datum on reference UTxO | Datum on reference UTxO |
| Updatable | No | Yes | Yes |
| On-chain behavior | No | No | Yes (transfer rules) |
| Complexity | Low | Medium | High |
| Wallet support | Universal | Growing | Early |
| Gas cost | Lower (no script) | Higher (Plutus) | Highest (Plutus + rules) |
| Token types | NFT only | NFT, FT, RFT | NFT, FT, RFT + programmable |

---

## CIP-25: NFT Metadata Standard

**Purpose:** Define a standard way to attach metadata to NFTs at mint time.

**How it works:**
- Metadata is included in the minting transaction under label `721`
- Metadata is permanently recorded in the transaction, immutable
- No on-chain UTxO is created for metadata -- it lives in tx metadata only
- Wallets and marketplaces read label 721 from the minting transaction

**When to use:**
- Simple NFTs or NFT collections
- Metadata will never need updating
- Want maximum wallet/marketplace compatibility
- Want simplest possible implementation

**Label convention:**
- Transaction metadata label: `721`

**Metadata structure:**
```json
{
  "721": {
    "<policy_id>": {
      "<asset_name_utf8>": {
        "name": "SpaceBud #1234",
        "image": "ipfs://QmXyz...",
        "mediaType": "image/png",
        "description": "A unique SpaceBud",
        "files": [
          {
            "name": "SpaceBud1234_hires.png",
            "mediaType": "image/png",
            "src": "ipfs://QmAbc..."
          }
        ],
        "<custom_field>": "<custom_value>"
      }
    }
  }
}
```

**Required fields:** `name`, `image`
**Optional fields:** `mediaType`, `description`, `files`, any custom fields

**Update mechanism:** None. Metadata is immutable once the minting transaction
is confirmed. To "update," you must burn and re-mint (new token).

---

## CIP-68: Datum Metadata Standard

**Purpose:** Enable updatable, on-chain metadata for NFTs, fungible tokens,
and rich fungible tokens using reference tokens.

**How it works:**
- Two tokens are minted simultaneously under the same policy:
  1. **Reference token** (label 100): held at a script address with metadata in its datum
  2. **User token** (label 222/333/444): held by the owner, represents the asset
- Metadata lives in the datum of the reference token's UTxO
- To update metadata: spend the reference UTxO and recreate it with new datum
- Wallets read the reference token's datum to display metadata

**When to use:**
- NFTs that need updatable metadata (e.g., game items, evolving art)
- Fungible tokens that need rich on-chain metadata
- Projects that want on-chain verifiable metadata
- Dynamic NFTs that change based on external events

**Label conventions:**

| Label | Hex Prefix | Token Type | Purpose |
|-------|-----------|------------|---------|
| 100 | `000643b0` | Reference | Holds metadata datum |
| 222 | `000de140` | NFT | User-facing NFT token |
| 333 | `0014df10` | FT | User-facing fungible token |
| 444 | `001bc280` | RFT | User-facing rich fungible token |

The asset name is constructed as: `<hex_prefix><token_name_bytes>`

Both the reference token (100) and user token (222/333/444) share the same
`<token_name_bytes>` suffix, linking them together.

**Datum structure (CBOR):**
```
121_0([ ; Constr 0
  { ; metadata map
    h'6E616D65': h'<utf8_name>',           ; "name"
    h'696D616765': h'<utf8_image_uri>',    ; "image"
    h'6D6564696154797065': h'<utf8_mime>', ; "mediaType"
    h'6465736372697074696F6E': h'<utf8>'   ; "description"
  },
  1,           ; version (integer)
  121_0([])    ; extra data (application-specific)
])
```

**Update mechanism:**
1. Spend the UTxO holding the reference token
2. Create a new UTxO at the same script address with the reference token
   and an updated datum
3. The minting policy or a separate governance script controls who can update

**Example -- minting a CIP-68 NFT pair:**
- Mint `000643b04d794e4654` (reference token: label 100 + "MyNFT")
- Mint `000de1404d794e4654` (user NFT token: label 222 + "MyNFT")
- Send reference token to script address with metadata datum
- Send user token to the buyer/owner

---

## CIP-113: Programmable Token Standard

**Purpose:** Extend CIP-68 with programmable transfer rules enforced on-chain.

**How it works:**
- Builds on CIP-68 reference token architecture
- Adds a **programmable logic script** that governs token transfers
- Every transfer of the token must satisfy the programmable logic validator
- Enables enforced royalties, KYC requirements, transfer restrictions,
  freezing, and other compliance features

**When to use:**
- Regulated/security tokens requiring transfer restrictions
- Enforced royalty payments on every transfer
- Tokens with KYC/AML compliance requirements
- Freezable or pausable tokens
- Tokens with transfer fees or caps

**How it differs from CIP-68:**
- CIP-68 reference token + user token structure is preserved
- An additional spending validator (programmable logic) must be satisfied
  for every transfer of the user token
- The programmable logic script can read the reference token datum to
  make decisions (e.g., check a whitelist, enforce royalties)

**Architecture:**

```
Minting Policy
  |
  +-- Reference Token (label 100) at script address
  |     datum: { metadata, version, programmable_logic_hash }
  |
  +-- User Token (label 222/333/444) held by owner
        transfers governed by programmable_logic validator
```

**Example use cases:**

1. **Enforced royalties:** Every transfer must include a payment to the
   creator address. The programmable logic script checks for this output.

2. **KYC whitelist:** The reference token datum contains a whitelist of
   approved addresses. The programmable logic script verifies the
   recipient is on the whitelist.

3. **Freeze mechanism:** The reference token datum contains a `frozen`
   flag. When set to `true`, the programmable logic script rejects
   all transfers.

**Metadata structure:** Same as CIP-68, with additional fields in the
`extra` section for programmable logic configuration:

```
Constr(0, [
  metadata_map,  ; same as CIP-68
  version,       ; integer
  Constr(0, [    ; extra
    programmable_logic_hash,  ; script hash
    transfer_rules            ; application-specific config
  ])
])
```

---

## Migration Paths

**CIP-25 to CIP-68:**
- Cannot update existing CIP-25 tokens (metadata is immutable)
- Burn old tokens and re-mint as CIP-68 pair
- Or maintain both standards and let users swap

**CIP-68 to CIP-113:**
- If the minting policy and reference token architecture already follow
  CIP-68, adding programmable logic is an extension
- Requires a new minting policy (new policy ID = new token)
- Plan for CIP-113 from the start if programmable features are likely

## Choosing the Right Standard

```
Do you need updatable metadata?
  No  --> CIP-25
  Yes --> Do you need on-chain transfer rules?
            No  --> CIP-68
            Yes --> CIP-113
```

For fungible tokens: CIP-68 (label 333 or 444) is always preferred over
CIP-25, as CIP-25 was designed primarily for NFTs.

For maximum compatibility today: CIP-25 has the widest wallet and
marketplace support. CIP-68 support is growing rapidly. CIP-113 is
still early-stage.
