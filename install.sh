#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { printf "[loadout] ERROR: %s\n" "$*" >&2; exit 1; }

os="${1:-}"
if [[ -z "$os" || "$os" == "-"* ]]; then
  # Back-compat: if OS isn't provided, default to ubuntu.
  os="ubuntu"
else
  shift
fi

if [[ ! -d "$REPO_ROOT/$os" ]]; then
  die "Unknown OS: $os (missing directory: $REPO_ROOT/$os)"
fi
if [[ ! -f "$REPO_ROOT/$os/install.sh" ]]; then
  die "Missing per-OS installer: $REPO_ROOT/$os/install.sh"
fi

exec bash "$REPO_ROOT/$os/install.sh" "$@"

