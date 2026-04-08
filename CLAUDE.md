# Cardano Dev Skills

Community-curated knowledge base for building on Cardano. This repo is a Claude Code plugin and Codex-compatible skill set.

## Repo Structure

- `registry/sources.yaml` — canonical list of Cardano projects and their documentation sources
- `skills/` — 13 developer skills organized by workflow (smart-contracts, transaction-building, infrastructure, governance, concepts, integration)
- `scripts/` — validation, sync, and scaffolding tooling
- `docs/DESIGN.md` — architectural decisions
- `docs/CONTRIBUTING.md` — how to add sources, skills, and refresh content

## Documentation Sources

The `docs/sources/` directory contains documentation extracted from 40+ Cardano projects.
When a skill or user needs to look up SDK APIs, CIP specs, or tool docs, search here first:

```
docs/sources/aiken/          # Aiken language docs
docs/sources/mesh-sdk/       # Mesh SDK API docs
docs/sources/evolution-sdk/  # Evolution SDK docs
docs/sources/cips/           # All CIP proposals
docs/sources/ogmios/         # Ogmios WebSocket bridge
...
```

Use `Read` and `Grep` tools to search these directories for accurate, up-to-date information.

## Conventions

- Skills follow the Agent Skills standard: SKILL.md with YAML frontmatter
- SKILL.md files must be under 500 lines; deep content goes in `references/` (one level deep only)
- Skill names are kebab-case, max 64 characters
- `registry/sources.yaml` is the single source of truth for documentation sources
- Skills are standalone — they must work without the MCP server
- When referencing documentation, guide the user to search or read rather than pasting specs

## Skill Format

```yaml
---
name: skill-name
description: >-
  What this skill does. Include trigger phrases.
allowed-tools: Read Grep Glob
---
```

Required sections: When to use, When NOT to use, Key principles, Workflow.

## Quality Standards

- Behavioral guidance over reference dumps
- Explain WHY, not just WHAT
- Include trade-offs and decision criteria
- Prescriptiveness scales with risk (strict for security, flexible for exploration)
- No hardcoded paths — use relative references
