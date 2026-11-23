#!/usr/bin/env bash
# ==============================================================================
# Family Gift Manager — Standalone Debian 13 (Trixie) LXC Installer
#
# Installs all prerequisites, pulls the latest version from the `main` branch
# of the GitHub repository, and configures a dedicated systemd daemon to serve
# the Family Gift Manager website and Privacy Policy.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/booneruk2000-bit/family-gift-manager-site/main/scripts/install.sh | sudo bash
#
# Options (via flags or environment variables):
#   --repo URL       GitHub repository URL (default: https://github.com/booneruk2000-bit/family-gift-manager-site.git)
#   --branch NAME    Git branch to deploy (default: main)
#   --port PORT      HTTP port to listen on when --domain is not set (default: 80)
#   --domain DOMAIN  Domain name for automatic HTTPS via Caddy (optional)
#   --dir PATH       Install directory (default: /opt/family-gift-manager)
#   -h, --help       Show this help message
# ==============================================================================

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/booneruk2000-bit/family-gift-manager-site.git}"
BRANCH="${BRANCH:-main}"
PORT="${PORT:-80}"
DOMAIN="${DOMAIN:-}"
INSTALL_DIR="${INSTALL_DIR:-/opt/family-gift-manager}"
CONFIG_DIR="/etc/family-gift-manager"
STATE_DIR="/var/lib/family-gift-manager"
SERVICE_NAME="family-gift-manager"
SERVICE_USER="fgm-web"
SERVICE_GROUP="fgm-web"

usage() {
  sed -n '2,20p' "$0"
}

log() {
  printf '\033[1;32m[fgm-install]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[fgm-install]\033[0m %s\n' "$*" >&2
}

err() {
  printf '\033[1;31m[fgm-install]\033[0m %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_URL="${2:?Missing value for --repo}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:?Missing value for --branch}"
      shift 2
      ;;
    --port)
      PORT="${2:?Missing value for --port}"
      shift 2
      ;;
    --domain)
      DOMAIN="${2:?Missing value for --domain}"
      shift 2
      ;;
    --dir)
      INSTALL_DIR="${2:?Missing value for --dir}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1 (use --help for usage)"
      ;;
  esac
done

# 1. Pre-flight checks
if [[ "${EUID}" -ne 0 ]]; then
  err "Please run this installer as root (e.g., with sudo)."
fi

if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get not found. This installer is designed for Debian 13 (Trixie) LXC containers."
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "debian" ]]; then
    warn "Detected OS '${ID:-unknown}' instead of Debian. Proceeding anyway..."
  elif [[ "${VERSION_ID:-}" != "13" ]]; then
    warn "Detected Debian ${VERSION_ID:-unknown} (targeted for Debian 13 Trixie). Proceeding anyway..."
  else
    log "Detected Debian 13 (Trixie)."
  fi
fi

if ! command -v systemctl >/dev/null 2>&1; then
  err "systemd (systemctl) is required to create the service daemon."
fi

if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  err "Invalid port: ${PORT}"
fi

# 2. Install prerequisites
log "Installing prerequisites (git, curl, ca-certificates, caddy)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends git curl ca-certificates caddy

# Disable the stock caddy.service so our dedicated daemon manages the site cleanly
if systemctl list-unit-files caddy.service >/dev/null 2>&1; then
  if systemctl is-active --quiet caddy.service || systemctl is-enabled --quiet caddy.service 2>/dev/null; then
    log "Stopping and disabling default caddy.service to avoid port conflicts..."
    systemctl disable --now caddy.service >/dev/null 2>&1 || true
  fi
fi

# 3. Create dedicated system user & directories
if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
  log "Creating system user '${SERVICE_USER}'..."
  useradd --system --home-dir "${STATE_DIR}" --shell /usr/sbin/nologin --user-group "${SERVICE_USER}"
fi

mkdir -p "${CONFIG_DIR}" "${STATE_DIR}/config"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${STATE_DIR}"

# 4. Clone or pull the latest version from the target branch (default: main)
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  log "Updating existing repository in ${INSTALL_DIR} (branch: ${BRANCH})..."
  git -C "${INSTALL_DIR}" remote set-url origin "${REPO_URL}"
  git -C "${INSTALL_DIR}" fetch --depth 1 origin "${BRANCH}"
  git -C "${INSTALL_DIR}" checkout -B "${BRANCH}" "origin/${BRANCH}"
  git -C "${INSTALL_DIR}" reset --hard "origin/${BRANCH}"
else
  log "Cloning ${REPO_URL} (branch: ${BRANCH}) into ${INSTALL_DIR}..."
  rm -rf "${INSTALL_DIR}"
  git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
fi

if [[ ! -f "${INSTALL_DIR}/site/index.html" ]]; then
  err "Expected website files not found at ${INSTALL_DIR}/site/index.html"
fi

chown -R root:"${SERVICE_GROUP}" "${INSTALL_DIR}"
chmod -R g+rX "${INSTALL_DIR}"

# 5. Render Caddyfile configuration
if [[ -n "${DOMAIN}" ]]; then
  SITE_ADDRESS="${DOMAIN}"
else
  SITE_ADDRESS=":${PORT}"
fi

CADDYFILE_PATH="${CONFIG_DIR}/Caddyfile"
log "Writing daemon web configuration to ${CADDYFILE_PATH} (${SITE_ADDRESS})..."
sed \
  -e "s|__SITE_ADDRESS__|${SITE_ADDRESS}|g" \
  -e "s|__SITE_ROOT__|${INSTALL_DIR}/site|g" \
  "${INSTALL_DIR}/config/Caddyfile.template" > "${CADDYFILE_PATH}"

chown root:"${SERVICE_GROUP}" "${CADDYFILE_PATH}"
chmod 640 "${CADDYFILE_PATH}"

# Validate Caddyfile before starting daemon
caddy validate --config "${CADDYFILE_PATH}" --adapter caddyfile >/dev/null

# 6. Install and start systemd daemon
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
log "Installing systemd daemon at ${SERVICE_FILE}..."
sed \
  -e "s|__SERVICE_USER__|${SERVICE_USER}|g" \
  -e "s|__SERVICE_GROUP__|${SERVICE_GROUP}|g" \
  -e "s|__CADDYFILE_PATH__|${CADDYFILE_PATH}|g" \
  "${INSTALL_DIR}/config/family-gift-manager.service.template" > "${SERVICE_FILE}"

chmod 644 "${SERVICE_FILE}"

log "Enabling and starting ${SERVICE_NAME}.service..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service" >/dev/null
systemctl restart "${SERVICE_NAME}.service"

# 7. Verify daemon health
sleep 1
if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
  journalctl -u "${SERVICE_NAME}.service" -n 30 --no-pager >&2 || true
  err "${SERVICE_NAME}.service failed to start."
fi

if [[ -z "${DOMAIN}" ]]; then
  if curl -fsS "http://127.0.0.1:${PORT}/privacy-policy" >/dev/null 2>&1; then
    log "Health check passed on http://127.0.0.1:${PORT}/privacy-policy"
  else
    warn "Service is running, but local HTTP check on port ${PORT} did not return 200."
  fi
fi

IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo ""
log "Installation complete!"
if [[ -n "${DOMAIN}" ]]; then
  echo "  Site URL:           https://${DOMAIN}/"
  echo "  Privacy Policy URL: https://${DOMAIN}/privacy-policy"
else
  echo "  Site URL:           http://${IP_ADDR:-localhost}:${PORT}/"
  echo "  Privacy Policy URL: http://${IP_ADDR:-localhost}:${PORT}/privacy-policy"
fi
echo ""
echo "  Manage daemon:"
echo "    systemctl status ${SERVICE_NAME}"
echo "    systemctl restart ${SERVICE_NAME}"
echo "    journalctl -u ${SERVICE_NAME} -f"
echo ""
echo "  Update to latest main branch:"
echo "    sudo ${INSTALL_DIR}/scripts/update.sh"
echo ""
