log "Installing Steam (apt)..."

# Fast path: if Steam is already installed, don't touch apt sources.
if os_apt_is_installed steam; then
  log "Steam already installed."
  exit 0
fi

# Enable multiverse (Steam lives here on Ubuntu).
# Pre-scripts already run `apt-get update`, so we only update again after
# enabling multiverse.
if ! have_cmd add-apt-repository; then
  # add-apt-repository is provided by software-properties-common.
  os_apt_install software-properties-common
fi

if ! grep -RqsE '^[^#].*\bmultiverse\b' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  sudo_run add-apt-repository -y multiverse
  sudo_run apt-get update -y
fi

os_apt_install steam

log "Done (Steam)."

