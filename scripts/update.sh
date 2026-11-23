#!/usr/bin/env bash
# ==============================================================================
# Family Gift Manager — Pull Latest `main` Branch & Reload Daemon
# ==============================================================================

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/family-gift-manager}"
BRANCH="${BRANCH:-main}"
SERVICE_NAME="family-gift-manager"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root (e.g., sudo $0)" >&2
  exit 1
fi

if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
  echo "Installation not found at ${INSTALL_DIR}. Run install.sh first." >&2
  exit 1
fi

echo "[fgm-update] Fetching latest '${BRANCH}' branch..."
git -C "${INSTALL_DIR}" fetch --depth 1 origin "${BRANCH}"
git -C "${INSTALL_DIR}" checkout -B "${BRANCH}" "origin/${BRANCH}"
git -C "${INSTALL_DIR}" reset --hard "origin/${BRANCH}"

echo "[fgm-update] Reloading ${SERVICE_NAME}.service..."
systemctl reload-or-restart "${SERVICE_NAME}.service"
systemctl is-active --quiet "${SERVICE_NAME}.service"
echo "[fgm-update] Updated successfully."
