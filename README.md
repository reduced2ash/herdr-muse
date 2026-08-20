# herdr-muse

**Muse Code integration for [Herdr](https://herdr.dev)** — makes `muse` (`muse-spark`, `muse-bin-*`) appear as a first-class Herdr agent (`muse`) without rebuilding Herdr.

<img src="https://img.shields.io/badge/herdr-%3E%3D0.8.0-blue" alt="herdr >=0.8.0">
<img src="https://img.shields.io/badge/muse-%3E%3D0.2.1-orange" alt="muse >=0.2.1">


Herdr is a terminal workspace manager for AI coding agents. It tracks panes, tabs, and agent lifecycle (`idle` / `working` / `blocked`) and shows them in its sidebar. Out of the box Herdr knows `claude`, `codex`, `cursor`, `copilot`, `amp`, `pi`, etc. — this plugin adds `muse` (Meta Muse Code).

## Demo

Before:

```
herdr pane list --workspace w2
  w2:p7  agent=-  status=unknown  title=cliprelay   # muse running but Herdr says unknown
```

After (`muse` in `w2:p7`):

```
herdr pane list --workspace w2
  w2:p7  agent=muse  status=working  title=cliprelay

herdr agent list
  w2:p7  muse  working  ~/.local/share/muse/sessions/.../session.jsonl
```

Empty `fish` tabs stay `unknown` — no false positives.

## Installation

### 1. Clone & link as Herdr plugin

```bash
git clone https://github.com/reduced2ash/herdr-muse.git
cd herdr-muse
./install.sh
```

`install.sh` does two things:

1. **Patches `~/.local/bin/muse`** (the launcher that `exec`s `muse-bin-*`) to report to Herdr on every launch when inside Herdr (`HERDR_ENV=1`). It backs up the original to `~/.local/bin/muse.bak.<ts>` and is idempotent. The patch is ~30 lines and fire-and-forgets over `HERDR_SOCKET_PATH` (500 ms timeout, never blocks startup). On exit (`trap EXIT HUP INT TERM`) it clears the pane label so you don't get stuck `muse` ghosts.
2. **Links the Herdr plugin**: `herdr plugin link /path/to/herdr-muse && herdr server reload-config`.


### 2. Verify

```bash
herdr agent list          # should show muse in current pane as working
herdr pane list --workspace w2

# New empty tab should stay clean:
herdr tab create --workspace w2   # or Ctrl+T / new tab in UI
herdr pane list --workspace w2   # new pane: agent=- status=unknown

# Manual re-report if needed (e.g., after a server restart):
herdr plugin action invoke herdr-muse report-muse
# or directly:
HERDR_PANE_ID=w2:p7 bash ~/.config/herdr/plugins/local/herdr-muse/report.sh

# Clear a stuck label:
herdr plugin action invoke herdr-muse clear-muse
```

### 3. Alternative Herdr-native install (once published)

```bash
herdr plugin install reduced2ash/herdr-muse
./install.sh   # still needed for the launcher patch until Herdr upstream adds native muse kind
```

## How it works


* `muse-hook.py` reads `session_id` from `~/.local/share/muse/session-index.db` (latest for `$(pwd)` or latest overall) and the session path `~/.local/share/muse/sessions/.../session.jsonl`, then sends two messages:
  * `pane.report_agent_session` — lets Herdr resume/navigate to the Muse session.
  * `pane.report_agent` (`state: working`) — makes the pane + agent list show `muse:working`.

* `report.sh` — same logic, but gated: `herdr pane process-info --pane "$HERDR_PANE_ID" | grep '"name":\s*"muse'` — so empty `fish` panes are not mis-tagged. Used by the plugin's `report-muse` action and for manual recovery.

* `herdr-plugin.toml` — minimal plugin:
```toml
id = "herdr-muse"
version = "0.1.1"
[[startup]] command = ["bash", "startup.sh"]   # only on server startup, not every pane.created
[[actions]] report-muse / clear-muse
```


## Files

| Path | Role |
|------|------|
| `herdr-plugin.toml` | Herdr plugin manifest |
| `muse-hook.py` | Socket reporter (500 ms timeout) |
| `report.sh` | Gated manual reporter (checks `muse` process) |
| `startup.sh` | No-op startup (launcher patch does the real work) |
| `clear.sh` | Clears `muse` label |
| `install.sh` | Patches launcher + links plugin |
| `uninstall.sh` | Restores launcher backup + unlinks plugin |

## Uninstall

```bash
./uninstall.sh
# or manually:
cp ~/.local/bin/muse.bak.* ~/.local/bin/muse
herdr plugin unlink herdr-muse && herdr server reload-config
```

Launcher backups are never deleted automatically.

## Limitations (Tier 1)

* `idle` vs `working` is coarse — reports `working` on start; Herdr's screen detection may keep it `working` even when Muse is waiting for input. A future `Tier 1.1` could tail `session.jsonl` for `prompt`/`idle` events.
* `herdr agent start --kind muse` is still `unsupported` (`herdr` binary hasn't added `muse` to `SupportedAgentKind`). Use `herdr pane split` + `muse` as normal. Upstream fix is two lines in `src/app/api/agents.rs` + `src/integration/targets.rs`.
* Launcher patch is overwritten on `muse` auto-update (`MUSE_SYNC_UPDATE`). Re-run `./install.sh` or `HERDR_PANE_ID=... report.sh`.


## Development

```bash
# Edit plugin in place (the linked dir is the repo itself after install.sh)
herdr plugin list
herdr server reload-config

# Test empty-tab guard:
HERDR_PANE_ID=w2:p8 bash ./report.sh && echo "blocked (good) vs reported"

# Simulate a new muse pane:
herdr pane split --current --direction right --cwd "$PWD" --no-focus  # -> w2:pX
herdr pane run w2:pX "muse --help" && herdr agent list
```


