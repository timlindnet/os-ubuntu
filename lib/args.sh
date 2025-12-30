#!/usr/bin/env bash
set -euo pipefail

# Globals set by parse_args
MODE="install"
TAGS=()

# Install selection
INSTALL_ALL="false"
OPTIONAL_GLOBAL="false"          # -o / --optional
OPTIONAL_TAGS=()                 # --<tag>-optional
# One-off script selector: --<tag>--<script>
# Runner will install <tag>/explicit/<script>.sh if present, otherwise <tag>/optional/<script>.sh.
declare -A SELECT_ONLY=()

print_help() {
  cat <<'EOF'
loadout: folder-driven OS setup (bash)

Usage:
  curl -fsSL https://loadout.timlind.net | bash -s -- ubuntu --base --dev --gaming

Modes:
  --help                  Show help
  --list-tags             List available tag folders

Notes:
  - Always-run folders (relative to the OS root): req/, pre/
  - Tag folders run only when selected: base/, dev/, gaming/, ...
  - Optional scripts live under <tag>/optional/
    - Install all optional scripts for a tag: --<tag>-optional
    - Install one optional/explicit script: --<tag>--<script>
      - prefers <tag>/explicit/<script>.sh if present
      - else runs <tag>/optional/<script>.sh
    - Install optional scripts for supplied tags: -o / --optional
    - Install all tag folders: --all-tags
      - To also run optional scripts: --all-tags -o
  - Explicit scripts live under <tag>/explicit/
    - They are only installed via --<tag>--<script> (never via -o/--optional)
  - For curl/wget piping: bash -s -- <args>
EOF
}

parse_args() {
  MODE="install"
  TAGS=()
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
      --all-tags|--all)
        MODE="install"
        INSTALL_ALL="true"
        ;;
      -o|--optional)
        MODE="install"
        OPTIONAL_GLOBAL="true"
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
      .git|_lib|_req|_pre|_*) continue ;;
    esac
    printf "%s\n" "$name"
  done | sort
}

