#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
YES=0

usage() {
  cat <<'USAGE'
Usage: install-nix.sh [options]

Install Determinate Nix if not already present. No-op if Nix is found.

Options:
  --dry-run     Print commands without running them
  --yes         Do not prompt before installing Nix
  -h, --help    Show this help
USAGE
}

log() { printf '[install-nix] %s\n' "$*"; }
die() { printf '[install-nix] error: %s\n' "$*" >&2; exit 1; }

quote_command() { printf '%q ' "$@"; printf '\n'; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] '
    quote_command "$@"
    return
  fi
  "$@"
}

confirm() {
  if [ "$YES" -eq 1 ]; then return; fi
  if [ ! -t 0 ]; then die "$1 Pass --yes to run non-interactively."; fi
  printf '%s [y/N] ' "$1"
  read -r answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) die "aborted" ;;
  esac
}

find_nix() {
  if command -v nix >/dev/null 2>&1; then
    command -v nix
    return
  fi
  if [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    printf '%s\n' /nix/var/nix/profiles/default/bin/nix
    return
  fi
  return 1
}

load_nix_profile() {
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

ensure_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    die "this script currently supports macOS only"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

ensure_macos

if find_nix >/dev/null 2>&1; then
  log "Nix is already installed"
  exit 0
fi

confirm "Nix is not installed. Install Determinate Nix now?"

installer_url="https://install.determinate.systems/nix"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

log "downloading Determinate Nix installer"
run curl --proto '=https' --tlsv1.2 -sSf -L "$installer_url" -o "$tmpdir/install-nix"

log "installing Determinate Nix"
run sh "$tmpdir/install-nix" install --no-confirm

if [ "$DRY_RUN" -eq 1 ]; then exit 0; fi

load_nix_profile
find_nix >/dev/null 2>&1 || die "Nix install finished, but nix is still not available"
