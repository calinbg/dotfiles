#!/bin/bash
# monthly-ai-tools-update.sh
# Runs ai-tools.sh once per month via systemd timer.
# This script is a thin wrapper that:
#   1. Sources the user's shell profile so PATH / npm prefixes are available.
#   2. Runs ai-tools.sh from the dotfiles repo.
#   3. Updates Pi via its own managed updater (pi update) when installed.

set -euo pipefail

REPO_DIR="${HOME}/Code/dotfiles"
LOG_DIR="${HOME}/.local/share/ai-tools-updater"
LOG_FILE="${LOG_DIR}/monthly-update.log"

mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "════════════════════════════════════════════"
echo " Monthly AI Tools Update — $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════"

# Make sure user-local bins (npm global, pipx, etc.) are on PATH.
export PATH="${HOME}/.local/bin:${HOME}/.pi/agent/bin:${HOME}/.npm-global/bin:${PATH}"

# Source profile files when available to pick up any user PATH tweaks.
for profile in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
    [[ -f "$profile" ]] && source "$profile" 2>/dev/null || true
done

if [[ -f "${REPO_DIR}/ai-tools.sh" ]]; then
    bash "${REPO_DIR}/ai-tools.sh"
else
    echo "ERROR: ${REPO_DIR}/ai-tools.sh not found" >&2
    exit 1
fi

# Pi has its own update mechanism; run it if pi is installed.
if command -v pi &>/dev/null; then
    echo ""
    echo "### Updating Pi Agent..."
    if pi update; then
        echo "  ✔  Pi updated → $(pi --version 2>/dev/null || echo 'installed')"
    else
        echo "  ⚠  Pi update failed" >&2
    fi
fi

echo ""
echo "════════════════════════════════════════════"
echo " Monthly update complete."
echo "════════════════════════════════════════════"
