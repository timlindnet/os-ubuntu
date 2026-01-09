#!/usr/bin/env bash
set -euo pipefail

# Layered folder runner.
#
# A "layer" is a root directory (e.g. debian/, debian/ubuntu/, debian/ubuntu/24.04/)
# that may contain:
# - _lib/
# - _req/
# - _pre/
# - _tags/<tag>/
#
# When running a folder (e.g. "_pre" or "_tags/dev"), we merge scripts across layers:
# - later (more specific) layers override earlier layers by basename
# - scripts run in lexicographic order by basename

loadout_join_by() {
  local sep="$1"
  shift
  local out=""
  local x
  for x in "$@"; do
    if [[ -z "$out" ]]; then
      out="$x"
    else
      out="${out}${sep}${x}"
    fi
  done
  printf "%s" "$out"
}

loadout_layered_list_scripts() {
  # Usage: loadout_layered_list_scripts <rel-folder>
  #
  # Requires: LOADOUT_LAYER_ROOTS_ARR=()
  #
  # Output (global):
  # - LOADOUT_LAYERED_SCRIPTS_ARR: array of file paths to execute
  local rel="$1"

  declare -A by_base=()
  local layer
  for layer in "${LOADOUT_LAYER_ROOTS_ARR[@]}"; do
    local dir="$layer/$rel"
    [[ -d "$dir" ]] || continue

    local f
    for f in "$dir"/*.sh; do
      [[ -f "$f" ]] || continue
      by_base["$(basename "$f")"]="$f"
    done
  done

  local bases=()
  local b
  for b in "${!by_base[@]}"; do
    bases+=("$b")
  done

  if [[ ${#bases[@]} -eq 0 ]]; then
    LOADOUT_LAYERED_SCRIPTS_ARR=()
    return 0
  fi

  # Sort by basename for stable ordering.
  mapfile -t bases < <(printf "%s\n" "${bases[@]}" | sort)

  LOADOUT_LAYERED_SCRIPTS_ARR=()
  for b in "${bases[@]}"; do
    LOADOUT_LAYERED_SCRIPTS_ARR+=("${by_base[$b]}")
  done
}

loadout_run_layered_folder() {
  # Usage: loadout_run_layered_folder <repo-root> <rel-folder> <label> <tag>
  local repo_root="$1"
  local rel="$2"
  local label="$3"
  local tag="$4"

  loadout_layered_list_scripts "$rel"
  if [[ ${#LOADOUT_LAYERED_SCRIPTS_ARR[@]} -eq 0 ]]; then
    log "No scripts found in $label/ (rel: $rel)"
    return 0
  fi

  local f
  for f in "${LOADOUT_LAYERED_SCRIPTS_ARR[@]}"; do
    log "Running: $label/$(basename "$f")"
    LOADOUT_TAG="$tag" bash "$repo_root/lib/run-script.sh" "$f"
  done
}

loadout_list_all_tags() {
  # Usage: loadout_list_all_tags
  #
  # Prints tag names (one per line), merged across layers.
  declare -A seen=()
  local layer
  for layer in "${LOADOUT_LAYER_ROOTS_ARR[@]}"; do
    local dir="$layer/_tags"
    [[ -d "$dir" ]] || continue
    local d
    for d in "$dir"/*/; do
      [[ -d "$d" ]] || continue
      local name
      name="$(basename "$d")"
      [[ "$name" == _* ]] && continue
      seen["$name"]=1
    done
  done

  local out=()
  local t
  for t in "${!seen[@]}"; do
    out+=("$t")
  done
  if [[ ${#out[@]} -eq 0 ]]; then
    return 0
  fi
  printf "%s\n" "${out[@]}" | sort
}

loadout_strip_order_prefix() {
  # Usage: loadout_strip_order_prefix <stem>
  #
  # Strips common numeric ordering prefixes from a script stem:
  # - NN-foo -> foo
  # - NNN-foo (best-effort) -> foo
  local stem="$1"
  if [[ "$stem" =~ ^[0-9][0-9]- ]]; then
    printf "%s" "${stem:3}"
  elif [[ "$stem" =~ ^[0-9]+- ]]; then
    printf "%s" "${stem#*-}"
  else
    printf "%s" "$stem"
  fi
}

loadout_layered_list_selectors() {
  # Usage: loadout_layered_list_selectors <rel-folder>
  #
  # Prints selector bases (one per line), merged across layers.
  local rel="$1"
  loadout_layered_list_scripts "$rel"

  local selectors=()
  local f
  for f in "${LOADOUT_LAYERED_SCRIPTS_ARR[@]}"; do
    local name
    name="$(basename "$f")"
    local stem="${name%.sh}"
    selectors+=("$(loadout_strip_order_prefix "$stem")")
  done

  if [[ ${#selectors[@]} -eq 0 ]]; then
    return 0
  fi

  printf "%s\n" "${selectors[@]}" | sort -u
}

loadout_selector_display_name_from_file() {
  # Usage: loadout_selector_display_name_from_file <selector> <file-path>
  #
  # Allows nicer human-readable names for some scripts.
  local selector="$1"
  local file="$2"

  # Convention: show node installed via nvm as "node (nvm)".
  if [[ "$selector" == "node" ]]; then
    if grep -qi "nvm" "$file" 2>/dev/null; then
      printf "%s" "node (nvm)"
      return 0
    fi
  fi

  printf "%s" "$selector"
}

loadout_layered_list_display_names() {
  # Usage: loadout_layered_list_display_names <rel-folder>
  #
  # Prints human-readable display names (one per line), merged across layers.
  # Keeps stable ordering by selector base.
  local rel="$1"
  loadout_layered_list_scripts "$rel"

  declare -A by_selector=()
  local f
  for f in "${LOADOUT_LAYERED_SCRIPTS_ARR[@]}"; do
    local name
    name="$(basename "$f")"
    local stem="${name%.sh}"
    local selector
    selector="$(loadout_strip_order_prefix "$stem")"
    local display
    display="$(loadout_selector_display_name_from_file "$selector" "$f")"

    # If multiple layers provide the same selector, prefer the more descriptive name.
    if [[ -z "${by_selector[$selector]:-}" ]]; then
      by_selector["$selector"]="$display"
    else
      if [[ "${by_selector[$selector]}" == "$selector" && "$display" != "$selector" ]]; then
        by_selector["$selector"]="$display"
      fi
    fi
  done

  local keys=()
  local k
  for k in "${!by_selector[@]}"; do
    keys+=("$k")
  done
  if [[ ${#keys[@]} -eq 0 ]]; then
    return 0
  fi
  mapfile -t keys < <(printf "%s\n" "${keys[@]}" | sort)

  local out=()
  for k in "${keys[@]}"; do
    out+=("${by_selector[$k]}")
  done
  printf "%s\n" "${out[@]}"
}

loadout_print_wrapped_kv_list() {
  # Usage: loadout_print_wrapped_kv_list <indent> <key> [values...]
  #
  # Prints a readable, wrapped "key: v1 v2 ..." list.
  local indent="$1"
  local key="$2"
  shift 2

  local width="${COLUMNS:-80}"
  local prefix="${indent}${key}: "
  local cont_prefix
  cont_prefix="$(printf "%*s" "${#prefix}" "")"

  if [[ $# -eq 0 ]]; then
    printf "%s%s\n" "$prefix" "(none)"
    return 0
  fi

  local line="$prefix"
  local w
  for w in "$@"; do
    if [[ "$line" == "$prefix" ]]; then
      line+="$w"
      continue
    fi
    if (( ${#line} + 1 + ${#w} > width )); then
      printf "%s\n" "$line"
      line="${cont_prefix}${w}"
    else
      line+=" $w"
    fi
  done
  printf "%s\n" "$line"
}

loadout_print_tag_catalog() {
  # Usage: loadout_print_tag_catalog
  #
  # Human-readable tag listing for --list-tags.
  local tags=()
  mapfile -t tags < <(loadout_list_all_tags)
  if [[ ${#tags[@]} -eq 0 ]]; then
    return 0
  fi

  local tag
  for tag in "${tags[@]}"; do
    printf "%s\n" "$tag"

    local defaults=()
    mapfile -t defaults < <(loadout_layered_list_display_names "_tags/$tag" || true)
    loadout_print_wrapped_kv_list "  " "default" "${defaults[@]}"

    local optional=()
    mapfile -t optional < <(loadout_layered_list_selectors "_tags/$tag/optional" || true)
    loadout_print_wrapped_kv_list "  " "optional" "${optional[@]}"

    local explicit=()
    mapfile -t explicit < <(loadout_layered_list_selectors "_tags/$tag/explicit" || true)
    loadout_print_wrapped_kv_list "  " "explicit" "${explicit[@]}"

    printf "\n"
  done
}

loadout_resolve_selected_script_path() {
  # Usage: loadout_resolve_selected_script_path <dir> <selector_base>
  #
  # Resolves a selector like "ssh-config" to:
  # - <dir>/ssh-config.sh (exact), OR
  # - <dir>/NN-ssh-config.sh (two-digit order prefix), OR
  # - <dir>/NNN-ssh-config.sh (best-effort: numeric prefix)
  #
  # If multiple matches exist, returns failure.
  local dir="$1"
  local selector="$2"

  local exact="$dir/$selector.sh"
  if [[ -f "$exact" ]]; then
    printf "%s" "$exact"
    return 0
  fi

  local matches=()
  local f
  for f in "$dir"/*.sh; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f")"
    local stem="${name%.sh}"

    local stripped="$stem"
    if [[ "$stripped" =~ ^[0-9][0-9]- ]]; then
      stripped="${stripped:3}"
    elif [[ "$stripped" =~ ^[0-9]+- ]]; then
      stripped="${stripped#*-}"
    fi

    if [[ "$stripped" == "$selector" ]]; then
      matches+=("$f")
    fi
  done

  if [[ ${#matches[@]} -eq 1 ]]; then
    printf "%s" "${matches[0]}"
    return 0
  fi
  if [[ ${#matches[@]} -gt 1 ]]; then
    die "Selector '$selector' is ambiguous in dir: $dir; matches: ${matches[*]}"
  fi

  return 1
}

loadout_find_selected_script_across_layers() {
  # Usage: loadout_find_selected_script_across_layers <rel-dir> <selector_base>
  #
  # Searches from most-specific layer to base layer, and returns first match.
  local rel_dir="$1"
  local selector="$2"

  local i
  for ((i=${#LOADOUT_LAYER_ROOTS_ARR[@]}-1; i>=0; i--)); do
    local layer="${LOADOUT_LAYER_ROOTS_ARR[$i]}"
    local dir="$layer/$rel_dir"
    [[ -d "$dir" ]] || continue
    local p
    p="$(loadout_resolve_selected_script_path "$dir" "$selector" || true)"
    if [[ -n "$p" ]]; then
      printf "%s" "$p"
      return 0
    fi
  done

  return 1
}

loadout_run_install_layered() {
  # Usage: loadout_run_install_layered <repo-root>
  local repo_root="$1"

  export LOADOUT_REPO_ROOT="$repo_root"
  export LOADOUT_LAYER_ROOTS
  LOADOUT_LAYER_ROOTS="$(loadout_join_by ":" "${LOADOUT_LAYER_ROOTS_ARR[@]}")"
  export LOADOUT_PRIMARY_ROOT="${LOADOUT_LAYER_ROOTS_ARR[${#LOADOUT_LAYER_ROOTS_ARR[@]}-1]}"

  # Back-compat env var for older Ubuntu scripts.
  # (Some existing scripts refer to OS_UBUNTU_ROOT; keep it pointing at the
  # most specific root when on Ubuntu.)
  if [[ "${LOADOUT_OS_ID:-}" == "ubuntu" ]]; then
    export OS_UBUNTU_ROOT="$LOADOUT_PRIMARY_ROOT"
  fi
  export LOADOUT_OS_ROOT="$LOADOUT_PRIMARY_ROOT"

  log "Running always-on scripts: _req/"
  loadout_run_layered_folder "$repo_root" "_req" "_req" "req" || die "Failed in _req/"

  log "Running always-on scripts: _pre/"
  loadout_run_layered_folder "$repo_root" "_pre" "_pre" "pre" || die "Failed in _pre/"

  local tags=()
  if [[ "${INSTALL_ALL:-false}" == "true" ]]; then
    mapfile -t tags < <(loadout_list_all_tags)
  else
    tags=("${TAGS[@]:-}")
  fi

  local tag
  for tag in "${tags[@]:-}"; do
    # Ensure the tag exists in at least one layer, otherwise fail fast.
    local tag_ok="false"
    local layer
    for layer in "${LOADOUT_LAYER_ROOTS_ARR[@]}"; do
      if [[ -d "$layer/_tags/$tag" ]]; then
        tag_ok="true"
        break
      fi
    done
    if [[ "$tag_ok" != "true" ]]; then
      die "Unknown tag: $tag (not found under _tags/ in any layer)"
    fi

    log "Running tag folder: $tag/"
    loadout_run_layered_folder "$repo_root" "_tags/$tag" "_tags/$tag" "$tag" || die "Failed in tag: $tag"

    loadout_run_selected_for_tag "$repo_root" "$tag"
    loadout_run_optional_for_tag "$repo_root" "$tag"
  done
}

loadout_run_optional_for_tag() {
  local repo_root="$1"
  local tag="$2"

  local opt_rel="_tags/$tag/optional"

  local run_all="false"
  if [[ "${OPTIONAL_GLOBAL:-false}" == "true" ]]; then
    run_all="true"
  fi
  local t
  for t in "${OPTIONAL_TAGS[@]:-}"; do
    if [[ "$t" == "$tag" ]]; then
      run_all="true"
      break
    fi
  done

  if [[ "$run_all" == "true" ]]; then
    log "Running optional scripts for tag: $tag/"
    loadout_run_layered_folder "$repo_root" "$opt_rel" "_tags/$tag/optional" "$tag" || die "Failed in optional scripts for tag: $tag"
  fi
}

loadout_run_selected_for_tag() {
  local repo_root="$1"
  local tag="$2"

  local spec="${SELECT_ONLY[$tag]:-}"
  [[ -n "$spec" ]] || return 0

  log "Running selected scripts for tag: $tag/ ($spec)"

  local s
  for s in $spec; do
    local base="$s"
    if [[ "$base" == *.sh ]]; then
      base="${base%.sh}"
    fi

    local file=""
    local label=""

    file="$(loadout_find_selected_script_across_layers "_tags/$tag/explicit" "$base" || true)"
    if [[ -n "$file" ]]; then
      label="_tags/$tag/explicit"
    else
      file="$(loadout_find_selected_script_across_layers "_tags/$tag/optional" "$base" || true)"
      if [[ -n "$file" ]]; then
        label="_tags/$tag/optional"
      fi
    fi

    if [[ -z "$file" ]]; then
      die "Selected script not found for tag '$tag': $base (looked in: _tags/$tag/explicit, _tags/$tag/optional across layers)"
    fi

    log "Running: $label/$(basename "$file")"
    LOADOUT_TAG="$tag" bash "$repo_root/lib/run-script.sh" "$file"
  done
}

