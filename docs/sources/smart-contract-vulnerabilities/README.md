# Cardano Smart Contract Vulnerabilities

An open, structured knowledge base for smart contract security on Cardano's eUTxO model.

## Why This Exists

If you've built on Cardano, you've probably looked for a single reference on what can go wrong with eUTxO smart contracts. What the common vulnerability patterns are, what has actually been exploited in production, and what to check for in your own code. That reference doesn't exist yet.

The eUTxO model is fundamentally different from account-based chains. The vulnerabilities are different, the mitigations are different, and the design intuitions developers bring from other ecosystems don't apply. Security knowledge today is scattered across audit reports, blog posts, and internal checklists that most people never see.

This project brings it all together into one place. It will be useful for all of the following:

- **AI tooling** that MCP servers and agent workflows can query during development and code review
- **Security researchers and auditors** looking for a reference taxonomy grounded in real findings, not just theory
- **Developers** who need a clear map of the eUTxO security design space, common pitfalls, and best practices
- **Hackathons and developer onboarding** as a ready-made security reference baseline for fast-paced project development phases where teams need to get up to speed quickly
- **The Cardano ecosystem** as a shared foundation that raises the security baseline for everyone building on it

## What's Here

[`CARDANO-SMART-CONTRACT-VULNERABILITIES.md`](./CARDANO-SMART-CONTRACT-VULNERABILITIES.md): Known vulnerability classes for Cardano smart contracts, each with descriptions, examples, and mitigations.

[`audit-reports/`](./audit-reports/): Public Cardano smart contract audit reports, compiled to ground the vulnerability taxonomy in real-world findings.

## Audit Report Collection

This dataset is only as strong as the real-world findings behind it. We are compiling publicly available audit reports from across the Cardano ecosystem to ground the vulnerability taxonomy in production experience.

This is a collective effort. The more real findings are accessible in one place, the more developers can check their own work against known vulnerability patterns before code ever reaches an auditor. That raises the bar for everyone: developers ship safer code, auditors can focus on deeper issues, and the ecosystem grows more resilient as a whole. The initial list of firms is informed by [CIP-52](https://cips.cardano.org/cip/CIP-52) and broader ecosystem knowledge.

If you are an auditing firm or protocol team with public reports, or know of reports that should be included please open an issue.

## Related Work

- [CIP-52: Cardano Audit Best Practice Guidelines](https://cips.cardano.org/cip/CIP-52). Defines audit process standards for Cardano and maintains a registry of qualified auditing firms.
- [Cardano Developer Portal: Smart Contract Security](https://developers.cardano.org/docs/build/smart-contracts/advanced/security/overview). Aggregated educational content covering common vulnerability classes with code examples and mitigations.
