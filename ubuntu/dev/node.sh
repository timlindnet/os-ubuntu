target_user="${SUDO_USER:-$USER}"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"
if [[ -z "$target_home" ]]; then
  die "Cannot resolve home directory for user: $target_user"
fi

log "Installing nvm + Node LTS for user: $target_user"

install_nvm_cmd=$(
  cat <<'EOF'
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# Fast path: if nvm exists and Node LTS + default alias are already in place,
# do nothing (avoid network and avoid reconfiguring).
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"

  alias_ok="false"
  if [[ -f "$NVM_DIR/alias/default" ]] && grep -qx "lts/*" "$NVM_DIR/alias/default"; then
    alias_ok="true"
  fi

  lts_ok="false"
  if nvm ls --no-colors --lts 2>/dev/null | grep -qE '\bv[0-9]+'; then
    lts_ok="true"
  fi

  if [[ "$alias_ok" == "true" && "$lts_ok" == "true" ]]; then
    exit 0
  fi
fi

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  else
    echo "Need curl or wget to install nvm" >&2
    exit 1
  fi
fi
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

if ! nvm ls --no-colors --lts 2>/dev/null | grep -qE '\bv[0-9]+'; then
  nvm install --lts
fi

if [[ ! -f "$NVM_DIR/alias/default" ]] || ! grep -qx "lts/*" "$NVM_DIR/alias/default"; then
  nvm alias default 'lts/*' >/dev/null
fi
EOF
)

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  run sudo -u "$target_user" env HOME="$target_home" bash -lc "$install_nvm_cmd"
else
  run env HOME="$target_home" bash -lc "$install_nvm_cmd"
fi

log "Done (nvm + Node LTS)."

