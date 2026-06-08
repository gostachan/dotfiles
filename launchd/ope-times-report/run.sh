#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# launchd は対話シェルを継承しないため、nix-darwin/home-manager の PATH を明示する
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$(id -un)/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

exec uv run --quiet "$SCRIPT_DIR/report.py"
