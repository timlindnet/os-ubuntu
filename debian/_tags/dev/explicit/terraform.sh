if have_cmd terraform; then
  log "Terraform already installed ($(terraform version 2>/dev/null | head -n1 || true))."
  exit 0
fi

# Prefer snap on Ubuntu to avoid custom apt repositories / key management.
if have_cmd snap; then
  log "Installing Terraform (snap)..."
  sudo_run snap install terraform --classic
  run terraform version
  exit 0
fi

log "Installing Terraform (apt, best-effort)..."
if sudo_run apt-get install -y terraform; then
  run terraform version
  exit 0
fi

die "Could not install terraform (need snapd or an OS package that provides terraform)."

