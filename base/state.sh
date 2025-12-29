source "$OS_UBUNTU_ROOT/lib/state.sh"

log "Ensuring nested state repo exists at: ${OS_UBUNTU_STATE_DIR:-$OS_UBUNTU_ROOT/state}"
ensure_state_repo "${OS_UBUNTU_STATE_DIR:-$OS_UBUNTU_ROOT/state}"

