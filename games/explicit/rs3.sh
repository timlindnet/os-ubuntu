log "Installing RuneScape launcher (apt repo)..."

# Publisher instructions use apt-key; follow them as requested.
fetch_url "https://content.runescape.com/downloads/ubuntu/runescape.gpg.key" | sudo_run apt-key add -

sudo_run mkdir -p /etc/apt/sources.list.d
printf 'deb https://content.runescape.com/downloads/ubuntu trusty non-free\n' | sudo_run tee /etc/apt/sources.list.d/runescape.list >/dev/null

apt_recover_dpkg
sudo_run apt-get update -y
sudo_run apt-get install -y runescape-launcher

log "Done (RuneScape launcher)."

