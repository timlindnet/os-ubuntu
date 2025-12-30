repo_root="${LOADOUT_REPO_ROOT:-}"
if [[ -z "$repo_root" && -n "${OS_UBUNTU_ROOT:-}" ]]; then
  repo_root="$(cd "$OS_UBUNTU_ROOT/.." && pwd)"
fi
source "$repo_root/lib/state.sh"

state_dir="${LOADOUT_STATE_DIR:-${OS_UBUNTU_STATE_DIR:-}}"
if [[ -z "$state_dir" && -n "${OS_UBUNTU_ROOT:-}" ]]; then
  state_dir="$repo_root/state/ubuntu"
fi

log "Ensuring nested state repo exists at: $state_dir"
ensure_state_repo "$state_dir"

