# Keep it noninteractive and conservative with config files:
# - prefer default action where possible
# - keep existing config if a prompt would occur
export DEBIAN_FRONTEND=noninteractive

log "Upgrading installed packages (apt-get upgrade)..."
sudo_run apt-get upgrade -y \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold

