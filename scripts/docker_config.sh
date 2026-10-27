#!/usr/bin/env bash
# docker_config.sh — let the Docker CLI find the Compose and buildx plugins
# that Homebrew installs. Run with: make docker-config
#
# Homebrew puts them in $(brew --prefix)/lib/docker/cli-plugins:
#   /opt/homebrew/...  on Apple Silicon,   /usr/local/...  on Intel.
# Docker only looks there if ~/.docker/config.json lists that folder under
# "cliPluginsExtraDirs". This script ADDS the folder and keeps every other
# setting already in the file (e.g. from Docker Desktop), after a backup.

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "✘ Homebrew not found. Install it first (README, step 2)." >&2
  exit 1
fi

PLUGIN_DIR="$(brew --prefix)/lib/docker/cli-plugins"
CONFIG="$HOME/.docker/config.json"
mkdir -p "$HOME/.docker"
[ -f "$CONFIG" ] && cp "$CONFIG" "$CONFIG.bak"

/usr/bin/python3 - "$CONFIG" "$PLUGIN_DIR" <<'EOF'
import json, os, sys
path, plugin_dir = sys.argv[1], sys.argv[2]
config = json.load(open(path)) if os.path.exists(path) and os.path.getsize(path) else {}
dirs = config.setdefault("cliPluginsExtraDirs", [])
if plugin_dir in dirs:
    print(f"✔ {path} already lists {plugin_dir}")
else:
    dirs.append(plugin_dir)
    json.dump(config, open(path, "w"), indent=2)
    print(f"✔ added {plugin_dir} to {path}")
EOF

for plugin in compose buildx; do
  if docker "$plugin" version >/dev/null 2>&1; then
    echo "✔ docker $plugin works"
  else
    echo "✘ docker $plugin not found — install it: brew install docker-$plugin" >&2
  fi
done
