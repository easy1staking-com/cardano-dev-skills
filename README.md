# Cardano Dev Skills

Community-curated knowledge base for building on Cardano. Works as a Claude Code plugin, Codex skill set, or standalone reference.

## What's Inside

**13 developer skills** organized by workflow:

| Category | Skills |
|----------|--------|
| Smart Contracts | `review-contract`, `write-validator`, `optimize-validator` |
| Transaction Building | `build-transaction`, `design-token`, `debug-transaction` |
| Infrastructure | `query-chain`, `setup-devnet` |
| Governance | `governance-guide` |
| Concepts | `explain-eutxo`, `explain-cip` |
| Integration | `suggest-tooling`, `connect-wallet` |

**40+ documentation sources** — 2,684 files (23MB) of extracted documentation from Cardano projects, bundled in `docs/sources/` and auto-refreshed weekly via GitHub Actions.

## Installation

### Claude Code (plugin)

```bash
claude plugin add /path/to/cardano-dev-skills
```

Or add via marketplace (when published):

```bash
claude plugin marketplace add easy1staking-com/cardano-dev-skills
```

### Claude Code (project-level)

Clone into your project and skills are auto-discovered via the `.claude/skills` symlink:

```bash
git clone https://github.com/easy1staking-com/cardano-dev-skills.git
cd your-cardano-project
ln -s ../cardano-dev-skills/skills .claude/skills
```

### Codex

Skills are auto-discovered via the `.agents/skills` symlink:

```bash
git clone https://github.com/easy1staking-com/cardano-dev-skills.git
```

### Standalone

Just read the `skills/` directory — it's all Markdown.

## Usage

Once installed, skills activate automatically based on your requests:

- "Review my Aiken validator for vulnerabilities" → `review-contract`
- "Help me build a minting transaction with Mesh SDK" → `build-transaction`
- "Explain how datums work in Cardano" → `explain-eutxo`
- "What tools should I use for an NFT marketplace?" → `suggest-tooling`
- "Set up a local Cardano devnet" → `setup-devnet`

## Bundled Documentation

This repo includes **2,684 documentation files** (23MB) extracted from all 42 sources in `docs/sources/`. No external MCP server needed - Claude reads these files directly using `Read` and `Grep`.

Documentation is auto-refreshed weekly via GitHub Actions. To manually refresh:

```bash
./scripts/fetch-docs.sh
```

A `SessionStart` hook automatically checks doc freshness and notifies you if they're stale.

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for:

- How to add a new documentation source
- How to add a new skill
- How to refresh content
- Quality standards

Quick start:

```bash
# Add a new skill
./scripts/new-skill.sh my-skill-name category

# Validate everything
python3 scripts/validate.py

# Sync sources to MCP server
./scripts/sync-sources.sh path/to/mcp-server/src/config/sources.generated.ts
```

## Architecture

See [docs/DESIGN.md](docs/DESIGN.md) for all architectural decisions.

```
cardano-dev-skills/              ← this repo (self-contained)
├── registry/sources.yaml        ← what Cardano projects exist
├── skills/                      ← how to build on Cardano (13 skills)
├── docs/sources/                ← extracted docs from 42 sources (23MB)
├── hooks/                       ← SessionStart freshness check
└── scripts/                     ← fetch, validate, sync tooling
```

## License

Apache-2.0
