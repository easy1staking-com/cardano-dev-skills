---
name: query-chain
description: >-
  Guides finding the best way to query Cardano blockchain data. Triggers: "query chain", "read UTxOs", "fetch blockchain data", "Blockfrost vs Ogmios", "chain indexer", "query Cardano", "get transaction data", "read on-chain state".
allowed-tools: Read Grep Glob
---

# Query Cardano Chain Data

Help the developer choose and use the right data provider for querying the Cardano blockchain.

## When to use

- Developer needs to read UTxOs, transaction history, protocol parameters, or on-chain state
- Choosing between Blockfrost, Ogmios, Kupo, Koios, Cardano GraphQL, DB-Sync, or Oura
- Setting up a data pipeline from chain data
- Querying datum or script information attached to UTxOs
- Building a backend service that needs chain data
- Comparing hosted vs self-hosted infrastructure options

## When NOT to use

- Building or submitting transactions (use transaction-building skills instead)
- Setting up a local devnet (use `setup-devnet` skill)
- Writing smart contracts (use Aiken/Plutus skills)
- Wallet integration in a frontend (use `connect-wallet` skill)

## Key principles

1. **Match the provider to the use case.** There is no single best provider. A dApp frontend has different needs than a data pipeline.
2. **Hosted APIs are faster to start; self-hosted gives control.** Blockfrost and Koios are hosted. Ogmios, Kupo, DB-Sync require running infrastructure.
3. **Combine providers when needed.** Ogmios + Kupo is a common pairing: Ogmios for tx submission and protocol params, Kupo for UTxO queries.
4. **Consider cost at scale.** Hosted APIs have rate limits and pricing tiers. Self-hosted has infrastructure cost.
5. **Think about latency requirements.** WebSocket (Ogmios) is lower latency than REST (Blockfrost). Local node queries are fastest.

## Workflow

### Step 1: Identify the context

Ask the developer (if not already clear):

- **What are you building?** (backend-service | dapp-frontend | data-pipeline | one-off-query)
- **Do you need real-time chain-tip data or historical queries?**
- **Are you running your own Cardano node?**
- **What language/SDK are you using?**

### Step 2: Evaluate providers for the context

Search the reference file for detailed provider comparisons.

```
File: skills/infrastructure/query-chain/references/provider-comparison.md
```

#### Quick decision guide

| Context | Recommended Primary | Alternative |
|---|---|---|
| **backend-service** | Ogmios + Kupo (self-hosted) or Blockfrost (hosted) | Koios (hosted, free tier) |
| **dapp-frontend** | Blockfrost (via SDK) or Koios | Ogmios via backend proxy |
| **data-pipeline** | Oura (streaming) or DB-Sync (SQL) | Cardano GraphQL |
| **one-off-query** | Koios (free, no signup) or Blockfrost | cardano-cli with local node |

### Step 3: Describe each viable option

For each provider that fits the developer's context, explain:

1. **How to set it up** -- installation, configuration, API keys
2. **How to make the query** -- specific API calls, endpoints, or queries
3. **Code example** -- using their SDK/language of choice
4. **Limitations** -- rate limits, missing data, latency

### Step 4: Provider-specific guidance

#### Blockfrost (Hosted REST API)

- Sign up at blockfrost.io for a project ID
- REST API with comprehensive endpoints
- SDKs: JavaScript, Python, Rust, Go, Java, Kotlin, Swift, Elixir
- Rate limits: free tier 50k requests/day, 10 req/s burst
- Great for: quick prototyping, frontend dApps, moderate traffic backends

```
GET /addresses/{address}/utxos
GET /txs/{hash}
GET /epochs/latest/parameters
```

#### Ogmios (Self-hosted WebSocket)

- Requires a running cardano-node
- WebSocket JSON-RPC protocol (low latency)
- Local state queries: UTxOs, protocol parameters, chain tip
- Transaction submission and evaluation
- Best for: backends co-located with a node, tx submission workflows

#### Kupo (Self-hosted HTTP indexer)

- Indexes UTxOs by address, asset, or datum hash
- Lightweight, fast, pattern-based matching
- REST API on top of indexed data
- Often paired with Ogmios for a complete solution
- Best for: UTxO lookups, datum resolution, asset queries

#### Koios (Hosted REST API, community-run)

- Free tier with generous limits
- No API key required for basic use
- Comprehensive endpoints similar to Blockfrost
- Community-maintained, decentralized backend nodes
- Best for: open-source projects, quick queries, no-signup needs

#### Cardano GraphQL (Self-hosted GraphQL)

- GraphQL interface over cardano-db-sync
- Flexible queries with relationships
- Requires DB-Sync + PostgreSQL + Hasura
- Best for: complex relational queries, custom data views

#### DB-Sync (Self-hosted PostgreSQL)

- Full blockchain data in PostgreSQL
- Direct SQL access to all chain data
- Heavy resource requirements (100GB+ disk, significant RAM)
- Best for: analytics, complex historical queries, data warehousing

#### Oura (Self-hosted pipeline)

- Event-driven pipeline from cardano-node
- Outputs to Kafka, Elasticsearch, webhooks, files
- Filters and maps chain events
- Best for: real-time event processing, data pipelines, notifications

### Step 5: Provide working code

Give the developer a working code snippet for their chosen provider and language. Always include:

- Dependency installation
- Client initialization
- The specific query they need
- Error handling
- Response parsing

### Step 6: Address common issues

- **Stale data**: Hosted APIs may lag behind chain tip by a few seconds
- **Datum resolution**: Not all providers return inline datums; may need separate lookup
- **Pagination**: Large result sets require pagination (Blockfrost pages, Kupo cursors)
- **Network selection**: Ensure provider is configured for the right network (mainnet/preprod/preview)
- **CORS**: Frontend apps need CORS-friendly endpoints or a backend proxy

## References

- `skills/infrastructure/query-chain/references/provider-comparison.md` -- Detailed comparison of all 7 providers with decision matrix
- Blockfrost docs: https://docs.blockfrost.io
- Ogmios docs: https://ogmios.dev
- Kupo docs: https://cardanosolutions.github.io/kupo
- Koios docs: https://api.koios.rest
- DB-Sync docs: https://github.com/IntersectMBO/cardano-db-sync
- Oura docs: https://github.com/txpipe/oura
