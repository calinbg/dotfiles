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

# Run a command, warn on failure but keep going.
run_or_warn() {
    if "$@"; then
        return 0
    else
        warn "Command failed: $*"
        return 1
    fi
}

# Install/update an npm global package, verifying the binary exists afterwards.
install_npm_global() {
    local pkg="$1" cmd="${2:-$1}"
    info "Installing/updating $pkg via npm..."
    if npm install -g "$pkg" --no-fund --no-audit --progress=false; then
        if command -v "$cmd" &>/dev/null; then
            ok "$pkg → $cmd"
        else
            warn "$pkg installed but $cmd not on PATH"
        fi
    else
        warn "npm install -g $pkg failed"
    fi
}

# Run a curl | bash installer, verify command exists afterwards.
install_curl_bash() {
    local name="$1" url="$2" cmd="${3:-$1}"
    info "Running $name installer..."
    if curl -fsSL "$url" | bash; then
        if command -v "$cmd" &>/dev/null; then
            ok "$name → $cmd"
        else
            warn "$name installer ran but $cmd not on PATH"
        fi
    else
        warn "$name installer failed"
    fi
}

# ── System packages ──────────────────────────────────────────────────────────
info "Running apt update..."
sudo apt-get update -q

# ── Ollama ───────────────────────────────────────────────────────────────────
info "### Ollama..."
if curl -fsSL https://ollama.com/install.sh | bash; then
    ok "Ollama → $(ollama --version 2>/dev/null || echo 'installed')"
else
    warn "Ollama install failed"
fi

# ── OpenCode ─────────────────────────────────────────────────────────────────
info "### OpenCode..."
install_npm_global opencode opencode

# ── Copilot CLI ──────────────────────────────────────────────────────────────
info "### Copilot CLI..."
install_npm_global @githubnext/copilot-cli copilot

# ── Charm Crush ──────────────────────────────────────────────────────────────
info "### Charm Crush..."
install_npm_global @charmland/crush crush

# ── Pi Agent ─────────────────────────────────────────────────────────────────
info "### Pi Agent..."
install_curl_bash "Pi Agent" "https://pi.dev/install.sh" pi

#### EDITORS

# ── Zed ───────────────────────────────────────────────────────────────────
info "### Zed..."
install_curl_bash "Zed" "https://zed.dev/install.sh" zed

# ── Cursor ───────────────────────────────────────────────────────────────────
# Cursor ships as an AppImage; grab the latest from their API
info "### Cursor..."
install_deb_url "Cursor" "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/3.5"

# ── Warp ─────────────────────────────────────────────────────────────
# Warp ships a .deb and maintains its own apt repo
info "### Warp..."
if ! grep -rq "warp.dev" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    info "Adding Warp apt repository..."
    curl -fsSL https://releases.warp.dev/linux/keys/warp.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/warp.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/warp.gpg] https://releases.warp.dev/linux/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/warp.list > /dev/null
    sudo apt-get update -q
fi
if sudo apt-get install -y -q warp-terminal; then
    ok "Warp updated → $(warp-terminal --version 2>/dev/null || echo 'installed')"
else
    warn "Warp install via apt failed"
fi

# ── Antigravity CLI ─────────────────────────────────────────────────────────
info "### Antigravity CLI..."
install_curl_bash "Antigravity CLI" "https://antigravity.google/cli/install.sh" agy

# Install / update the Antigravity IDE (tar.gz distribution) to ~/.local/opt.
# Wires up a launcher symlink, app icon, and .desktop entry.
install_antigravity_ide() {
    local tarball_url="${1:-https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz}"
    local dir="${HOME}/.local/opt/antigravity-ide"
    local bin="${dir}/bin/antigravity-ide"
    local icon="${dir}/resources/app/resources/linux/code.png"
    local icon_dest="${HOME}/.local/share/icons/hicolor/1024x1024/apps/antigravity-ide.png"

    local old_version="none"
    if [[ -x "$bin" ]]; then
        old_version=$("$bin" --version 2>/dev/null | head -n1 || true)
    fi
    info "Current Antigravity IDE version: ${old_version}"

    local tmp_download tmp_extract extracted_dir new_version
    tmp_download=$(mktemp /tmp/antigravity-XXXXXX.tar.gz)
    tmp_extract=$(mktemp -d /tmp/antigravity-extract-XXXXXX)
    if wget -q --show-progress -O "$tmp_download" "$tarball_url"; then
        if tar -xzf "$tmp_download" -C "$tmp_extract"; then
            extracted_dir=$(find "$tmp_extract" -maxdepth 1 -mindepth 1 -type d | head -n1)
            if [[ -n "$extracted_dir" ]] && [[ -x "${extracted_dir}/bin/antigravity-ide" ]]; then
                rm -rf "$dir"
                mkdir -p "$(dirname "$dir")"
                mv "$extracted_dir" "$dir"
                chmod +x "$bin"
                ln -sf "$bin" "${HOME}/.local/bin/antigravity-ide"
                if [[ -f "$icon" ]]; then
                    mkdir -p "$(dirname "$icon_dest")"
                    cp -f "$icon" "$icon_dest"
                fi
                cat > "${HOME}/.local/share/applications/antigravity-ide.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity IDE
GenericName=Text Editor
Comment=Agentic IDE by Google Antigravity
TryExec=@@ANTIGRAVITY_BIN@@
StartupNotify=true
Exec=@@ANTIGRAVITY_BIN@@ %U
Icon=@@ANTIGRAVITY_ICON_DEST@@
Categories=Development;IDE;TextEditor;
Keywords=antigravity;ide;
MimeType=text/plain;
EOF
                sed -i "s|@@ANTIGRAVITY_BIN@@|${bin}|g; s|@@ANTIGRAVITY_ICON_DEST@@|${icon_dest}|g" "${HOME}/.local/share/applications/antigravity-ide.desktop"
                if command -v update-desktop-database &>/dev/null; then
                    update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
                fi
                new_version=$("$bin" --version 2>/dev/null | head -n1 || true)
                if [[ -n "$new_version" ]] && [[ "$new_version" != "$old_version" ]]; then
                    ok "Antigravity IDE updated: ${old_version} → ${new_version}"
                else
                    ok "Antigravity IDE installed"
                fi
            else
                warn "Antigravity IDE tarball did not contain a valid bin/antigravity-ide"
            fi
        else
            warn "Failed to extract Antigravity IDE tarball"
        fi
    else
        warn "Failed to download Antigravity IDE from ${tarball_url}"
    fi
    rm -rf "$tmp_download" "$tmp_extract"
}

# ── Antigravity IDE ─────────────────────────────────────────────────────────
# The IDE is a separate desktop application, distributed as a tar.gz.
info "### Antigravity IDE..."
install_antigravity_ide

### EXTRAS

# ── Obsidian ─────────────────────────────────────────────────────────────────
info "### Obsidian..."
search_install_deb_url Obsidian https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest

# ── Limux ─────────────────────────────────────────────────────────────────
info "### Limux..."
search_install_deb_url Limux https://api.github.com/repos/am-will/limux/releases/latest

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
