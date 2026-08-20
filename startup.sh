#!/usr/bin/env bash
set -eu
# Startup hook: only report if current pane is actually muse.
# No longer triggered on every pane.created — only on server startup.
if [[ -n "${HERDR_PANE_ID:-}" ]]; then
  bash "$(dirname "$0")/report.sh" 2>/dev/null || true
  exit 0
fi
# For global startup without a specific pane, do nothing — launcher patch
# handles per-pane reporting when muse actually launches.
# We still report current pane if inside herdr and it is muse.
bash "$(dirname "$0")/report.sh" 2>/dev/null || true
exit 0
