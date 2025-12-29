#!/usr/bin/env bash
set -euo pipefail

ROOT="${OS_UBUNTU_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

ensure_ubuntu

if ! have_cmd lspci; then
  log "Installing pciutils (for GPU detection)..."
  sudo_run apt-get update -y
  sudo_run apt-get install -y pciutils
fi

gpu_line="$(lspci -nn | grep -Ei 'vga|3d|display' | head -n1 || true)"
log "GPU detected: ${gpu_line:-unknown}"

# Decide kernel meta package (Ubuntu-supported "stable" choices)
kernel_meta="linux-generic"
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  # On older LTS releases, HWE meta is the supported "newer stable" kernel track.
  # For 24.04+ the generic kernel is already current; keep linux-generic.
  case "${VERSION_ID:-}" in
    20.04|22.04)
      kernel_meta="linux-generic-hwe-${VERSION_ID}"
      ;;
  esac
fi

log "Ensuring kernel meta package: $kernel_meta"
sudo_run apt-get update -y
sudo_run apt-get install -y "$kernel_meta" linux-firmware

if echo "$gpu_line" | grep -qi 'nvidia'; then
  log "NVIDIA GPU detected: installing Ubuntu-recommended NVIDIA driver (stable, tested for this Ubuntu release)"
  sudo_run apt-get install -y ubuntu-drivers-common

  # ubuntu-drivers picks the recommended, supported driver for this hardware/Ubuntu combo.
  sudo_run ubuntu-drivers autoinstall

  log "NVIDIA driver install requested. A reboot is typically required."
else
  # AMD/Intel: no proprietary driver step. Kernel meta above is the main lever.
  if echo "$gpu_line" | grep -Eqi 'amd|advanced micro devices|ati'; then
    log "AMD GPU detected: using Ubuntu kernel + firmware (Mesa handled by gaming/mesa.sh)."
  elif echo "$gpu_line" | grep -qi 'intel'; then
    log "Intel GPU detected: using Ubuntu kernel + firmware (Mesa handled by gaming/mesa.sh)."
  else
    log "Unknown GPU vendor: installed kernel meta + firmware only."
  fi
fi

