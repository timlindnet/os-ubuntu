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
  # dpkg/apt can be temporarily busy (e.g. unattended upgrades). Wait a bit for locks,
  # but never delete lock files.
  local timeout_s="${LOADOUT_DPKG_LOCK_TIMEOUT_S:-300}"
  local sleep_s=3
  local start_s=$SECONDS

  while true; do
    local out rc pid cmd
    out=""
    rc=0

    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      log "+ dpkg --configure -a"
      out="$(dpkg --configure -a 2>&1)" || rc=$?
    else
      log "+ sudo dpkg --configure -a"
      out="$(sudo dpkg --configure -a 2>&1)" || rc=$?
    fi

    if [[ "$rc" -eq 0 ]]; then
      return 0
    fi

    pid=""
    if [[ "$out" =~ pid[[:space:]]+([0-9]+) ]]; then
      pid="${BASH_REMATCH[1]}"
    fi

    # Common dpkg/apt lock messages.
    if [[ "$out" == *"lock-frontend"* ]] || [[ "$out" == *"dpkg frontend lock"* ]] || [[ "$out" == *"Unable to acquire the dpkg frontend lock"* ]] || [[ "$out" == *"Could not get lock /var/lib/dpkg/lock"* ]]; then
      if (( SECONDS - start_s >= timeout_s )); then
        warn "$out"
        die "Timed out waiting for dpkg/apt lock (${timeout_s}s). Try again later, or run: sudo dpkg --configure -a && sudo apt-get -f install"
      fi

      cmd=""
      if [[ -n "$pid" ]]; then
        cmd="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
      fi
      warn "dpkg/apt is busy${pid:+ (pid $pid${cmd:+: $cmd})}; waiting ${sleep_s}s and retrying..."
      sleep "$sleep_s"
      continue
    fi

    warn "$out"
    die "dpkg is in a broken state. Try: sudo dpkg --configure -a && sudo apt-get -f install"
  done
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

