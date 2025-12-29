log "Installing Steam (apt)..."

# Steam is a 32-bit program and expects i386 multiarch enabled.
# If an Nvidia proprietary driver is present, Steam also needs 32-bit Nvidia libs.
added_i386_arch="no"
if ! dpkg --print-foreign-architectures | grep -qx "i386"; then
  log "Enabling i386 multiarch (required for Steam)..."
  sudo_run dpkg --add-architecture i386
  added_i386_arch="yes"
fi

# Only apt-get update if we changed architectures (keeps this fast/idempotent).
if [[ "$added_i386_arch" == "yes" ]]; then
  sudo_run apt-get update
fi

# Avoid Steam's interactive debconf prompt about missing 32-bit Nvidia driver libs.
if [[ -e /proc/driver/nvidia/version ]] || have_cmd nvidia-smi; then
  if ! dpkg -s nvidia-driver-libs:i386 >/dev/null 2>&1; then
    log "Nvidia driver detected; installing 32-bit Nvidia libs for Steam..."
    sudo_run apt-get install -y nvidia-driver-libs:i386
  fi
fi

# Package name differs by Ubuntu release; try the common options.
if apt-cache show steam-installer >/dev/null 2>&1; then
  sudo_run apt-get install -y steam-installer
elif apt-cache show steam >/dev/null 2>&1; then
  sudo_run apt-get install -y steam
else
  die "No steam package found via apt-cache (enable multiverse?)"
fi

log "Done (Steam)."

