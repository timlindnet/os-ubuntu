log "Installing Bolt (Flatpak)..."

if ! have_cmd flatpak; then
  log "Installing requirement: flatpak"
  os_pkg_install flatpak
fi

# Ensure Flathub exists (Bolt is published there).
sudo_run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true

sudo_run flatpak install -y --noninteractive flathub com.adamcake.Bolt

log "Done (Bolt)."

