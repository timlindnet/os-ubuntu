if have_cmd az; then
  log "Azure CLI already installed ($(az version 2>/dev/null | head -n1 || true))."
  exit 0
fi

# Prefer snap on Ubuntu to avoid custom apt repositories / key management.
if have_cmd snap; then
  log "Installing Azure CLI (snap)..."
  sudo_run snap install azure-cli --classic
  run az version
  exit 0
fi

log "Installing Azure CLI (apt, best-effort)..."
if sudo_run apt-get install -y azure-cli; then
  run az version
  exit 0
fi

die "Could not install azure-cli (need snapd or an OS package that provides azure-cli)."

