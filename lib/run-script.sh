#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: run-script.sh <script-path>" >&2
  exit 2
fi

SCRIPT_PATH="$1"

# Prefer OS root set by the runner; otherwise resolve from script path.
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

OS_ROOT="${LOADOUT_OS_ROOT:-${OS_UBUNTU_ROOT:-}}"
if [[ -z "$OS_ROOT" ]]; then
  case "$(basename "$SCRIPT_DIR")" in
    optional|explicit)
      OS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
      ;;
    *)
      OS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
      ;;
  esac
fi

REPO_ROOT="${LOADOUT_REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$OS_ROOT/.." && pwd)"
fi

# Shared helpers.
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# OS-specific helpers.
# shellcheck disable=SC1090
source "$OS_ROOT/_lib/os.sh"

ensure_os

# Execute script body in this shell (scripts are snippets, not standalone executables).
# shellcheck disable=SC1090
source "$SCRIPT_PATH"

