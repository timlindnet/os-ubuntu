log "Installing Spotify (snap)..."

apt_recover_dpkg
sudo_run apt-get install -y snapd
sudo_run snap install spotify

log "Done (Spotify)."

