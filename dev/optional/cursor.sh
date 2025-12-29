if have_cmd cursor; then
  log "Cursor already installed."
  exit 0
fi

arch="$(dpkg --print-architecture 2>/dev/null || true)"
case "$arch" in
  amd64) platform="linux-x64-deb" ;;
  arm64) platform="linux-arm64-deb" ;;
  *)
    die "Unsupported architecture for Cursor install: ${arch:-unknown}"
    ;;
esac

log "Installing Cursor (.deb, ${arch})..."

page="$(fetch_url "https://cursor.com/download")"
url="$(printf "%s" "$page" | grep -oE "https://api2\\.cursor\\.sh/updates/download/golden/${platform}/cursor/[^\"[:space:]]+" | head -n1 || true)"

if [[ -z "$url" ]]; then
  die "Could not find Cursor download URL on cursor.com/download for platform: $platform"
fi

tmp="$(mktemp --suffix=.deb)"
trap 'rm -f "$tmp"' RETURN

fetch_url "$url" >"$tmp"

# Prefer apt installing local deb (pulls dependencies). Fallback to dpkg if needed.
if sudo_run apt-get install -y "$tmp"; then
  :
else
  warn "apt-get install of local .deb failed; trying dpkg + fix deps"
  sudo_run dpkg -i "$tmp" || true
  sudo_run apt-get -f install -y
fi

log "Done (Cursor)."

