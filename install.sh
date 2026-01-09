#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared helpers.
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# CLI parsing.
# shellcheck source=lib/args.sh
source "$REPO_ROOT/lib/args.sh"

# OS detection and layered runner.
# shellcheck source=lib/detect.sh
source "$REPO_ROOT/lib/detect.sh"
# shellcheck source=lib/layer-runner.sh
source "$REPO_ROOT/lib/layer-runner.sh"

main() {
  parse_args "$@"

  loadout_read_os_release
  loadout_detect_family
  loadout_build_layer_chain "$REPO_ROOT"

  case "$MODE" in
    help)
      print_help
      return 0
      ;;
    list_tags)
      loadout_print_tag_catalog
      return 0
      ;;
    install)
      log "Detected OS: id=${LOADOUT_OS_ID} family=${LOADOUT_OS_FAMILY} version=${LOADOUT_OS_VERSION_ID:-unknown}"
      log "Using layer chain: $(loadout_join_by " -> " "${LOADOUT_LAYER_ROOTS_ARR[@]}")"
      loadout_run_install_layered "$REPO_ROOT"
      return 0
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac
}

main "$@"

