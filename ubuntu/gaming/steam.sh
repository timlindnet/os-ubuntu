log "Installing Steam (apt)..."

# Avoid any interactive apt/debconf prompts.
export DEBIAN_FRONTEND=noninteractive

# Ensure dpkg isn't left half-configured (blocks apt operations).
apt_recover_dpkg

# Enable multiverse (Steam lives here on Ubuntu).
# Pre-scripts already run `apt-get update`, so we only update again after
# enabling multiverse.
if ! have_cmd add-apt-repository; then
  # add-apt-repository is provided by software-properties-common.
  sudo_run apt-get install -y software-properties-common
fi

sudo_run add-apt-repository -y multiverse
sudo_run apt-get update -y
sudo_run apt-get install -y steam

log "Done (Steam)."

