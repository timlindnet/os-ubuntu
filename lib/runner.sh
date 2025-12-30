#!/usr/bin/env bash
set -euo pipefail

run_install() {
  local repo_root="$1"
  local os="$2"

  local os_root="$repo_root/$os"
  [[ -d "$os_root" ]] || die "Unknown OS folder: $os (missing directory: $os_root)"
  [[ -f "$os_root/lib/os.sh" ]] || die "Missing OS library: $os_root/lib/os.sh"

  export LOADOUT_REPO_ROOT="$repo_root"
  export LOADOUT_OS="$os"
  export LOADOUT_OS_ROOT="$os_root"
  export LOADOUT_STATE_DIR="$repo_root/state/$os"

  # Back-compat for existing Ubuntu scripts (env var names).
  if [[ "$os" == "ubuntu" ]]; then
    export OS_UBUNTU_ROOT="$os_root"
    export OS_UBUNTU_STATE_DIR="$LOADOUT_STATE_DIR"
  fi

  log "Running always-on scripts: $os/req/"
  run_folder "$repo_root" "$os_root/req" "$os/req" "req" || die "Failed in $os/req/"

  log "Running always-on scripts: $os/pre/"
  run_folder "$repo_root" "$os_root/pre" "$os/pre" "pre" || die "Failed in $os/pre/"

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

  local s
  for s in $spec; do
    local base="$s"
    if [[ "$base" == *.sh ]]; then
      base="${base%.sh}"
    fi

    local explicit="$os_root/$tag/explicit/$base.sh"
    local optional="$os_root/$tag/optional/$base.sh"

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
    LOADOUT_TAG="$tag" bash "$repo_root/lib/run-script.sh" "$file"
  done
}

