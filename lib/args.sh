#!/usr/bin/env bash
set -euo pipefail

# Globals set by parse_args
MODE="install"
TAGS=()
SNAPSHOT_NAME=""
SNAPSHOT_TAGS=()
APPLY_SNAPSHOT_REF=""

# Install selection
INSTALL_ALL="false"
OPTIONAL_GLOBAL="false"          # -o / --optional
OPTIONAL_TAGS=()                 # --<tag>-optional
# One-off script selector: --<tag>--<script>
# Runner will install <tag>/explicit/<script>.sh if present, otherwise <tag>/optional/<script>.sh.
declare -A SELECT_ONLY=()

print_help() {
  cat <<'EOF'
os-ubuntu: folder-driven Ubuntu setup (bash)

Usage:
  ./install.sh [--base] [--dev] [--gaming] ...
  ./install.sh --all
  ./install.sh --gaming -o
  ./install.sh --base--spotify
  ./install.sh --games--rs3

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
  - Optional scripts live under <tag>/optional/
    - Install all optional scripts for a tag: --<tag>-optional
    - Install one optional/explicit script: --<tag>--<script>
      - prefers <tag>/explicit/<script>.sh if present
      - else runs <tag>/optional/<script>.sh
    - Install optional scripts for supplied tags: -o / --optional
    - Install all tags incl. optional scripts: --all
  - Explicit scripts live under <tag>/explicit/
    - They are only installed via --<tag>--<script> (never via -o/--optional)
  - For curl/wget piping: bash -s -- <args>
EOF
}

parse_args() {
  MODE="install"
  TAGS=()
  SNAPSHOT_NAME=""
  SNAPSHOT_TAGS=()
  APPLY_SNAPSHOT_REF=""
  INSTALL_ALL="false"
  OPTIONAL_GLOBAL="false"
  OPTIONAL_TAGS=()
  SELECT_ONLY=()

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
      --all)
        MODE="install"
        INSTALL_ALL="true"
        OPTIONAL_GLOBAL="true"
        ;;
      -o|--optional)
        MODE="install"
        OPTIONAL_GLOBAL="true"
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
        # Install-time selectors:
        # - --<tag>
        # - --<tag>-optional
        # - --<tag>--<script>
        local spec="${a#--}"
        if [[ "$spec" == *"--"* ]]; then
          local tag="${spec%%--*}"
          local script="${spec#*--}"
          [[ -n "$tag" ]] || die "Invalid selector: $a"
          [[ -n "$script" ]] || die "Invalid selector (missing script): $a"
          add_unique TAGS "$tag"
          SELECT_ONLY["$tag"]="$(append_word "${SELECT_ONLY[$tag]:-}" "$script")"
        elif [[ "$spec" == *"-optional" ]]; then
          local tag="${spec%-optional}"
          [[ -n "$tag" ]] || die "Invalid selector: $a"
          add_unique TAGS "$tag"
          add_unique OPTIONAL_TAGS "$tag"
        else
          add_unique TAGS "$spec"
        fi
        ;;
      *)
        die "Unknown argument: $a"
        ;;
    esac
    i=$((i+1))
  done

  # Default tags (when installing) unless user explicitly provided tags.
  # Keep default minimal: base only.
  if [[ "$MODE" == "install" && "$INSTALL_ALL" != "true" && ${#TAGS[@]} -eq 0 ]]; then
    TAGS=("base")
  fi
}

append_word() {
  local existing="$1"
  local w="$2"
  if [[ -z "$existing" ]]; then
    printf "%s" "$w"
  else
    printf "%s %s" "$existing" "$w"
  fi
}

add_unique() {
  # add_unique ARRAY_NAME VALUE
  local arr_name="$1"
  local value="$2"
  [[ -n "$value" ]] || return 0

  # shellcheck disable=SC2178
  local -n arr="$arr_name"
  local x
  for x in "${arr[@]:-}"; do
    if [[ "$x" == "$value" ]]; then
      return 0
    fi
  done
  arr+=("$value")
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

