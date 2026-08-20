#!/usr/bin/env bash
set -eu
# Herdr Muse installer — patches ~/.local/bin/muse to report to Herdr
# Idempotent; keeps backup at ~/.local/bin/muse.bak.*
REPO_DIR="$(cd -- "$(dirname "$0")" && pwd)"
LAUNCHER="${HOME}/.local/bin/muse"
HOOK_PY="${HOME}/.config/herdr/plugins/local/herdr-muse/muse-hook.py"

if [[ ! -x "$LAUNCHER" ]]; then
  echo "muse launcher not found at $LAUNCHER" >&2
  exit 1
fi

if grep -q "herdr-muse integration" "$LAUNCHER" 2>/dev/null; then
  echo "launcher already patched"
else
  BACKUP="${LAUNCHER}.bak.$(date +%s)"
  cp "$LAUNCHER" "$BACKUP"
  echo "backup: $BACKUP"
  python3 << PY
import pathlib
p = pathlib.Path("$LAUNCHER")
text = p.read_text()
old = '  exec "\$binary" "\$@"'
new = '''  # ---- herdr-muse integration (Tier 1) ----
  # Cleanup trap: when muse exits, clear herdr label so pane doesn't stay stuck as 'muse'
  _herdr_muse_cleanup() {
    if [ "\${HERDR_ENV:-}" = "1" ] && [ -n "\${HERDR_SOCKET_PATH:-}" ] && [ -n "\${HERDR_PANE_ID:-}" ]; then
      python3 -c '
import os, json, socket, time
sock=os.environ.get("HERDR_SOCKET_PATH","")
pane=os.environ.get("HERDR_PANE_ID","")
if sock and pane:
    try:
        seq=time.time_ns()
        params={"pane_id":pane,"source":"herdr:muse","agent":"muse","state":"unknown","seq":seq}
        req=json.dumps({"id":f"herdr:muse:exit:{seq}","method":"pane.report_agent","params":params})
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.3)
            s.connect(sock)
            s.sendall((req+"\\n").encode())
            s.recv(4096)
    except: pass
' 2>/dev/null || true
    fi
  }
  trap _herdr_muse_cleanup EXIT HUP INT TERM
  # Report Muse Code to Herdr as managed agent 'muse'.
  if [ "\${HERDR_ENV:-}" = "1" ] && [ -n "\${HERDR_SOCKET_PATH:-}" ] && [ -n "\${HERDR_PANE_ID:-}" ] && command -v python3 >/dev/null 2>&1; then
    _muse_herdr_db="\${HOME:-/home/roman}/.local/share/muse/session-index.db"
    _muse_herdr_session=""
    if [ -r "\$_muse_herdr_db" ] && command -v sqlite3 >/dev/null 2>&1; then
      _muse_herdr_session="\$(sqlite3 "\$_muse_herdr_db" "SELECT session_id FROM sessions WHERE workspace_root='\$(pwd)' ORDER BY updated_at_us DESC LIMIT 1;" 2>/dev/null || true)"
      if [ -z "\$_muse_herdr_session" ]; then
        _muse_herdr_session="\$(sqlite3 "\$_muse_herdr_db" "SELECT session_id FROM sessions ORDER BY updated_at_us DESC LIMIT 1;" 2>/dev/null || true)"
      fi
    fi
    export _muse_herdr_session
    python3 "\$HOME/.config/herdr/plugins/local/herdr-muse/muse-hook.py" 2>/dev/null || true
    export MUSE_SESSION_ID="\$_muse_herdr_session"
    unset _muse_herdr_db _muse_herdr_session
  fi
  # ---- end herdr-muse integration ----
  exec "\$binary" "\$@"'''
  if old in text:
      p.write_text(text.replace(old, new))
      print("patched launcher")
  else:
      print("exec line not found, manual patch needed", file=sys.stderr)
PY
  bash -n "$LAUNCHER" && echo "launcher syntax ok" || { cp "$BACKUP" "$LAUNCHER"; echo "syntax fail, restored"; exit 1; }
fi

# Ensure Herdr plugin is linked
if command -v herdr >/dev/null 2>&1; then
  PLUGIN_SRC="$REPO"
  # If already linked via local, unlink/relink to new location
  herdr plugin list 2>&1 | grep -q "herdr-muse" && herdr plugin unlink herdr-muse 2>&1 || true
  herdr plugin link "$PLUGIN_SRC" 2>&1 | head -n 5
  herdr server reload-config 2>&1 | head -n 5
  echo "Herdr plugin linked: herdr-muse"
fi

echo "Done. Verify: herdr agent list | herdr pane list --workspace \${HERDR_WORKSPACE_ID:-w2}"
