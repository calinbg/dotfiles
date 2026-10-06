#!/usr/bin/env bash
# apply-gnome-settings.sh
# Captures and reapplies this machine's full GNOME configuration:
#   - dconf settings (/org/gnome/ and /org/gtk/)
#   - GTK 3/4 settings.ini and GTK bookmarks
#   - Terminator profile
#   - GNOME Shell extensions (downloaded and installed automatically)
#
# Reapply (idempotent):
#   bash config/gnome/apply-gnome-settings.sh
#
# Capture current settings (refresh the snapshots in this directory):
#   bash config/gnome/apply-gnome-settings.sh --capture

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
EXTENSIONS_DIR="${HOME}/.local/share/gnome-shell/extensions"

SHELL_VERSION="$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -n1)"
SHELL_VERSION="${SHELL_VERSION:-46}"

# Extensions installed on the machine the snapshots were captured from.
REQUIRED_EXTENSIONS=(
    "arcmenu@arcmenu.com"
    "clipboard-indicator@tudmotu.com"
    "dash-to-dock@micxgx.gmail.com"
    "extension-list@tu.berry"
    "gnome-ui-tune@itstime.tech"
    "impatience@gfxmonk.net"
    "live-lockscreen@nick-redwill"
    "no-overview@fthx"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "pop-shell@system76.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "vertical-workspaces@G-dH.github.com"
    "Vitals@CoreCoding.com"
)

capture_settings() {
    mkdir -p "$DIR" "${REPO_ROOT}/config/terminator"
    dconf dump /org/gnome/ > "$DIR/gnome.dconf"
    dconf dump /org/gtk/ > "$DIR/gtk.dconf"
    [[ -f "${HOME}/.config/gtk-3.0/settings.ini" ]] &&
        cp -f "${HOME}/.config/gtk-3.0/settings.ini" "$DIR/gtk-3.0-settings.ini"
    [[ -f "${HOME}/.config/gtk-3.0/bookmarks" ]] &&
        cp -f "${HOME}/.config/gtk-3.0/bookmarks" "$DIR/gtk-3.0-bookmarks"
    [[ -f "${HOME}/.config/gtk-4.0/settings.ini" ]] &&
        cp -f "${HOME}/.config/gtk-4.0/settings.ini" "$DIR/gtk-4.0-settings.ini"
    [[ -f "${HOME}/.config/terminator/config" ]] &&
        cp -f "${HOME}/.config/terminator/config" "${REPO_ROOT}/config/terminator/config"
    echo "Captured GNOME/GTK settings, GTK files and Terminator config."
}

# Download and install a single extension. Returns 0 if the extension
# directory exists after the attempt.
install_extension() {
    local uuid="$1"
    local zip dl

    if [[ -d "${EXTENSIONS_DIR}/${uuid}" || -d "/usr/share/gnome-shell/extensions/${uuid}" ]]; then
        return 0
    fi

    if [[ "$uuid" == "pop-shell@system76.com" ]]; then
        # pop-shell is not on extensions.gnome.org; it ships in the Pop!_OS repo.
        if sudo apt-get install -y -q pop-shell; then
            [[ -d "/usr/share/gnome-shell/extensions/${uuid}" ]] && return 0
        fi
        echo "  failed to install pop-shell via apt"
        return 1
    fi

    zip="$(mktemp "/tmp/${uuid}_XXXXXX.zip")"
    dl="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VERSION}" \
        | grep -oP '"download_url":\s*"\K[^"]+' | head -n1)" || true
    if [[ -z "$dl" ]]; then
        echo "  not found on extensions.gnome.org (shell ${SHELL_VERSION})"
        rm -f "$zip"
        return 1
    fi
    [[ "$dl" == http* ]] || dl="https://extensions.gnome.org${dl}"
    if ! curl -fsSL -o "$zip" "$dl"; then
        echo "  download failed"
        rm -f "$zip"
        return 1
    fi

    if ! gnome-extensions install --force "$zip"; then
        echo "  gnome-extensions install failed"
        rm -f "$zip"
        return 1
    fi
    rm -f "$zip"

    if [[ -d "${EXTENSIONS_DIR}/${uuid}" ]]; then
        echo "  installed $uuid"
        return 0
    fi
    echo "  installed zip but ${EXTENSIONS_DIR}/${uuid} is missing"
    return 1
}

apply_settings() {
    local failed=0

    echo "Checking GNOME extensions..."
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if ! install_extension "$ext"; then
            failed=1
        fi
    done

    mkdir -p "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0" "${HOME}/.config/terminator"
    [[ -f "$DIR/gtk-3.0-settings.ini" ]] &&
        cp -f "$DIR/gtk-3.0-settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
    [[ -f "$DIR/gtk-3.0-bookmarks" ]] &&
        cp -f "$DIR/gtk-3.0-bookmarks" "${HOME}/.config/gtk-3.0/bookmarks"
    [[ -f "$DIR/gtk-4.0-settings.ini" ]] &&
        cp -f "$DIR/gtk-4.0-settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
    [[ -f "${REPO_ROOT}/config/terminator/config" ]] &&
        cp -f "${REPO_ROOT}/config/terminator/config" "${HOME}/.config/terminator/config"

    echo "Applying dconf settings..."
    dconf load /org/gnome/ < "$DIR/gnome.dconf"
    dconf load /org/gtk/ < "$DIR/gtk.dconf"

    if (( failed )); then
        echo "Some extensions could not be installed (see above)."
        return 1
    fi
    echo "Done. Log out/in (or Alt+F2 'r' on X11) for changes to fully apply."
}

if [[ "${1:-}" == "--capture" ]]; then
    capture_settings
    exit 0
fi

apply_settings
