#!/usr/bin/env bash
set -eu
if [[ -z "${HERDR_SOCKET_PATH:-}" ]]; then
  HERDR_SOCKET_PATH="/home/roman/.config/herdr/herdr.sock"
fi
if [[ ! -S "$HERDR_SOCKET_PATH" ]]; then
  exit 0
fi
command -v python3 >/dev/null 2>&1 || exit 0
# Clear muse label from current pane
if [[ -n "${HERDR_PANE_ID:-}" ]]; then
  python3 - << PY 2>/dev/null || true
import os, json, socket, time
sock=os.environ["HERDR_SOCKET_PATH"]
pane=os.environ["HERDR_PANE_ID"]
seq=time.time_ns()
params={"pane_id":pane,"source":"herdr:muse","agent":"muse","state":"unknown","seq":seq}
req=json.dumps({"id":f"herdr:muse:clear:{seq}","method":"pane.report_agent","params":params})
try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        s.connect(sock)
        s.sendall((req+"\n").encode())
        s.recv(4096)
except: pass
PY
fi
exit 0
