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
  echo "[Cardano Dev Skills] Documentation sources not found."
  echo ""
  echo "The skills plugin works but will produce better results with local docs."
  echo "To fetch all 40+ Cardano documentation sources (~23MB), run:"
  echo ""
  echo "  cd $PLUGIN_ROOT && ./scripts/fetch-docs.sh"
  exit 0
fi

# Check freshness
LAST_FETCHED=$(grep 'last_fetched:' "$MANIFEST" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
if [ -z "$LAST_FETCHED" ]; then
  exit 0
fi

# Calculate age using file modification time as fallback
FETCH_EPOCH=0

# Try macOS date
if command -v date &>/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    FETCH_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_FETCHED" "+%s" 2>/dev/null || echo 0)
  else
    FETCH_EPOCH=$(date -d "$LAST_FETCHED" "+%s" 2>/dev/null || echo 0)
  fi
fi

# If date parsing failed, use manifest file mtime as fallback
if [ "$FETCH_EPOCH" -eq 0 ] 2>/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    FETCH_EPOCH=$(stat -f %m "$MANIFEST" 2>/dev/null || echo 0)
  else
    FETCH_EPOCH=$(stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)
  fi
fi

NOW_EPOCH=$(date "+%s")

# Sanity check: if fetch epoch is still 0 or in the future, skip age reporting
if [ "$FETCH_EPOCH" -eq 0 ] || [ "$FETCH_EPOCH" -gt "$NOW_EPOCH" ]; then
  TOTAL_SOURCES=$(grep 'total_sources:' "$MANIFEST" | head -1 | sed 's/.*: *//')
  TOTAL_FILES=$(grep 'total_files:' "$MANIFEST" | head -1 | sed 's/.*: *//')
  echo "[Cardano Dev Skills] Docs loaded: ${TOTAL_SOURCES} sources, ${TOTAL_FILES} files"
  exit 0
fi

AGE_DAYS=$(( (NOW_EPOCH - FETCH_EPOCH) / 86400 ))
TOTAL_SOURCES=$(grep 'total_sources:' "$MANIFEST" | head -1 | sed 's/.*: *//')
TOTAL_FILES=$(grep 'total_files:' "$MANIFEST" | head -1 | sed 's/.*: *//')

if [ "$AGE_DAYS" -gt "$STALE_DAYS" ]; then
  echo "[Cardano Dev Skills] Docs are ${AGE_DAYS} days old (${TOTAL_SOURCES} sources, ${TOTAL_FILES} files). Consider refreshing:"
  echo "  cd $PLUGIN_ROOT && ./scripts/fetch-docs.sh"
else
  echo "[Cardano Dev Skills] Docs loaded: ${TOTAL_SOURCES} sources, ${TOTAL_FILES} files (updated ${AGE_DAYS}d ago)"
fi
