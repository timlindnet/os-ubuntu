if have_cmd gcloud; then
  log "Google Cloud CLI already installed ($(gcloud --version 2>/dev/null | head -n1 || true))."
  exit 0
fi

# Prefer snap on Ubuntu to avoid custom apt repositories / key management.
if have_cmd snap; then
  log "Installing Google Cloud CLI (snap)..."
  sudo_run snap install google-cloud-cli --classic
  run gcloud --version
  exit 0
fi

log "Installing Google Cloud CLI (apt, best-effort)..."
if sudo_run apt-get install -y google-cloud-cli; then
  run gcloud --version
  exit 0
fi

die "Could not install google-cloud-cli (need snapd or an OS package that provides google-cloud-cli)."

