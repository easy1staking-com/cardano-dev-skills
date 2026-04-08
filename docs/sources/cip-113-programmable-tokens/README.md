# CIP-113 Programmable Tokens Implementation

A comprehensive implementation of programmable tokens for Cardano, consisting of smart contracts (Aiken) and off-chain infrastructure (Java).

## Important Disclaimers

### Origins and Attribution

This implementation builds upon the foundational work of the **CIP-143 reference implementation** originally developed by Phil DiSarro and the IOG team. The Aiken smart contracts in this repository are migrated from their Plutarch implementation.

**Original Work:**
- Repository: [input-output-hk/wsc-poc](https://github.com/input-output-hk/wsc-poc)
- Specification: [CIP-143: Interoperable Programmable Tokens](https://cips.cardano.org/cip/CIP-0143)
- Authors: Phil DiSarro, IOG Team

We are deeply grateful for the significant effort and expertise invested in the original design and implementation. Their work has provided an invaluable foundation for advancing programmable token standards on Cardano.

### CIP-113 Adaptation

This codebase has been adapted to align with the requirements of **CIP-113**, which supersedes CIP-143 as a more comprehensive standard for programmable tokens on Cardano.

**Important Note:** CIP-113 is currently under active development ([PR #444](https://github.com/cardano-foundation/CIPs/pull/444)) and has not been finalized. The specification may change as the standard evolves. This implementation reflects our current understanding and may require updates as CIP-113 matures.

### Temporary Repository

This repository serves as a **temporary home** for the codebase while we work toward establishing a permanent organizational structure. We anticipate the code will eventually be transferred to and maintained by organizations such as Pragma, Intersect, or other appropriate Cardano ecosystem entities.

---

## Repository Structure

This repository contains two main components:

### 1. Smart Contracts (Aiken)
**Location:** [`src/programmable-tokens-onchain-aiken/`](./src/programmable-tokens-onchain-aiken/)

Complete on-chain implementation of programmable tokens written in Aiken, including:
- Core validators for token custody and transfer validation
- Token registry (directory) management
- Issuance and lifecycle controls
- Example implementations (blacklist, freeze & seize)
- Comprehensive test suite (89 passing tests)

📖 **[View Detailed Documentation](./src/programmable-tokens-onchain-aiken/README.md)**

### 2. Off-Chain Infrastructure (Java)
**Location:** [`src/programmable-tokens-offchain-java/`](./src/programmable-tokens-offchain-java/)

Spring Boot application providing transaction building and blockchain integration:
- Transaction construction for protocol operations
- Blockchain data access via Blockfrost/Yaci
- Integration tests for Preview testnet
- API endpoints for protocol interactions

📖 **[View Setup Instructions](./src/programmable-tokens-offchain-java/README.md)**

---

## What Are Programmable Tokens?

Programmable tokens are native Cardano assets enhanced with customizable validation logic that executes on every transfer, mint, or burn operation. They enable:

- **Regulatory Compliance:** Enforce KYC/AML requirements, sanctions screening, transfer restrictions
- **Lifecycle Controls:** Programmatic freeze, seize, and burn capabilities
- **Custom Logic:** Pluggable validation scripts for blacklists, whitelists, time-locks, and more
- **Native Compatibility:** Full interoperability with existing Cardano wallets and infrastructure

### Use Cases
- Stablecoins with regulatory compliance
- Tokenized securities and real-world assets (RWAs)
- Regulated financial instruments
- Any token requiring programmable transfer rules

---

## Project Status

**Current Status:** Research & Development

This is high-quality research code with strong implementation:
- ✅ Core validators implemented and tested
- ✅ Registry operations functional
- ✅ Token issuance and transfer flows working
- ✅ Example freeze & seize functionality complete
- ✅ Good test coverage (89 passing tests)
- ✅ Limited testing on Preview testnet
- ⏳ Comprehensive real-world testing required
- ⏳ **Professional security audit pending**

### Security Notice

⚠️ **This code has NOT been professionally audited and is NOT production-ready.** While code quality is high, do not use with real assets or in production environments without:
- Comprehensive security audit by qualified professionals
- Extensive testing across diverse scenarios
- Thorough review by domain experts

---

## Quick Start

### Prerequisites
- [Aiken](https://aiken-lang.org/installation-instructions) v1.0.29+ (for smart contracts)
- Java 17+ and Gradle (for off-chain)
- [Cardano CLI](https://github.com/IntersectMBO/cardano-cli) (optional, for deployment)

### Build Smart Contracts
```bash
cd src/programmable-tokens-onchain-aiken
aiken build
aiken check  # Run tests
```

### Build Off-Chain Application
```bash
cd src/programmable-tokens-offchain-java
./gradlew build
```

For detailed setup, testing, and deployment instructions, see the respective README files in each subdirectory.

---

## Key Technical Concepts

**Token Registry:** An on-chain directory of registered programmable tokens implemented as a sorted linked list, enabling constant-time lookups.

**Shared Contract Address:** All programmable tokens are held at a common smart contract address, with ownership determined by stake credentials.

**Validation Scripts:** Pluggable logic for transfer validation and issuer controls, allowing customized behavior per token.

**Transaction Flow:**
1. Deploy protocol (one-time setup)
2. Register token with validation logic
3. Issue tokens
4. Transfer with automatic validation
5. Burn/seize (when authorized)

For comprehensive technical documentation, see the [Aiken implementation docs](./src/programmable-tokens-onchain-aiken/README.md).

---

## Standards and Specifications

- **CIP-143:** [Interoperable Programmable Tokens](https://cips.cardano.org/cip/CIP-0143) (Original specification, now inactive)
- **CIP-113:** [Programmable Tokens](https://github.com/cardano-foundation/CIPs/pull/444) (Active development, supersedes CIP-143)

---

## Contributing

Contributions are welcome as we develop this implementation. Please:
1. Read the technical documentation in subdirectory READMEs
2. Ensure all tests pass before submitting changes
3. Add tests for new functionality
4. Open an issue to discuss significant changes
5. Follow existing code style and patterns

---

## Resources

- 📖 [Aiken Language Documentation](https://aiken-lang.org/)
- 🎓 [CIP-143 Specification](https://cips.cardano.org/cip/CIP-0143)
- 🔗 [Cardano Developer Portal](https://developers.cardano.org/)
- 💬 [Aiken Discord](https://discord.gg/Vc3x8N9nz2)

---

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

Copyright 2024 Cardano Foundation

---

## Built With

- [Aiken](https://aiken-lang.org/) — Smart contract language for Cardano
- [MeshJS](https://meshjs.dev/) — Cardano TypeScript SDK for frontend transaction building
- [Cardano Node](https://github.com/IntersectMBO/cardano-node) — Blockchain infrastructure
- [Spring Boot](https://spring.io/projects/spring-boot) — Off-chain backend services
- [Next.js](https://nextjs.org/) — Frontend framework

---

## Acknowledgments

This project builds on the pioneering work of:
- **Phil DiSarro** and the **IOG Team** for the original Plutarch implementation
- The **CIP-143/CIP-113 authors and contributors** for standard development
- The **Aiken team** for excellent smart contract tooling
- The **Cardano developer community** for continued support

---

**Status:** Research & Development | **Not Production Ready** | **Security Audit Required**
