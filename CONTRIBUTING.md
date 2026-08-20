# Contributing

Issues and PRs welcome.

## Development loop

```bash
# The plugin dir is the repo itself after ./install.sh did `herdr plugin link /path/to/herdr-muse`
herdr plugin list
herdr server reload-config

# Test guard
HERDR_PANE_ID=w2:p8 bash ./report.sh && echo "blocked (good)"
HERDR_PANE_ID=w2:p7 bash ./report.sh && herdr agent list

# Edit, then reload
herdr server reload-config
```

## Upstream Tier 2

If you have `herdr` source, add `muse` to `src/app/api/agents.rs` (`SupportedAgentKind`) and `src/integration/targets.rs` (`IntegrationTarget`) + manifest entry. Then `herdr integration install muse` works natively and `install.sh`'s launcher patch becomes optional.
