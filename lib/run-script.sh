#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: run-script.sh <script-path>" >&2
  exit 2
fi

SCRIPT_PATH="$1"

# Prefer OS_UBUNTU_ROOT set by the runner; otherwise resolve relative to script.
if [[ -n "${OS_UBUNTU_ROOT:-}" ]]; then
  ROOT="$OS_UBUNTU_ROOT"
else
  ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
fi

# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

ensure_ubuntu

# Execute script body in this shell (scripts are snippets, not standalone executables).
# shellcheck disable=SC1090
source "$SCRIPT_PATH"

