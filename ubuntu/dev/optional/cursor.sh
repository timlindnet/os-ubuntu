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

# Cursor's postinst may prompt to add its apt repository; answer "yes" up front.
if have_cmd debconf-set-selections; then
  sudo_run sh -c 'printf "%s\n" "cursor cursor/add-cursor-repo boolean true" | debconf-set-selections'
fi

# Prefer apt installing local deb (pulls dependencies). Fallback to dpkg if needed.
apt_recover_dpkg
if sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp"; then
  :
else
  warn "apt-get install of local .deb failed; trying dpkg + fix deps"
  sudo_run dpkg -i "$tmp" || true
  apt_recover_dpkg
  sudo_run env DEBIAN_FRONTEND=noninteractive apt-get -f install -y
fi

log "Done (Cursor)."

