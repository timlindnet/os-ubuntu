need=()

# We only require ONE fetcher. Prefer what is already installed.
have_fetcher="false"
if have_cmd curl || have_cmd wget; then
  have_fetcher="true"
fi
if [[ "$have_fetcher" != "true" ]]; then
  need+=("curl")
fi

# ca-certificates is commonly present, but required for HTTPS.
if have_cmd dpkg && ! dpkg -s ca-certificates >/dev/null 2>&1; then
  need+=("ca-certificates")
fi
if ! have_cmd dpkg; then
  # Best-effort: keep it slim; don't force install if we can't check.
  :
fi

if [[ ${#need[@]} -eq 0 ]]; then
  log "Bootstrap requirements satisfied (fetcher + certs)."
  exit 0
fi

log "Installing bootstrap tools: ${need[*]}"
sudo_run apt-get update -y
sudo_run apt-get install -y "${need[@]}"

