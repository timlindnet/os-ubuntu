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

os_pkg_is_installed() {
  # Usage: os_pkg_is_installed <apt-package-name>
  #
  # Returns 0 if the package is installed (per dpkg), otherwise 1.
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1
}

os_pkg_install() {
  local pkgs=("$@")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    return 0
  fi

  local missing=()
  local p
  for p in "${pkgs[@]}"; do
    if os_pkg_is_installed "$p"; then
      :
    else
      missing+=("$p")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "All requested apt packages already installed: ${pkgs[*]}"
    return 0
  fi

  log "Installing apt packages: ${missing[*]}"
  os_pkg_update
  sudo_run apt-get install -y "${missing[@]}"
}

os_snap_is_installed() {
  # Usage: os_snap_is_installed <snap-name>
  have_cmd snap || return 1
  snap list "$1" >/dev/null 2>&1
}

os_snap_install() {
  # Usage: os_snap_install <snap-name> [--classic]
  #
  # Installs a snap only if not already installed.
  local name="$1"
  shift || true

  if os_snap_is_installed "$name"; then
    log "Snap already installed: $name"
    return 0
  fi

  log "Installing snap: $name"
  sudo_run snap install "$name" "$@"
}

# Back-compat with existing Ubuntu scripts.
ensure_ubuntu() { ensure_os; }
apt_recover_dpkg() { os_recover_pkg_system; }

