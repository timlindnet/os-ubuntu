#!/usr/bin/env bash
set -euo pipefail

log() {
  # shellcheck disable=SC2059
  printf "[loadout] %s\n" "$*"
}

warn() {
  # shellcheck disable=SC2059
  printf "[loadout] WARN: %s\n" "$*" >&2
}

die() {
  warn "$*"
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

fetch_url() {
  # Usage: fetch_url <url>
  # Prints content to stdout.
  local url="$1"
  if have_cmd curl; then
    curl -fsSL "$url"
  elif have_cmd wget; then
    wget -qO- "$url"
  else
    die "Need curl or wget to fetch: $url"
  fi
}

require_cmd() {
  have_cmd "$1" || die "Missing required command: $1"
}

run() {
  log "+ $*"
  "$@"
}

sudo_run() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

