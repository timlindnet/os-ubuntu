#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=lib/args.sh
source "$ROOT_DIR/lib/args.sh"
# shellcheck source=lib/runner.sh
source "$ROOT_DIR/lib/runner.sh"
# shellcheck source=lib/state.sh
source "$ROOT_DIR/lib/state.sh"

main() {
  parse_args "$@"

  case "$MODE" in
    help)
      print_help
      return 0
      ;;
    list_tags)
      list_tags "$ROOT_DIR"
      return 0
      ;;
    snapshot)
      ensure_state_repo "$ROOT_DIR/state"
      snapshot_create_commit \
        "$ROOT_DIR/state" \
        "${SNAPSHOT_NAME:-}" \
        "${SNAPSHOT_TAGS[@]:-}"
      return 0
      ;;
    list_snapshots)
      ensure_state_repo "$ROOT_DIR/state" --no-init
      snapshot_list_commits "$ROOT_DIR/state"
      return 0
      ;;
    apply_snapshot)
      ensure_state_repo "$ROOT_DIR/state" --no-init
      snapshot_apply_ref "$ROOT_DIR/state" "$APPLY_SNAPSHOT_REF"
      return 0
      ;;
    install)
      run_install "$ROOT_DIR"
      return 0
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac
}

main "$@"

