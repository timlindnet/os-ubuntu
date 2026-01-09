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
if ! dnf_is_installed ca-certificates; then
  need+=("ca-certificates")
fi

if [[ ${#need[@]} -eq 0 ]]; then
  log "Bootstrap requirements satisfied (fetcher + certs)."
  exit 0
fi

log "Installing bootstrap tools: ${need[*]}"
dnf_install "${need[@]}"

