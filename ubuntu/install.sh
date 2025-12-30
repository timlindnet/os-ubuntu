#!/usr/bin/env bash
set -euo pipefail

OS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$OS_ROOT/.." && pwd)"
OS="ubuntu"

# Shared helpers.
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# OS-specific helpers.
# shellcheck disable=SC1090
source "$OS_ROOT/_lib/os.sh"

# Shared installer logic.
# shellcheck source=lib/args.sh
source "$REPO_ROOT/lib/args.sh"
# shellcheck source=lib/runner.sh
source "$REPO_ROOT/lib/runner.sh"

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

