#!/usr/bin/env bash
set -eu
LAUNCHER="${HOME}/.local/bin/muse"
# Restore latest backup if exists
latest="$(ls -t "${LAUNCHER}".bak.* 2>/dev/null | head -n1 || true)"
if [[ -n "$latest" && -r "$latest" ]]; then
  cp "$latest" "$LAUNCHER"
  echo "restored $latest -> $LAUNCHER"
else
  # Try to remove the patch manually
  if grep -q "herdr-muse integration" "$LAUNCHER" 2>/dev/null; then
    echo "No backup found but launcher is patched — manual removal needed" >&2
    exit 1
  fi
fi
if command -v herdr >/dev/null 2>&1; then
  herdr plugin unlink herdr-muse 2>&1 || true
  herdr server reload-config 2>&1 | head -n 5
  echo "Herdr plugin unlinked"
fi
echo "Uninstalled"
