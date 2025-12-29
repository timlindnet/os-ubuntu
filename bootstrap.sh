#!/usr/bin/env bash
set -euo pipefail

# Minimal bootstrap: download repo tarball, run install.sh, clean up.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/main/bootstrap.sh | bash -s -- --base --dev

log() { printf "[os-ubuntu-bootstrap] %s\n" "$*"; }
die() { printf "[os-ubuntu-bootstrap] ERROR: %s\n" "$*" >&2; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

fetch_url() {
  local url="$1"
  if have_cmd curl; then
    curl -fsSL "$url"
  elif have_cmd wget; then
    wget -qO- "$url"
  else
    die "Need curl or wget to bootstrap."
  fi
}

REPO_OWNER="${OS_UBUNTU_OWNER:-timlindnet}"
REPO_NAME="${OS_UBUNTU_REPO:-os-ubuntu}"
REF="${OS_UBUNTU_REF:-main}"

TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REF}.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "Downloading ${REPO_OWNER}/${REPO_NAME}@${REF}..."
fetch_url "$TARBALL_URL" >"$tmp/repo.tgz"

log "Extracting..."
tar -xzf "$tmp/repo.tgz" -C "$tmp"

repo_dir="$tmp/${REPO_NAME}-${REF}"
if [[ ! -d "$repo_dir" ]]; then
  # Fallback (avoid find): assume only one top-level directory in tarball.
  repo_dir="$(ls -1d "$tmp"/*/ 2>/dev/null | head -n1 || true)"
fi
[[ -d "$repo_dir" ]] || die "Could not locate extracted repo directory."

log "Running install..."
bash "$repo_dir/install.sh" "$@"

