#!/usr/bin/env bash
#
# SessionStart hook: check if documentation sources are present and fresh
#
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DOCS_DIR="$PLUGIN_ROOT/docs/sources"
MANIFEST="$DOCS_DIR/.manifest.yaml"
STALE_DAYS=30

# Check if docs exist at all
if [ ! -d "$DOCS_DIR" ] || [ ! -f "$MANIFEST" ]; then
  cat << 'MSG'
[Cardano Dev Skills] Documentation sources not found.

The skills plugin works but will produce better results with local docs.
To fetch all 40+ Cardano documentation sources (~20-50MB), run:

  cd $(dirname "$0") && ./scripts/fetch-docs.sh

This gives Claude direct access to SDK APIs, CIP specs, and tool documentation.
MSG
  exit 0
fi

# Check freshness
LAST_FETCHED=$(grep 'last_fetched:' "$MANIFEST" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')
if [ -z "$LAST_FETCHED" ]; then
  exit 0
fi

# Calculate age in days
if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_FETCHED" "+%s" &>/dev/null; then
  # macOS
  FETCH_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_FETCHED" "+%s")
else
  # Linux
  FETCH_EPOCH=$(date -d "$LAST_FETCHED" "+%s" 2>/dev/null || echo 0)
fi

NOW_EPOCH=$(date "+%s")
AGE_DAYS=$(( (NOW_EPOCH - FETCH_EPOCH) / 86400 ))

TOTAL_SOURCES=$(grep 'total_sources:' "$MANIFEST" | head -1 | sed 's/.*: *//')
TOTAL_FILES=$(grep 'total_files:' "$MANIFEST" | head -1 | sed 's/.*: *//')

if [ "$AGE_DAYS" -gt "$STALE_DAYS" ]; then
  echo "[Cardano Dev Skills] Docs are ${AGE_DAYS} days old (${TOTAL_SOURCES} sources, ${TOTAL_FILES} files). Consider refreshing:"
  echo "  ./scripts/fetch-docs.sh"
else
  echo "[Cardano Dev Skills] Docs loaded: ${TOTAL_SOURCES} sources, ${TOTAL_FILES} files (updated ${AGE_DAYS}d ago)"
fi
