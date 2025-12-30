#!/usr/bin/env bash
set -euo pipefail

run_install() {
  local repo_root="$1"
  local os="$2"

  local os_root="$repo_root/$os"
  [[ -d "$os_root" ]] || die "Unknown OS folder: $os (missing directory: $os_root)"
  [[ -f "$os_root/_lib/os.sh" ]] || die "Missing OS library: $os_root/_lib/os.sh"

  export LOADOUT_REPO_ROOT="$repo_root"
  export LOADOUT_OS="$os"
  export LOADOUT_OS_ROOT="$os_root"

  # Back-compat for older Ubuntu scripts (env var name).
  if [[ "$os" == "ubuntu" ]]; then
    export OS_UBUNTU_ROOT="$os_root"
  fi

  log "Running always-on scripts: $os/_req/"
  run_folder "$repo_root" "$os_root/_req" "$os/_req" "req" || die "Failed in $os/_req/"

  log "Running always-on scripts: $os/_pre/"
  run_folder "$repo_root" "$os_root/_pre" "$os/_pre" "pre" || die "Failed in $os/_pre/"

  local tags=()
  if [[ "${INSTALL_ALL:-false}" == "true" ]]; then
    mapfile -t tags < <(list_tags "$os_root")
  else
    tags=("${TAGS[@]:-}")
  fi

  local tag
  for tag in "${tags[@]:-}"; do
    if [[ ! -d "$os_root/$tag" ]]; then
      die "Unknown tag folder for OS '$os': $tag (missing directory: $os_root/$tag)"
    fi

    log "Running tag folder: $os/$tag/"
    run_folder "$repo_root" "$os_root/$tag" "$os/$tag" "$tag" || die "Failed in tag: $os/$tag/"

    run_selected_for_tag "$repo_root" "$os_root" "$tag"
    run_optional_for_tag "$repo_root" "$os_root" "$tag"
  done
}

run_folder() {
  local repo_root="$1"
  local folder="$2"
  local label="$3"
  local tag="$4"

  [[ -d "$folder" ]] || return 0

  local files=()
  # compgen returns non-zero when no matches; swallow it.
  while IFS= read -r f; do
    files+=("$f")
  done < <(compgen -G "$folder/*.sh" 2>/dev/null | sort || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    log "No scripts found in $label/ (folder: $folder)"
    return 0
  fi

  local f
  for f in "${files[@]}"; do
    log "Running: $label/$(basename "$f")"
    LOADOUT_TAG="$tag" bash "$repo_root/lib/run-script.sh" "$f"
  done
}

run_optional_for_tag() {
  local repo_root="$1"
  local os_root="$2"
  local tag="$3"
  local opt_dir="$os_root/$tag/optional"

  [[ -d "$opt_dir" ]] || return 0

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
    run_folder "$repo_root" "$opt_dir" "$LOADOUT_OS/$tag/optional" "$tag" || die "Failed in optional scripts for tag: $tag/"
    return 0
  fi

  return 0
}

run_selected_for_tag() {
  local repo_root="$1"
  local os_root="$2"
  local tag="$3"
  local spec="${SELECT_ONLY[$tag]:-}"
  [[ -n "$spec" ]] || return 0

  log "Running selected scripts for tag: $tag/ ($spec)"

  resolve_selected_script_path() {
    # Usage: resolve_selected_script_path <dir> <selector_base>
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

      # Strip common numeric ordering prefixes.
      # Primary: NN-foo
      local stripped="$stem"
      if [[ "$stripped" =~ ^[0-9][0-9]- ]]; then
        stripped="${stripped:3}"
      elif [[ "$stripped" =~ ^[0-9]+- ]]; then
        # Best-effort fallback (e.g. 100-foo)
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
      die "Selector '$tag--$selector' is ambiguous; matches: ${matches[*]}"
    fi

    return 1
  }

  local s
  for s in $spec; do
    local base="$s"
    if [[ "$base" == *.sh ]]; then
      base="${base%.sh}"
    fi

    local file=""
    local label=""
    local explicit_dir="$os_root/$tag/explicit"
    local optional_dir="$os_root/$tag/optional"

    if [[ -d "$explicit_dir" ]]; then
      file="$(resolve_selected_script_path "$explicit_dir" "$base" || true)"
      if [[ -n "$file" ]]; then
        label="$tag/explicit"
      fi
    fi
    if [[ -z "$file" && -d "$optional_dir" ]]; then
      file="$(resolve_selected_script_path "$optional_dir" "$base" || true)"
      if [[ -n "$file" ]]; then
        label="$tag/optional"
      fi
    fi

    if [[ -z "$file" ]]; then
      die "Selected script not found for tag '$tag': $base (looked in: $explicit_dir, $optional_dir)"
    fi

    log "Running: $label/$(basename "$file")"
    LOADOUT_TAG="$tag" bash "$repo_root/lib/run-script.sh" "$file"
  done
}

