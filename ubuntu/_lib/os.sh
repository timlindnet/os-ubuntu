#!/usr/bin/env bash
set -euo pipefail

# Ubuntu-specific helpers and OS checks.

ensure_os() {
  if [[ ! -f /etc/os-release ]]; then
    die "Cannot detect OS (missing /etc/os-release)."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    die "This installer currently supports Ubuntu only (detected: ${ID:-unknown})."
  fi
}

os_recover_pkg_system() {
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

os_pkg_update() {
  os_recover_pkg_system
  sudo_run apt-get update -y
}

os_pkg_upgrade() {
  # Keep it noninteractive and conservative with config files:
  # - prefer default action where possible
  # - keep existing config if a prompt would occur
  export DEBIAN_FRONTEND=noninteractive

  os_recover_pkg_system
  sudo_run apt-get upgrade -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold
}

os_pkg_install() {
  local pkgs=("$@")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    return 0
  fi
  os_pkg_update
  sudo_run apt-get install -y "${pkgs[@]}"
}

# Back-compat with existing Ubuntu scripts.
ensure_ubuntu() { ensure_os; }
apt_recover_dpkg() { os_recover_pkg_system; }

