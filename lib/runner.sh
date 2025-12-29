#!/usr/bin/env bash
set -euo pipefail

run_install() {
  local root_dir="$1"

  ensure_ubuntu

  export OS_UBUNTU_ROOT="$root_dir"
  export OS_UBUNTU_STATE_DIR="$root_dir/state"

  log "Running always-on scripts: req/"
  run_folder "$root_dir/req" "req" || die "Failed in req/"

  log "Running always-on scripts: pre/"
  run_folder "$root_dir/pre" "pre" || die "Failed in pre/"

  local tags=()
  if [[ "${INSTALL_ALL:-false}" == "true" ]]; then
    mapfile -t tags < <(list_tags "$root_dir")
  else
    tags=("${TAGS[@]:-}")
  fi

  local tag
  for tag in "${tags[@]:-}"; do
    if [[ ! -d "$root_dir/$tag" ]]; then
      die "Unknown tag folder: $tag (missing directory: $root_dir/$tag)"
    fi

    log "Running tag folder: $tag/"
    run_folder "$root_dir/$tag" "$tag" || die "Failed in tag: $tag/"

    run_selected_for_tag "$root_dir" "$tag"
    run_optional_for_tag "$root_dir" "$tag"
  done
}

run_folder() {
  local folder="$1"
  local tag="$2"

  [[ -d "$folder" ]] || return 0

  local files=()
  # compgen returns non-zero when no matches; swallow it.
  while IFS= read -r f; do
    files+=("$f")
  done < <(compgen -G "$folder/*.sh" 2>/dev/null | sort || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    log "No scripts found in $tag/ (folder: $folder)"
    return 0
  fi

  local f
  for f in "${files[@]}"; do
    log "Running: $tag/$(basename "$f")"
    OS_UBUNTU_TAG="$tag" OS_UBUNTU_ROOT="$root_dir" bash "$root_dir/lib/run-script.sh" "$f"
  done
}

run_optional_for_tag() {
  local root_dir="$1"
  local tag="$2"
  local opt_dir="$root_dir/$tag/optional"

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
    run_folder "$opt_dir" "$tag/optional" || die "Failed in optional scripts for tag: $tag/"
    return 0
  fi

  return 0
}

run_selected_for_tag() {
  local root_dir="$1"
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

    local explicit="$root_dir/$tag/explicit/$base.sh"
    local optional="$root_dir/$tag/optional/$base.sh"

    local file=""
    local label=""
    if [[ -f "$explicit" ]]; then
      file="$explicit"
      label="$tag/explicit"
    elif [[ -f "$optional" ]]; then
      file="$optional"
      label="$tag/optional"
    else
      die "Selected script not found for tag '$tag': expected $explicit or $optional"
    fi

    log "Running: $label/$(basename "$file")"
    OS_UBUNTU_TAG="$tag" OS_UBUNTU_ROOT="$root_dir" bash "$root_dir/lib/run-script.sh" "$file"
  done
}

