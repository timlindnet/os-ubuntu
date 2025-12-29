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

# Baseline gaming graphics utilities (generally safe)
sudo_run apt-get update -y
sudo_run apt-get install -y mesa-utils vulkan-tools || true

# NVIDIA generally doesn't benefit from Mesa updates for the main driver stack.
if echo "$gpu_line" | grep -qi 'nvidia'; then
  log "NVIDIA GPU detected: skipping Mesa PPA (NVIDIA uses its own driver stack)."
  exit 0
fi

# For AMD/Intel, the commonly-used "stable newer Mesa" option on Ubuntu is kisak-mesa.
# This is still a PPA, so treat as opt-in but enabled here for the gaming tag.
log "Enabling kisak-mesa PPA for newer Mesa (AMD/Intel gaming performance)."
sudo_run apt-get install -y software-properties-common
sudo_run add-apt-repository -y ppa:kisak/kisak-mesa
sudo_run apt-get update -y

# Upgrade Mesa-related packages (best-effort, package names vary by release).
mesa_pkgs=(
  libgl1-mesa-dri
  mesa-vulkan-drivers
  mesa-va-drivers
  mesa-vdpau-drivers
)

installable=()
for p in "${mesa_pkgs[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    installable+=("$p")
  fi
done

if [[ ${#installable[@]} -gt 0 ]]; then
  log "Installing/upgrading Mesa packages: ${installable[*]}"
  sudo_run apt-get install -y "${installable[@]}"
else
  log "No known Mesa packages found to upgrade on this Ubuntu release; skipping."
fi

log "Mesa update complete. A reboot is recommended if graphics components were upgraded."

