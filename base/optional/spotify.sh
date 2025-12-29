log "Installing Spotify (snap)..."

sudo_run apt-get install -y snapd
sudo_run snap install spotify

log "Done (Spotify)."

