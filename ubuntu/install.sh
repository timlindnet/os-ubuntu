#!/usr/bin/env bash
set -euo pipefail

OS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$OS_ROOT/.." && pwd)"
OS="ubuntu"
STATE_DIR="$REPO_ROOT/state/$OS"

# Shared helpers.
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# OS-specific helpers.
# shellcheck disable=SC1090
source "$OS_ROOT/lib/os.sh"

# Shared installer logic.
# shellcheck source=lib/args.sh
source "$REPO_ROOT/lib/args.sh"
# shellcheck source=lib/runner.sh
source "$REPO_ROOT/lib/runner.sh"
# shellcheck source=lib/state.sh
source "$REPO_ROOT/lib/state.sh"

main() {
  parse_args "$@"

  case "$MODE" in
    help)
      print_help
      return 0
      ;;
    list_tags)
      list_tags "$OS_ROOT"
      return 0
      ;;
    snapshot)
      ensure_state_repo "$STATE_DIR"
      snapshot_create_commit \
        "$STATE_DIR" \
        "${SNAPSHOT_NAME:-}" \
        "${SNAPSHOT_TAGS[@]:-}"
      return 0
      ;;
    list_snapshots)
      ensure_state_repo "$STATE_DIR" --no-init
      snapshot_list_commits "$STATE_DIR"
      return 0
      ;;
    apply_snapshot)
      ensure_state_repo "$STATE_DIR" --no-init
      snapshot_apply_ref "$STATE_DIR" "$APPLY_SNAPSHOT_REF"
      return 0
      ;;
    install)
      run_install "$REPO_ROOT" "$OS"
      return 0
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac
}

main "$@"

