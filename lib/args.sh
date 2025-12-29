#!/usr/bin/env bash
set -euo pipefail

# Globals set by parse_args
MODE="install"
TAGS=()
SNAPSHOT_NAME=""
SNAPSHOT_TAGS=()
APPLY_SNAPSHOT_REF=""

print_help() {
  cat <<'EOF'
os-ubuntu: folder-driven Ubuntu setup (bash)

Usage:
  ./install.sh [--base] [--dev] [--gaming] ...

Modes:
  --help                  Show help
  --list-tags             List available tag folders

Snapshots (stored as commits in ./state):
  --snapshot [name]       Capture state and commit it (also tags snapshot/<name>)
  --snapshot-tag <label>  Add extra annotated tag(s) label/<label>/<name>
  --list-snapshots         List snapshot commits (git log in ./state)
  --apply-snapshot <ref>  Apply snapshot by git ref (commit SHA, tag, etc.)

Notes:
  - Always-run folders: req/, pre/
  - Tag folders run only when selected: base/, dev/, gaming/, ...
  - For curl/wget piping: bash -s -- <args>
EOF
}

parse_args() {
  MODE="install"
  TAGS=()
  SNAPSHOT_NAME=""
  SNAPSHOT_TAGS=()
  APPLY_SNAPSHOT_REF=""

  local argv=("$@")
  local i=0
  while [[ $i -lt ${#argv[@]} ]]; do
    local a="${argv[$i]}"
    case "$a" in
      -h|--help)
        MODE="help"
        return 0
        ;;
      --list-tags)
        MODE="list_tags"
        return 0
        ;;
      --snapshot)
        MODE="snapshot"
        # Optional name if next arg exists and isn't another flag
        if [[ $((i+1)) -lt ${#argv[@]} && "${argv[$((i+1))]}" != --* ]]; then
          SNAPSHOT_NAME="${argv[$((i+1))]}"
          i=$((i+1))
        fi
        ;;
      --snapshot-tag)
        MODE="snapshot"
        if [[ $((i+1)) -ge ${#argv[@]} ]]; then
          die "--snapshot-tag requires a value"
        fi
        SNAPSHOT_TAGS+=("${argv[$((i+1))]}")
        i=$((i+1))
        ;;
      --list-snapshots)
        MODE="list_snapshots"
        return 0
        ;;
      --apply-snapshot)
        MODE="apply_snapshot"
        if [[ $((i+1)) -ge ${#argv[@]} ]]; then
          die "--apply-snapshot requires a git ref (commit SHA, tag, etc.)"
        fi
        APPLY_SNAPSHOT_REF="${argv[$((i+1))]}"
        i=$((i+1))
        ;;
      --*)
        # Treat unknown --foo as a tag name "foo"
        TAGS+=("${a#--}")
        ;;
      *)
        die "Unknown argument: $a"
        ;;
    esac
    i=$((i+1))
  done

  # Default tags (when installing) unless user explicitly provided tags.
  # Keep default minimal: base only.
  if [[ "$MODE" == "install" && ${#TAGS[@]} -eq 0 ]]; then
    TAGS=("base")
  fi
}

list_tags() {
  local root_dir="$1"
  local d
  for d in "$root_dir"/*/; do
    [[ -d "$d" ]] || continue
    local name
    name="$(basename "$d")"
    case "$name" in
      .git|lib|req|pre|state) continue ;;
    esac
    printf "%s\n" "$name"
  done | sort
}

