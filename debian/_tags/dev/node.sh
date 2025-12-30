target_user="${SUDO_USER:-$USER}"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"
if [[ -z "$target_home" ]]; then
  die "Cannot resolve home directory for user: $target_user"
fi

# Precheck: if Node is already installed for the target user, stop immediately.
node_ver=""
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  if node_ver="$(sudo -u "$target_user" env HOME="$target_home" bash -lc 'command -v node >/dev/null 2>&1 && node -v')"; then
    log "Node is already installed for user $target_user ($node_ver)."
    exit 0
  fi
else
  if node_ver="$(env HOME="$target_home" bash -lc 'command -v node >/dev/null 2>&1 && node -v')"; then
    log "Node is already installed for user $target_user ($node_ver)."
    exit 0
  fi
fi

log "Installing nvm + latest stable Node for user: $target_user"

install_cmd=$(
  cat <<'EOF'
set -euo pipefail

export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  command -v wget >/dev/null 2>&1 || { echo "Need wget to install nvm" >&2; exit 1; }
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

# Install the latest stable Node release.
nvm install node
nvm alias default node >/dev/null
EOF
)

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  run sudo -u "$target_user" env HOME="$target_home" bash -lc "$install_cmd"
else
  run env HOME="$target_home" bash -lc "$install_cmd"
fi

log "Done (nvm + Node)."

