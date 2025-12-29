#!/usr/bin/env bash
set -euo pipefail

log() {
  # shellcheck disable=SC2059
  printf "[os-ubuntu] %s\n" "$*"
}

warn() {
  # shellcheck disable=SC2059
  printf "[os-ubuntu] WARN: %s\n" "$*" >&2
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

ensure_ubuntu() {
  if [[ ! -f /etc/os-release ]]; then
    die "Cannot detect OS (missing /etc/os-release)."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    die "This installer currently supports Ubuntu only (detected: ${ID:-unknown})."
  fi
}

apt_recover_dpkg() {
  # In some environments dpkg can be left half-configured (e.g. interrupted upgrade),
  # which blocks any apt operation with:
  #   "E: dpkg was interrupted, you must manually run 'sudo dpkg --configure -a' ..."
  #
  # Running this proactively is safe when dpkg is healthy (it's effectively a no-op).
  log "Ensuring dpkg is configured (dpkg --configure -a)..."
  if ! sudo_run dpkg --configure -a; then
    die "dpkg is in a broken state. Try: sudo dpkg --configure -a && sudo apt-get -f install"
  fi
}

