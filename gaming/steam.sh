log "Installing Steam (apt)..."

# Package name differs by Ubuntu release; try the common options.
if apt-cache show steam-installer >/dev/null 2>&1; then
  sudo_run apt-get install -y steam-installer
elif apt-cache show steam >/dev/null 2>&1; then
  sudo_run apt-get install -y steam
else
  die "No steam package found via apt-cache (enable multiverse?)"
fi

log "Done (Steam)."

