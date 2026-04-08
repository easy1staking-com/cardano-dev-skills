# Cardano Development Principles

Cross-cutting safety and engineering principles that apply to all skills.

## Security

- **Never expose signing keys** in code, logs, or version control. Use environment variables or secure key management.
- **Always test on devnet/testnet first.** Never deploy untested validators to mainnet. Use Yaci DevKit for local testing, Preview testnet for integration testing.
- **Validate all external inputs.** In validators, never trust datum or redeemer values without verification. Check signatures, time ranges, and value preservation.
- **Check for double satisfaction.** When multiple script inputs exist in a transaction, ensure each validator independently verifies its own conditions — never rely on another script's checks.

## Smart Contracts

- **Validators must explicitly fail.** In Aiken, use `expect` to enforce patterns and `fail` for explicit rejection. Never silently succeed.
- **Minimize on-chain logic.** Move complex computation off-chain. Validators should verify, not compute.
- **Version your datum schemas.** Include a version field in datums so contracts can evolve without breaking existing UTxOs.
- **Prefer reference scripts (CIP-33).** Attach scripts as reference inputs to avoid including them in every transaction, reducing costs.

## Transactions

- **Always set collateral** for Plutus transactions. Use a pure-ADA UTxO with sufficient value (typically 5 ADA).
- **Handle change outputs.** The eUTxO model requires explicit change — always account for the ADA returned to the sender.
- **Respect minimum UTxO value.** Every output must carry enough ADA to satisfy the min-UTxO requirement (depends on output size).
- **Use `transaction build` over `build-raw`** when using cardano-cli. The `build` command handles fee estimation and balancing automatically.

## Tooling

- **Don't assume CLI syntax.** Cardano CLI changes across versions. Always check the docs or use `--help` for the installed version.
- **Pin SDK versions.** Cardano SDKs evolve rapidly. Lock dependency versions to avoid breaking changes.
- **Prefer typed SDKs.** Use Mesh SDK or Evolution SDK (TypeScript) or cardano-client-lib (Java) for type safety over raw CLI commands.

## eUTxO Model

- **Think in UTxOs, not accounts.** There is no global state. Each UTxO is independent. Design around UTxO consumption and production.
- **Plan for concurrency.** Multiple users cannot spend the same UTxO simultaneously. Design patterns: UTxO indexing, batching, multiple validator UTxOs.
- **Datum is not storage.** Datums are attached to individual UTxOs. When a UTxO is spent, its datum is consumed. New UTxOs need new datums.
