# Design Decisions

This document captures the architectural decisions behind `cardano-dev-skills`. It records what was decided, why, and what alternatives were considered.

## Decision 1: Two repos, not one

**Decision:** Keep the knowledge base (`cardano-dev-skills`) and the MCP server (`cardano-unified-mcp-server`) as separate repositories.

**Why:**
- **Security.** The knowledge base is pure content (YAML, Markdown). Anyone can fork, audit, and contribute without reviewing server code. Users downloading the skills repo don't execute arbitrary TypeScript.
- **Different audiences.** Content contributors (Cardano developers) don't need to understand MCP infrastructure. Infrastructure maintainers don't need to curate documentation.
- **Different cadences.** Skills and sources change with the ecosystem. Server code changes with protocol and tooling updates.

**Alternative considered:** Monorepo with both. Rejected because it couples content contributions to infrastructure reviews and creates a security concern for users who just want the knowledge base.

## Decision 2: Skills grouped by developer workflow

**Decision:** Organize skills into 6 workflow categories: `smart-contracts`, `transaction-building`, `infrastructure`, `governance`, `concepts`, `integration`.

**Why:** Developers think in terms of "what am I trying to do?" not "what category is this tool in?" A developer building an NFT marketplace needs `write-validator` + `build-transaction` + `connect-wallet` — these map to workflows, not to the registry's source categories.

**Alternative considered:** Mirror the registry's 7 categories (infrastructure, smart-contracts, sdk, standards, governance, scaling, testing). Rejected because skills like `build-transaction` span multiple source categories (SDKs + standards + infrastructure).

## Decision 3: YAML registry, not TypeScript

**Decision:** The canonical source list is `registry/sources.yaml`, not a TypeScript file.

**Why:** Lower contribution barrier. A Cardano developer who wants to add a new project doesn't need to know TypeScript or the MCP server's type system. YAML is universally readable and editable. A sync script generates the TypeScript for the MCP server.

**Sync flow:**
1. Community PRs update `sources.yaml`
2. CI validates the YAML schema
3. MCP server maintainer runs `scripts/sync-sources.sh` to regenerate `sources.ts`

## Decision 4: Skills are standalone

**Decision:** Skills must work without the MCP server. No skill references `search_docs` or any MCP-specific tool.

**Why:**
- Users who install just the skills plugin (without the MCP server) should still get useful guidance.
- Skills that depend on MCP break for Codex users, Cursor users, or anyone without the server running.
- Skills guide the workflow; the MCP server provides supplementary data. If both are available, the experience is richer but not required.

**How it works:** Skills use `allowed-tools: Read Grep Glob` — Claude searches local documentation, the user's codebase, or its own knowledge. If the MCP server is also connected, Claude can additionally call `search_docs` for deeper lookups, but the skill doesn't require it.

## Decision 5: Progressive disclosure

**Decision:** SKILL.md files are capped at 500 lines. Deep reference content goes in `references/` subdirectories, one level deep only.

**Why:**
- **Context budget.** At session start, Claude loads only the name + description of each skill (~100 tokens per skill, ~1,300 tokens for 13 skills). When a skill activates, the full SKILL.md loads (~2,000 tokens). References load only on demand. This keeps context usage manageable.
- **Maintainability.** A 500-line file is reviewable in a single PR. A 2,000-line file is not.
- **Trail of Bits pattern.** Their production skills follow this exact structure and it works at scale (35+ plugins, 100+ skills).

## Decision 6: Agent Skills standard compliance

**Decision:** Follow the Agent Skills open standard for SKILL.md format — YAML frontmatter with `name`, `description`, `allowed-tools`, and structured markdown body.

**Why:**
- Compatible with Claude Code plugins (`.claude-plugin/` + `skills/`)
- Compatible with Codex (`.agents/skills/` symlink)
- Future-proof for other tools that adopt the standard
- Established quality standards (naming conventions, description requirements, section structure)

**Cross-tool compatibility:** Symlinks handle multi-tool support without file duplication:
- `.claude/skills` → `../skills` (Claude Code project-level discovery)
- `.agents/skills` → `../skills` (Codex discovery)
- Plugin installation (`/plugin add`) uses `skills/` directly

## Decision 7: Single source of truth flow

**Decision:** Content flows one direction: `cardano-dev-skills` → `cardano-unified-mcp-server`.

```
cardano-dev-skills/                    WRITES
  registry/sources.yaml          ──→   MCP sources.ts (via sync script)
  skills/*/SKILL.md              ──→   MCP prompts (via loader at startup)

cardano-unified-mcp-server/            READS
  src/config/sources.ts          ←──   generated from sources.yaml
  src/tools/prompts.ts           ←──   reads SKILL.md content
```

**Why:** Eliminates drift. There is exactly one place to update a source entry or a skill's workflow. The MCP server is a consumer, not a peer.

## Decision 8: Content authored from scratch

**Decision:** Skill content is written by humans (or AI-assisted), not extracted from the MCP server's chunked/embedded data.

**Why:**
- MCP chunks are optimized for retrieval, not for teaching. They're fragments, not workflows.
- Skills need behavioral guidance ("when to use X over Y", "check for Z before doing W") that doesn't exist in raw documentation.
- Freshness: skills are written against current best practices, not against whatever was last indexed.

## Decision 9: Future lifecycle automation

**Decision:** Document but don't over-engineer the refresh lifecycle. Start with manual processes, automate incrementally.

**Current process:**
1. Adding sources: PR to `sources.yaml`
2. Adding skills: PR with SKILL.md (use `scripts/new-skill.sh` to scaffold)
3. Refreshing MCP index: `npm run ingest` in the MCP server repo
4. Validating: `python scripts/validate.py`

**Future automation candidates:**
- GitHub Action: weekly check if source repos have new releases → open issue
- Scheduled Claude Code agent: audits skill accuracy against latest docs
- MCP server: auto-pull `sources.yaml` on startup from published repo
- Dependabot-style: monitor Cardano ecosystem announcements for new tools

These are documented in `docs/CONTRIBUTING.md` as future work, not built into v0.1.0.
