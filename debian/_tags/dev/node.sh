target_user="${SUDO_USER:-$USER}"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"
if [[ -z "$target_home" ]]; then
  die "Cannot resolve home directory for user: $target_user"
fi

log "Ensuring nvm + Node LTS for user: $target_user"

install_nvm_cmd=$(
  cat <<'EOF'
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# Fast path (must be at the beginning): if nvm exists, LTS is installed, and
# default alias already points at lts/*, do nothing.
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"

  lts_path="$(nvm which 'lts/*' 2>/dev/null || true)"

  default_ok="false"
  if [[ -f "$NVM_DIR/alias/default" ]]; then
    default_alias="$(<"$NVM_DIR/alias/default")"
    if [[ "$default_alias" == "lts/*" ]]; then
      default_ok="true"
    fi
  fi

  if [[ -n "$lts_path" && -x "$lts_path" && "$default_ok" == "true" ]]; then
    exit 0
  fi
fi

# Install nvm (pinned) if missing.
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  if ! command -v wget >/dev/null 2>&1; then
    echo "Need wget to install nvm" >&2
    exit 1
  fi
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

# Install latest LTS if missing.
lts_path="$(nvm which 'lts/*' 2>/dev/null || true)"
if [[ -z "$lts_path" || ! -x "$lts_path" ]]; then
  nvm install --lts
fi

# Ensure default alias points to LTS.
if [[ ! -f "$NVM_DIR/alias/default" ]] || [[ "$( <"$NVM_DIR/alias/default")" != "lts/*" ]]; then
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

