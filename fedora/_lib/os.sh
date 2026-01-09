#!/usr/bin/env bash
set -euo pipefail

# Fedora-family helpers and OS checks.

ensure_os() {
  if [[ ! -f /etc/os-release ]]; then
    die "Cannot detect OS (missing /etc/os-release)."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release

  local id="${ID:-}"
  local like="${ID_LIKE:-}"

  if [[ "$id" == "fedora" ]] || [[ " $like " == *" fedora "* ]] || [[ " $like " == *" rhel "* ]]; then
    return 0
  fi

  die "Fedora layer selected but OS is not Fedora-family (detected: ${id:-unknown})."
}

dnf_is_installed() {
  # Usage: dnf_is_installed <rpm-name>
  rpm -q "$1" >/dev/null 2>&1
}

dnf_install() {
  local pkgs=("$@")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    return 0
  fi

  local missing=()
  local p
  for p in "${pkgs[@]}"; do
    if dnf_is_installed "$p"; then
      :
    else
      missing+=("$p")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "All requested dnf packages already installed: ${pkgs[*]}"
    return 0
  fi

  log "Installing dnf packages: ${missing[*]}"
  sudo_run dnf install -y "${missing[@]}"
}

flatpak_is_installed() {
  # Usage: flatpak_is_installed <app-id>
  have_cmd flatpak || return 1
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    flatpak info --system "$1" >/dev/null 2>&1
  else
    sudo_run flatpak info --system "$1" >/dev/null 2>&1
  fi
}

flatpak_install() {
  # Usage: flatpak_install <app-id> [remote]
  local app_id="$1"
  local remote="${2:-flathub}"

  if flatpak_is_installed "$app_id"; then
    log "Flatpak already installed: $app_id"
    return 0
  fi

  if ! have_cmd flatpak; then
    dnf_install flatpak
  fi

  if [[ "$remote" == "flathub" ]]; then
    sudo_run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  fi

  log "Installing flatpak: $app_id (remote: $remote)"
  sudo_run flatpak install -y --noninteractive "$remote" "$app_id"
}

# Back-compat wrappers for existing scripts (older names).
os_flatpak_is_installed() { flatpak_is_installed "$@"; }
os_flatpak_install() { flatpak_install "$@"; }
os_pkg_is_installed() { dnf_is_installed "$@"; }
os_pkg_install() { dnf_install "$@"; }

