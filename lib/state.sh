#!/usr/bin/env bash
set -euo pipefail

state_git_name() {
  if [[ -n "${OS_UBUNTU_STATE_GIT_NAME:-}" ]]; then
    printf "%s" "$OS_UBUNTU_STATE_GIT_NAME"
    return 0
  fi
  local u="${SUDO_USER:-${USER:-user}}"
  local h
  h="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo local)"
  printf "os-ubuntu snapshot (%s@%s)" "$u" "$h"
}

state_git_email() {
  if [[ -n "${OS_UBUNTU_STATE_GIT_EMAIL:-}" ]]; then
    printf "%s" "$OS_UBUNTU_STATE_GIT_EMAIL"
    return 0
  fi
  local u="${SUDO_USER:-${USER:-user}}"
  local h
  h="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo local)"
  printf "%s@%s.local" "$u" "$h"
}

git_state() {
  local state_dir="$1"
  shift || true
  git -C "$state_dir" \
    -c "user.name=$(state_git_name)" \
    -c "user.email=$(state_git_email)" \
    "$@"
}

ensure_state_repo() {
  local state_dir="$1"
  shift || true

  local no_init="false"
  if [[ "${1:-}" == "--no-init" ]]; then
    no_init="true"
  fi

  if [[ -d "$state_dir/.git" ]]; then
    return 0
  fi

  if [[ "$no_init" == "true" ]]; then
    die "State repo not initialized at: $state_dir (run ./install.sh --snapshot once, or run base/state.sh)"
  fi

  ensure_git_installed

  mkdir -p "$state_dir"
  if [[ ! -d "$state_dir/.git" ]]; then
    log "Initializing nested snapshot repo in: $state_dir"
    run git -C "$state_dir" init --initial-branch=main
  fi

  # Seed content so the repo is self-explanatory.
  mkdir -p "$state_dir/snapshot"
  if [[ ! -f "$state_dir/README.md" ]]; then
    cat >"$state_dir/README.md" <<'EOF'
# os-ubuntu state snapshots

This directory is a separate git repository created by `os-ubuntu`.

Each snapshot is a commit whose tree contains a `snapshot/` folder (package lists, sources, metadata) plus an `apply.sh` helper.

- List snapshots:
  - `git log --oneline --decorate`
- Jump between snapshots:
  - `git checkout <commit-or-tag>`
- Push to your own GitHub:
  - Add a remote and push (optional)
EOF
  fi

  if ! git -C "$state_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    run git -C "$state_dir" add -A
    run git_state "$state_dir" commit -m "init: state snapshot repo"
  fi
}

ensure_git_installed() {
  if have_cmd git; then
    return 0
  fi
  log "git not found; installing it (required for snapshots)"
  ensure_ubuntu
  sudo_run apt-get update -y
  sudo_run apt-get install -y git ca-certificates
}

snapshot_create_commit() {
  local state_dir="$1"
  local name="${2:-}"
  shift 2 || true
  local labels=("$@")

  ensure_state_repo "$state_dir"
  require_cmd git

  local created_utc
  created_utc="$(date -u +"%Y-%m-%dT%H%M%SZ")"
  if [[ -z "$name" ]]; then
    name="$created_utc"
  fi
  local safe_name
  safe_name="$(sanitize_ref_component "$name")"
  if [[ -z "$safe_name" ]]; then
    die "Snapshot name '$name' sanitized to empty; choose a different name."
  fi

  log "Capturing snapshot into $state_dir (name: $safe_name)"
  snapshot_write_tree "$state_dir" "$safe_name" "$created_utc" "${labels[@]:-}"

  run git -C "$state_dir" add -A

  local msg="snapshot: $safe_name"
  if [[ ${#labels[@]} -gt 0 ]]; then
    msg="$msg (labels: $(IFS=,; echo "${labels[*]}"))"
  fi
  run git_state "$state_dir" commit --allow-empty -m "$msg"

  local commit
  commit="$(git -C "$state_dir" rev-parse HEAD)"
  log "Snapshot commit: $commit"

  # Always tag snapshots so they're easy to reference
  local snapshot_tag
  snapshot_tag="$(unique_tag_name "$state_dir" "snapshot/$safe_name")"
  run git_state "$state_dir" tag -a "$snapshot_tag" -m "snapshot $safe_name" "$commit"

  local label
  for label in "${labels[@]:-}"; do
    local safe_label
    safe_label="$(sanitize_ref_component "$label")"
    [[ -n "$safe_label" ]] || continue
    local label_tag
    label_tag="$(unique_tag_name "$state_dir" "label/$safe_label/$safe_name")"
    run git_state "$state_dir" tag -a "$label_tag" -m "label $safe_label for snapshot $safe_name" "$commit"
  done

  log "Snapshot tags created: $snapshot_tag"
}

snapshot_list_commits() {
  local state_dir="$1"
  require_cmd git
  log "Snapshots (state repo): $state_dir"
  run git -C "$state_dir" --no-pager log --decorate --date=short --pretty=format:'%h %ad %d %s' -n 50
}

snapshot_apply_ref() {
  local state_dir="$1"
  local ref="$2"
  require_cmd git

  local commit
  commit="$(git -C "$state_dir" rev-parse --verify "$ref^{commit}" 2>/dev/null || true)"
  [[ -n "$commit" ]] || die "Cannot resolve snapshot ref in state repo: $ref"

  log "Applying snapshot ref '$ref' (commit: $commit)"
  require_cmd tar

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Extract snapshot/ directory from the commit without moving HEAD.
  git -C "$state_dir" archive --format=tar "$commit" snapshot | tar -xf - -C "$tmp"

  if [[ ! -f "$tmp/snapshot/apply.sh" ]]; then
    die "Snapshot does not contain snapshot/apply.sh (ref: $ref)"
  fi

  bash "$tmp/snapshot/apply.sh"
}

snapshot_write_tree() {
  local state_dir="$1"
  local name="$2"
  local created_utc="$3"
  shift 3 || true
  local labels=("$@")

  mkdir -p "$state_dir/snapshot"
  mkdir -p "$state_dir/snapshot/apt-sources"

  local hostname
  hostname="$(hostname 2>/dev/null || echo unknown)"

  local kernel
  kernel="$(uname -r 2>/dev/null || echo unknown)"

  local os_pretty="unknown"
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_pretty="${PRETTY_NAME:-${NAME:-unknown}}"
  fi

  # Metadata (simple JSON-ish; easy to read and diff)
  {
    printf '{\n'
    printf '  "name": "%s",\n' "$name"
    printf '  "created_utc": "%s",\n' "$created_utc"
    printf '  "hostname": "%s",\n' "$hostname"
    printf '  "kernel": "%s",\n' "$kernel"
    printf '  "os": "%s",\n' "$os_pretty"
    printf '  "labels": ['
    local first="true"
    local l
    for l in "${labels[@]:-}"; do
      if [[ "$first" == "true" ]]; then
        first="false"
      else
        printf ', '
      fi
      printf '"%s"' "$l"
    done
    printf ']\n'
    printf '}\n'
  } >"$state_dir/snapshot/meta.json"

  # APT manual packages (best practical restore list)
  if have_cmd apt-mark; then
    apt-mark showmanual | sort >"$state_dir/snapshot/apt-manual.txt" || true
  else
    printf "apt-mark not found\n" >"$state_dir/snapshot/apt-manual.txt"
  fi

  # Full dpkg inventory (mainly for diffing/auditing)
  if have_cmd dpkg-query; then
    dpkg-query -W -f='${Package}\t${Version}\n' | sort >"$state_dir/snapshot/dpkg-all.txt" || true
  else
    printf "dpkg-query not found\n" >"$state_dir/snapshot/dpkg-all.txt"
  fi

  # Snaps / flatpaks (optional)
  if have_cmd snap; then
    snap list >"$state_dir/snapshot/snap.txt" || true
  else
    printf "snap not installed\n" >"$state_dir/snapshot/snap.txt"
  fi

  if have_cmd flatpak; then
    flatpak list >"$state_dir/snapshot/flatpak.txt" || true
  else
    printf "flatpak not installed\n" >"$state_dir/snapshot/flatpak.txt"
  fi

  # APT sources (best-effort)
  if [[ -f /etc/apt/sources.list ]]; then
    cp /etc/apt/sources.list "$state_dir/snapshot/apt-sources/sources.list" 2>/dev/null || sudo_run cp /etc/apt/sources.list "$state_dir/snapshot/apt-sources/sources.list" || true
  fi
  if [[ -d /etc/apt/sources.list.d ]]; then
    rm -rf "$state_dir/snapshot/apt-sources/sources.list.d"
    mkdir -p "$state_dir/snapshot/apt-sources/sources.list.d"
    cp -a /etc/apt/sources.list.d/. "$state_dir/snapshot/apt-sources/sources.list.d/" 2>/dev/null || sudo_run cp -a /etc/apt/sources.list.d/. "$state_dir/snapshot/apt-sources/sources.list.d/" || true
  fi

  # Generate an apply helper that reads adjacent files
  cat >"$state_dir/snapshot/apply.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf "[snapshot-apply] %s\n" "$*"; }

sudo_run() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

apply_apt_manual() {
  local f="$HERE/apt-manual.txt"
  if [[ ! -f "$f" ]]; then
    log "No apt-manual.txt found; skipping apt."
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    log "apt-get not found; skipping apt."
    return 0
  fi
  log "Updating apt indexes..."
  sudo_run apt-get update -y

  # Filter comments/empty lines
  mapfile -t pkgs < <(grep -vE '^\s*($|#)' "$f" || true)
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log "No apt packages to install."
    return 0
  fi
  log "Installing ${#pkgs[@]} apt package(s) (additive)..."
  sudo_run apt-get install -y "${pkgs[@]}"
}

apply_snap() {
  local f="$HERE/snap.txt"
  command -v snap >/dev/null 2>&1 || return 0
  [[ -f "$f" ]] || return 0

  # `snap list` output: Name Version Rev Tracking Publisher Notes
  local names=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    case "$line" in
      Name\ *) continue ;;
    esac
    names+=("$(awk '{print $1}' <<<"$line")")
  done <"$f"

  if [[ ${#names[@]} -eq 0 ]]; then
    return 0
  fi

  log "Attempting to install ${#names[@]} snap(s) (best-effort)..."
  local n
  for n in "${names[@]}"; do
    # Skip common bases that are usually present or handled automatically
    case "$n" in
      core|core18|core20|core22|core24|bare|snapd) continue ;;
    esac
    sudo_run snap install "$n" >/dev/null 2>&1 || log "snap install failed (skipped): $n"
  done
}

apply_flatpak() {
  local f="$HERE/flatpak.txt"
  command -v flatpak >/dev/null 2>&1 || return 0
  [[ -f "$f" ]] || return 0

  # Flatpak install typically needs remotes; we only best-effort attempt by app ID.
  local ids=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    ids+=("$(awk '{print $1}' <<<"$line")")
  done <"$f"

  if [[ ${#ids[@]} -eq 0 ]]; then
    return 0
  fi

  log "Flatpak restore is best-effort (remotes may be missing)."
  local id
  for id in "${ids[@]}"; do
    sudo_run flatpak install -y --noninteractive "$id" >/dev/null 2>&1 || log "flatpak install failed (skipped): $id"
  done
}

apply_apt_manual
apply_snap
apply_flatpak

log "Done."
EOF
  chmod +x "$state_dir/snapshot/apply.sh" || true
}

sanitize_ref_component() {
  local s="$1"
  # Lower friction: allow A-Z a-z 0-9 . _ - and convert spaces to '-'
  s="${s// /-}"
  # Remove everything else
  s="$(printf "%s" "$s" | tr -cd 'A-Za-z0-9._-')"
  printf "%s" "$s"
}

unique_tag_name() {
  local state_dir="$1"
  local base="$2"

  local candidate="$base"
  local n=2
  while git -C "$state_dir" rev-parse -q --verify "refs/tags/$candidate" >/dev/null 2>&1; do
    candidate="${base}-${n}"
    n=$((n+1))
  done
  printf "%s" "$candidate"
}

