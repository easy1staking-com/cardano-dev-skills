#!/usr/bin/env bash
#
# sync-sources.sh — Generate MCP server's sources.ts from registry/sources.yaml
#
# Usage:
#   ./scripts/sync-sources.sh [output-path]
#
# Default output: stdout (pipe to a file or copy to MCP server)
# Example:
#   ./scripts/sync-sources.sh ../cardano-unified-mcp-server/src/config/sources.generated.ts
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCES_YAML="$REPO_ROOT/registry/sources.yaml"
OUTPUT="${1:-/dev/stdout}"

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required" >&2
  exit 1
fi

if [ ! -f "$SOURCES_YAML" ]; then
  echo "Error: $SOURCES_YAML not found" >&2
  exit 1
fi

python3 -c "
import yaml, json, sys

with open('$SOURCES_YAML') as f:
    sources = yaml.safe_load(f)

# Filter out commented/candidate entries (they won't appear in parsed YAML)
if not isinstance(sources, list):
    print('Error: sources.yaml must be a list', file=sys.stderr)
    sys.exit(1)

print('// AUTO-GENERATED from registry/sources.yaml — do not edit manually')
print('// Run: ./scripts/sync-sources.sh to regenerate')
print()
print('export type DocFormat = \"markdown\" | \"mdx\" | \"rst\" | \"openapi\" | \"aiken\" | \"toml\";')
print()
print('export type DocCategory = \"infrastructure\" | \"smart-contracts\" | \"sdk\" | \"standards\" | \"governance\" | \"scaling\" | \"testing\";')
print()
print('export interface DocSource {')
print('  name: string;')
print('  repo: string;')
print('  docsPath: string;')
print('  format: DocFormat;')
print('  formatOverrides?: Record<string, DocFormat>;')
print('  category: DocCategory;')
print('  priority: \"high\" | \"medium\" | \"low\";')
print('  branch?: string;')
print('  globPatterns?: string[];')
print('}')
print()
print('export const DOC_SOURCES: DocSource[] = [')

for src in sources:
    parts = ['  {']
    parts.append(f'    name: {json.dumps(src[\"name\"])},')
    parts.append(f'    repo: {json.dumps(src[\"repo\"])},')
    parts.append(f'    docsPath: {json.dumps(src[\"docs_path\"])},')
    parts.append(f'    format: {json.dumps(src[\"format\"])},')

    if 'format_overrides' in src:
        fo = ', '.join(f'{json.dumps(k)}: {json.dumps(v)}' for k, v in src['format_overrides'].items())
        parts.append(f'    formatOverrides: {{ {fo} }},')

    parts.append(f'    category: {json.dumps(src[\"category\"])},')
    parts.append(f'    priority: {json.dumps(src[\"priority\"])},')

    if 'branch' in src:
        parts.append(f'    branch: {json.dumps(src[\"branch\"])},')

    if 'glob_patterns' in src:
        gp = json.dumps(src['glob_patterns'])
        parts.append(f'    globPatterns: {gp},')

    parts.append('  },')
    print('\n'.join(parts))

print('];')
" > "$OUTPUT"

if [ "$OUTPUT" != "/dev/stdout" ]; then
  echo "Generated: $OUTPUT ($(grep -c 'name:' "$OUTPUT") sources)" >&2
fi
