if have_cmd ansible; then
  log "Ansible already installed ($(ansible --version 2>/dev/null | head -n1 || true))."
  exit 0
fi

log "Installing Ansible..."
sudo_run apt-get install -y ansible

run ansible --version

log "Done (Ansible)."

