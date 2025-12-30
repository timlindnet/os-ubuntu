log "Installing Bolt (Flatpak)..."

# Avoid any interactive apt/debconf prompts.
export DEBIAN_FRONTEND=noninteractive

apt_recover_dpkg

if ! have_cmd flatpak; then
  log "Installing requirement: flatpak"
  sudo_run apt-get update -y
  sudo_run apt-get install -y flatpak
fi

# Ensure Flathub exists (Bolt is published there).
sudo_run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true

sudo_run flatpak install -y --noninteractive flathub com.adamcake.Bolt

log "Done (Bolt)."

