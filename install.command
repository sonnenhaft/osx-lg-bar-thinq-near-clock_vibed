#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.command
mkdir -p "$HOME/Applications"
destination="$HOME/Applications/LGBar.app"
staging_dir="$(mktemp -d "$HOME/Applications/.LGBar-install.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto LGBar.app "$staging_dir/LGBar.app"
config_dir="$HOME/Library/Application Support/LGBar"
if [[ -s token.txt && ! -s "$config_dir/token.txt" ]]; then
  mkdir -p "$config_dir"
  chmod 700 "$config_dir"
  (umask 077; cp token.txt "$config_dir/token.txt")
  chmod 600 "$config_dir/token.txt"
fi
# Stop every running copy before replacing the installed application.
if pgrep -x LGBar >/dev/null; then
  pkill -TERM -x LGBar || true
  for ((attempt = 0; attempt < 50; attempt++)); do
    if ! pgrep -x LGBar >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x LGBar >/dev/null; then
    pkill -KILL -x LGBar || true
    sleep 0.2
  fi
  if pgrep -x LGBar >/dev/null; then
    printf 'Could not stop LG Bar. Installation cancelled.\n' >&2
    exit 1
  fi
fi
rm -rf "$destination"
mv "$staging_dir/LGBar.app" "$destination"
if [[ "$(pwd -P)/LGBar.app" != "$destination" ]]; then
  rm -rf LGBar.app
fi
open "$destination"
