if have_cmd aws; then
  aws_ver="$(aws --version 2>&1 || true)"
  log "AWS CLI is already installed (${aws_ver:-unknown version})."
  exit 0
fi

log "Installing AWS CLI (apt)..."

sudo_run apt-get install -y awscli

log "Done (AWS CLI)."

