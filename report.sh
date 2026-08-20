#!/usr/bin/env bash
set -eu
# Report current pane as muse ONLY if it is actually running muse.
# Used by startup hook, manual action, and launcher fallback.
if [[ "${HERDR_ENV:-}" != "1" ]]; then
  : "${HERDR_SOCKET_PATH:=/home/roman/.config/herdr/herdr.sock}"
fi
if [[ -z "${HERDR_SOCKET_PATH:-}" || ! -S "$HERDR_SOCKET_PATH" ]]; then
  exit 0
fi
command -v python3 >/dev/null 2>&1 || exit 0

if [[ -z "${HERDR_PANE_ID:-}" ]]; then
  exit 0
fi

# --- Guard: only report if this pane's foreground process is muse/muse-bin ---
# This prevents new empty tabs (fish) from being falsely tagged as muse.
if command -v herdr >/dev/null 2>&1; then
  if ! herdr pane process-info --pane "$HERDR_PANE_ID" 2>/dev/null | grep -qE '"name":\s*"muse'; then
    exit 0
  fi
fi

cwd="${PWD:-$(pwd)}"
db="/home/roman/.local/share/muse/session-index.db"
session_id=""
if [[ -r "$db" ]] && command -v sqlite3 >/dev/null 2>&1; then
  session_id="$(sqlite3 "$db" "SELECT session_id FROM sessions WHERE workspace_root='$cwd' ORDER BY updated_at_us DESC LIMIT 1;" 2>/dev/null || true)"
fi
if [[ -z "$session_id" ]]; then
  session_id="$(sqlite3 "$db" "SELECT session_id FROM sessions ORDER BY updated_at_us DESC LIMIT 1;" 2>/dev/null || true)"
fi
if [[ -z "$session_id" && -n "${MUSE_SESSION_ID:-}" ]]; then
  session_id="$MUSE_SESSION_ID"
fi

python3 - << PY 2>/dev/null || true
import os, json, socket, time
sock = os.environ.get("HERDR_SOCKET_PATH", "")
pane = os.environ.get("HERDR_PANE_ID", "")
session_id = os.environ.get("MUSE_SESSION_ID", "") or """$session_id"""
if not sock or not pane:
    raise SystemExit(0)
seq = time.time_ns()
params = {
    "pane_id": pane,
    "source": "herdr:muse",
    "agent": "muse",
    "seq": seq,
}
if session_id:
    params["agent_session_id"] = session_id
    import pathlib
    p = pathlib.Path(os.path.expanduser("~/.local/share/muse/sessions"))
    for candidate in p.rglob(f"{session_id}/session.jsonl"):
        params["agent_session_path"] = str(candidate)
        break
req = json.dumps({"id": f"herdr:muse:{seq}", "method": "pane.report_agent_session", "params": params})
try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        s.connect(sock)
        s.sendall((req+"\n").encode())
        s.recv(4096)
except Exception:
    pass
seq = time.time_ns()
params2 = {
    "pane_id": pane,
    "source": "herdr:muse",
    "agent": "muse",
    "state": "working",
    "seq": seq,
}
req2 = json.dumps({"id": f"herdr:muse2:{seq}", "method": "pane.report_agent", "params": params2})
try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        s.connect(sock)
        s.sendall((req2+"\n").encode())
        s.recv(4096)
except Exception:
    pass
PY
exit 0
