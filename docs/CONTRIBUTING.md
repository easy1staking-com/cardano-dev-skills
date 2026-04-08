# Contributing to Cardano Dev Skills

This guide covers the full lifecycle: adding sources, adding skills, refreshing content, and quality standards.

## Adding a New Documentation Source

Sources are tracked in `registry/sources.yaml`. To add a new Cardano project:

### 1. Edit sources.yaml

Add an entry with all required fields:

```yaml
- name: Project Name
  repo: https://github.com/org/repo.git
  docs_path: docs                    # path within repo containing docs
  format: markdown                   # markdown, mdx, rst, openapi, aiken, toml
  category: infrastructure           # infrastructure, smart-contracts, sdk, standards, governance, scaling, testing
  priority: medium                   # high, medium, low
  description: Short description of the project
  # Optional fields:
  # website: https://project.dev
  # branch: main
  # glob_patterns:
  #   - "**/*.md"
  #   - "**/*.mdx"
  # format_overrides:
  #   "**/*.yaml": openapi
```

### 2. Validate

```bash
python3 scripts/validate.py
```

### 3. Open a PR

CI will validate your changes automatically.

### 4. After merge

The MCP server maintainer runs the sync script to regenerate the TypeScript source file:

```bash
./scripts/sync-sources.sh ../cardano-unified-mcp-server/src/config/sources.generated.ts
```

Then re-runs ingestion in the MCP server:

```bash
cd ../cardano-unified-mcp-server
npm run ingest -- "Project Name"
```

## Adding a New Skill

Skills are developer workflow guides in `skills/<category>/<skill-name>/SKILL.md`.

### 1. Scaffold

```bash
./scripts/new-skill.sh my-new-skill smart-contracts
```

This creates:
```
skills/smart-contracts/my-new-skill/
├── SKILL.md          # template to fill in
└── references/       # add reference docs here
```

### 2. Write the SKILL.md

Follow this structure:

```yaml
---
name: my-new-skill
description: >-
  What this skill does. Include 3-5 trigger phrases users would say.
allowed-tools: Read Grep Glob
---

# my-new-skill

## When to use
- Specific scenario 1
- Specific scenario 2

## When NOT to use
- Wrong scenario (redirect to correct skill)

## Key principles
- Domain-specific principle 1
- Domain-specific principle 2

## Workflow

### Step 1: Name
Instructions...

### Step 2: Name
Instructions...

## References
- See [reference-name](references/file.md) for details
- See shared/PRINCIPLES.md for safety guidelines
```

### 3. Quality checklist

- [ ] SKILL.md under 500 lines
- [ ] Name is kebab-case, under 64 characters
- [ ] Name matches directory name
- [ ] Description includes trigger phrases
- [ ] Has "When to use" and "When NOT to use" sections
- [ ] Has a "Workflow" section with clear steps
- [ ] No MCP dependency (no `search_docs` references)
- [ ] Deep content in `references/`, not in SKILL.md
- [ ] References are one level deep (no chaining)

### 4. Validate and submit

```bash
python3 scripts/validate.py
```

Open a PR. CI validates automatically.

### Categories

| Category | What belongs here |
|----------|-------------------|
| `smart-contracts` | Writing, reviewing, optimizing on-chain code |
| `transaction-building` | Building, designing, debugging transactions |
| `infrastructure` | Querying chain data, setting up environments |
| `governance` | CIP-1694, voting, DRep registration |
| `concepts` | Explaining eUTxO concepts, CIPs |
| `integration` | Tooling selection, wallet integration |

## Refreshing Content

### When to refresh

- A major SDK release changes APIs (e.g., Mesh SDK v2, Evolution SDK breaking changes)
- New CIPs are ratified that affect developer workflows
- New vulnerability patterns are discovered
- A referenced tool is deprecated or replaced

### How to refresh

**Skills:** Edit the relevant SKILL.md and/or reference files. Review the workflow steps — are they still accurate? Do code examples still compile?

**Sources:** Update `registry/sources.yaml` if repos have moved, renamed, or changed structure. Remove deprecated projects. Add new ones.

**MCP index:** After source changes, re-run ingestion:

```bash
cd ../cardano-unified-mcp-server

# Re-ingest a specific source
npm run ingest -- "Source Name"

# Re-ingest everything
npm run ingest

# Re-ingest by priority
npm run ingest -- --priority=high
```

### Refresh schedule (recommended)

| What | Frequency | How |
|------|-----------|-----|
| High-priority sources | Monthly | `npm run ingest -- --priority=high` |
| All sources | Quarterly | `npm run ingest` |
| Skills review | Quarterly | Manual review of each SKILL.md |
| Ecosystem scan | Quarterly | Check for new tools, deprecated tools |
| Vulnerability patterns | As discovered | Update `vulnerability-checklist.md` |

## How the MCP Server Consumes This Repo

The MCP server (`cardano-unified-mcp-server`) uses this repo in two ways:

### 1. Source registry → ingestion pipeline

```
sources.yaml  →  sync-sources.sh  →  sources.ts  →  npm run ingest
```

The sync script converts YAML to TypeScript. The ingestion pipeline clones repos, chunks docs, generates embeddings, and stores them in SQLite.

### 2. Skills → MCP prompts (future)

The MCP server can read SKILL.md files to enhance its prompt responses. A `loader.ts` module reads the SKILL.md content and registers it as MCP prompts, so Cursor and other MCP clients get the same workflows.

### Integration options

1. **Git submodule** — `git submodule add <this-repo> data/skills` in the MCP server
2. **Clone at build time** — CI clones this repo before building
3. **File path reference** — point to a local checkout during development

## Future Automation

These are tracked as potential improvements, not current requirements:

- **Release watcher:** GitHub Action that checks if source repos have new releases weekly, opens an issue if so
- **Scheduled agent:** Claude Code agent that audits skill accuracy against latest docs on a schedule
- **Auto-sync:** MCP server pulls `sources.yaml` from the published repo on startup
- **Community dashboard:** GitHub Pages site showing source health, last-indexed dates, contribution stats
