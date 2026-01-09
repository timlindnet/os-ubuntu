if have_cmd git; then
  log "git is already installed ($(git --version 2>/dev/null || true))."
  exit 0
fi

log "Installing git..."
sudo_run apt-get install -y git

