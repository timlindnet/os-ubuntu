if have_cmd docker; then
  log "Docker already installed ($(docker --version 2>/dev/null || true))."
  exit 0
fi

log "Installing Docker (docker.io)..."
sudo_run apt-get install -y docker.io

# Install a compose solution if available (plugin preferred).
if have_cmd docker && docker compose version >/dev/null 2>&1; then
  :
elif sudo_run apt-get install -y docker-compose-plugin; then
  :
elif sudo_run apt-get install -y docker-compose; then
  :
else
  warn "Could not install docker compose (plugin or legacy docker-compose)."
fi

# Enable docker service when systemd is present.
if have_cmd systemctl; then
  sudo_run systemctl enable --now docker || true
fi

# Add the invoking user to the docker group so docker works without sudo.
target_user="${SUDO_USER:-$USER}"
if getent group docker >/dev/null 2>&1; then
  :
else
  sudo_run groupadd docker || true
fi
sudo_run usermod -aG docker "$target_user" || true

log "Done (Docker). Log out/in for docker group changes to apply."

