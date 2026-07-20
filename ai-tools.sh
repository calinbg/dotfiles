#!/bin/bash
# update-ai-tools.sh
# Installs / updates all AI & dev tools.
# Designed to be called by the ai-tools-update systemd service.

set -euo pipefail

STAMP_FILE="$HOME/.local/share/ai-tools-updater/last_run"
LOG_FILE="$HOME/.local/share/ai-tools-updater/update.log"
INTERVAL_DAYS=30

# ── Throttle: skip if last run was < INTERVAL_DAYS ago ──────────────────────
mkdir -p "$(dirname "$STAMP_FILE")"
if [[ -f "$STAMP_FILE" ]]; then
    last_run=$(cat "$STAMP_FILE")
    now=$(date +%s)
    elapsed=$(( now - last_run ))
    threshold=$(( INTERVAL_DAYS * 86400 ))
    if (( elapsed < threshold )); then
        days_left=$(( (threshold - elapsed) / 86400 ))
        echo "ai-tools-updater: last run was $(( elapsed / 86400 )) days ago. Next run in ~${days_left} day(s). Skipping." >&2
        exit 0
    fi
fi

# ── Logging ──────────────────────────────────────────────────────────────────
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "════════════════════════════════════════════"
echo " AI Tools Update — $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════"

ok()   { echo "  ✔  $*"; }
info() { echo "  →  $*"; }
warn() { echo "  ⚠  $*"; }

# ── Helpers ──────────────────────────────────────────────────────────────────

# Install / update a .deb from a direct URL
install_deb_url() {
    local name="$1" url="$2"
    info "Fetching $name..."
    local tmp
    tmp=$(mktemp /tmp/${name}_XXXXXX.deb)
    if wget -q --show-progress -O "$tmp" "$url"; then
        sudo dpkg -i "$tmp" || sudo apt-get install -fy -q
        ok "$name installed/updated"
    else
        warn "Failed to download $name from $url"
    fi
    rm -f "$tmp"
}

# Install / update an AppImage to ~/Applications
install_appimage_url() {
    local name="$1" url="$2"
    local dest="$HOME/Applications/${name}.AppImage"
    mkdir -p "$HOME/Applications"
    info "Fetching $name AppImage..."
    if wget -q --show-progress -O "$dest" "$url"; then
        chmod +x "$dest"
        ok "$name AppImage updated → $dest"
    else
        warn "Failed to download $name AppImage"
    fi
}

search_install_deb_url() {
    local name="$1" url="$2"
    info "Checking ${name} latest release..."
    DEB_URL=$(
        curl -fsSL ${url} \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+amd64\.deb'
    ) || true

    if [[ -n "$DEB_URL" ]]; then
        install_deb_url "${name}" "$DEB_URL"
    else
        warn "Could not find ${name} .deb in latest release"
    fi
}

# ── System packages ──────────────────────────────────────────────────────────
info "Running apt update..."
sudo apt-get update -q

# ── Ollama ───────────────────────────────────────────────────────────────────
info "### Ollama..."
curl -fsSL https://ollama.com/install.sh | bash
ok "Ollama → $(ollama --version 2>/dev/null || echo 'installed')"

# ── OpenCode ─────────────────────────────────────────────────────────────────
info "### OpenCode..."
curl -fsSL https://opencode.ai/install | bash
ok "OpenCode → $(opencode --version 2>/dev/null || echo 'installed')"

# ── Copilot CLI ──────────────────────────────────────────────────────────────
curl -fsSL https://gh.io/copilot-install | bash
ok "Copilot CLI → $(copilot --version 2>/dev/null || echo 'installed')"

# ── Charm       ──────────────────────────────────────────────────────────────
# ── Devin? ──────────────────────────────────────────────────────────────
# ── Goose? ──────────────────────────────────────────────────────────────

#### EDITORS

# ── Zed ───────────────────────────────────────────────────────────────────
curl -f https://zed.dev/install.sh | sh

# ── Cursor ───────────────────────────────────────────────────────────────────
# Cursor ships as an AppImage; grab the latest from their API
info "### Cursor..."
install_deb_url "Cursor" "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/3.5"

# ── Warp ─────────────────────────────────────────────────────────────
# Warp ships a .deb and maintains its own apt repo
info "Updating Warp..."
if ! grep -rq "warp.dev" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    info "Adding Warp apt repository..."
    curl -fsSL https://releases.warp.dev/linux/keys/warp.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/warp.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/warp.gpg] https://releases.warp.dev/linux/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/warp.list > /dev/null
    sudo apt-get update -q
fi
sudo apt-get install -y -q warp-terminal \
    && ok "Warp updated → $(warp-terminal --version 2>/dev/null || echo 'installed')" \
    || warn "Warp install via apt failed"

# ── Antigravity (pip) ─────────────────────────────────────────────────────────
# info "Updating antigravity (pip)..."
# if command -v pip3 &>/dev/null; then
#     pip3 install --upgrade antigravity --break-system-packages -q \
#         && ok "antigravity updated" \
#         || warn "pip install antigravity failed"
# else
#     warn "pip3 not found, skipping antigravity"
# fi

### EXTRAS

# ── Obsidian ─────────────────────────────────────────────────────────────────
search_install_deb_url https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest Obsidian
# info "Checking Obsidian latest release..."
# OBSIDIAN_DEB_URL=$(
#     curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
#     | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+amd64\.deb'
# ) || true

# if [[ -n "$OBSIDIAN_DEB_URL" ]]; then
#     install_deb_url "Obsidian" "$OBSIDIAN_DEB_URL"
# else
#     warn "Could not find Obsidian .deb in latest release"
# fi

# ── Limux ─────────────────────────────────────────────────────────────────
search_install_deb_url https://api.github.com/repos/am-will/limux/releases/latest Limux
# info "Checking Limux latest release..."
# LIMUX_DEB_URL=$(
#     curl -fsSL https://api.github.com/repos/am-will/limux/releases/latest \
#     | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+amd64\.deb'
# ) || true

# if [[ -n "$LIMUX_DEB_URL" ]]; then
#     install_deb_url "Obsidian" "$LIMUX_DEB_URL"
# else
#     warn "Could not find Limux .deb in latest release"
# fi

# ── Optional: pull latest Ollama models you use ──────────────────────────────
# Uncomment and extend this list to keep your local models fresh:
# OLLAMA_MODELS=( "llama3.2" "mistral" "codestral" )
# for model in "${OLLAMA_MODELS[@]}"; do
#     info "Pulling Ollama model: $model"
#     ollama pull "$model" && ok "$model up to date" || warn "Failed to pull $model"
# done

# ── Stamp ────────────────────────────────────────────────────────────────────
date +%s > "$STAMP_FILE"
echo ""
echo "════════════════════════════════════════════"
echo " All done! Next update in ~${INTERVAL_DAYS} days."
echo "════════════════════════════════════════════"
