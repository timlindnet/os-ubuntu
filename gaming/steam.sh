log "Installing Steam (apt)..."

# Avoid any interactive apt/debconf prompts.
export DEBIAN_FRONTEND=noninteractive

# Ensure dpkg isn't left half-configured (blocks apt operations).
apt_recover_dpkg

# Steam packages are in Ubuntu multiverse. Make this snippet fool-proof by
# enabling the required components here (idempotent).
need_apt_update="no"
if ! have_cmd add-apt-repository; then
  # add-apt-repository is provided by software-properties-common
  log "Installing add-apt-repository helper (software-properties-common)..."
  sudo_run apt-get update -y
  sudo_run apt-get install -y software-properties-common
fi

log "Ensuring apt components enabled (universe/restricted/multiverse)..."
sudo_run add-apt-repository -y universe >/dev/null
sudo_run add-apt-repository -y restricted >/dev/null
sudo_run add-apt-repository -y multiverse >/dev/null
need_apt_update="yes"

# Steam is a 32-bit program and expects i386 multiarch enabled.
# If an Nvidia proprietary driver is present, Steam also needs 32-bit Nvidia libs.
added_i386_arch="no"
if ! dpkg --print-foreign-architectures | grep -qx "i386"; then
  log "Enabling i386 multiarch (required for Steam)..."
  sudo_run dpkg --add-architecture i386
  added_i386_arch="yes"
fi

# Refresh apt lists if we changed repos and/or architectures.
if [[ "$need_apt_update" == "yes" || "$added_i386_arch" == "yes" ]]; then
  sudo_run apt-get update -y
fi

# Avoid Steam's interactive debconf prompt about missing 32-bit Nvidia driver libs.
# NOTE: On Ubuntu 24+, `nvidia-driver-libs:i386` is often not published; the 32-bit
# libs are provided by versioned packages like `libnvidia-gl-<version>:i386`.
if [[ -e /proc/driver/nvidia/version ]] || have_cmd nvidia-smi; then
  log "Nvidia driver detected; ensuring 32-bit Nvidia libs for Steam..."

  pkg_installable() {
    # True iff apt has an install candidate (not "Candidate: (none)").
    local pkg="$1"
    local cand=""
    cand="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
    [[ -n "$cand" && "$cand" != "(none)" ]]
  }

  # Legacy (some Ubuntu releases): metapackage exists for i386.
  if pkg_installable "nvidia-driver-libs:i386"; then
    if ! dpkg -s nvidia-driver-libs:i386 >/dev/null 2>&1; then
      sudo_run apt-get install -y nvidia-driver-libs:i386 || warn "Failed installing nvidia-driver-libs:i386 (continuing)."
    fi
  else
    # Preferred (Ubuntu 24+): install versioned 32-bit GL libs.
    # Try, in order:
    #  - match currently installed amd64 libnvidia-gl-### (best)
    #  - match driver major version from nvidia-smi or /proc (good)
    #  - fall back to newest libnvidia-gl-### candidate (best effort)

    best_pkg=""

    # 1) Installed amd64 libnvidia-gl-###.
    best_pkg="$(dpkg-query -W -f='${Package}\n' 'libnvidia-gl-[0-9]*' 2>/dev/null | sort -V | awk 'END{print}')"

    # 2) Driver major version (e.g. 550) -> libnvidia-gl-550.
    if [[ -z "${best_pkg:-}" ]]; then
      drv_major=""
      if have_cmd nvidia-smi; then
        drv_major="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | awk -F. 'NR==1{print $1; exit}')"
      elif [[ -r /proc/driver/nvidia/version ]]; then
        drv_major="$(awk 'match($0, /Kernel Module[[:space:]]+([0-9]+)\./, m){print m[1]; exit}' /proc/driver/nvidia/version 2>/dev/null || true)"
      fi
      if [[ -n "${drv_major:-}" ]]; then
        best_pkg="libnvidia-gl-${drv_major}"
      fi
    fi

    # 3) Newest available libnvidia-gl-### package name (best effort).
    if [[ -z "${best_pkg:-}" ]]; then
      best_pkg="$(apt-cache search libnvidia-gl- 2>/dev/null | awk '{print $1}' | awk '$1 ~ /^libnvidia-gl-[0-9]+$/ {print}' | sort -V | awk 'END{print}')"
    fi

    if [[ -n "${best_pkg:-}" && "${best_pkg}" == libnvidia-gl-* ]]; then
      if pkg_installable "${best_pkg}:i386"; then
        if ! dpkg -s "${best_pkg}:i386" >/dev/null 2>&1; then
          sudo_run apt-get install -y "${best_pkg}:i386" || warn "Failed installing ${best_pkg}:i386 (continuing)."
        fi
      else
        warn "Nvidia detected but ${best_pkg}:i386 is not installable via apt; skipping 32-bit Nvidia libs."
      fi
    else
      warn "Nvidia detected but could not determine a libnvidia-gl-<version> package; skipping 32-bit Nvidia libs."
    fi
  fi
fi

# Package name differs by Ubuntu release; try the common options.
if apt-cache show steam-installer >/dev/null 2>&1; then
  sudo_run apt-get install -y steam-installer
elif apt-cache show steam >/dev/null 2>&1; then
  sudo_run apt-get install -y steam
else
  die "No steam package found via apt-cache (enable multiverse?)"
fi

log "Done (Steam)."

