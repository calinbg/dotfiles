#!/usr/bin/env bash
# apply-gnome-settings.sh
# Captures and reapplies GNOME Shell settings, appearance, and extension
# configuration to mimic Pop!_OS 22.04 GNOME on a stock GNOME desktop.
#
# Reapply (idempotent):
#   bash config/gnome/apply-gnome-settings.sh
#
# Capture current settings (refresh the .dconf snapshots):
#   bash config/gnome/apply-gnome-settings.sh --capture

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_DIR="${HOME}/.local/share/gnome-shell/extensions"

# Extensions that were installed when the settings were captured.
REQUIRED_EXTENSIONS=(
    "arcmenu@arcmenu.com"
    "clipboard-indicator@tudmotu.com"
    "dash-to-dock@micxgx.gmail.com"
    "extension-list@tu.berry"
    "gnome-ui-tune@itstime.tech"
    "impatience@gfxmonk.net"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "pop-shell@system76.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "vertical-workspaces@G-dH.github.com"
    "Vitals@CoreCoding.com"
)

if [[ "${1:-}" == "--capture" ]]; then
    mkdir -p "$DIR"
    dconf dump /org/gnome/shell/extensions/ > "$DIR/extensions.dconf"
    dconf dump /org/gnome/desktop/ > "$DIR/desktop.dconf"
    dconf dump /org/gnome/shell/ > "$DIR/shell.dconf"
    echo "Captured current GNOME settings to $DIR"
    exit 0
fi

missing=0
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if [[ ! -d "${EXTENSIONS_DIR}/${ext}" ]]; then
        echo "Missing extension: $ext"
        missing=1
    fi
done
if (( missing )); then
    echo "Install the missing extensions (e.g. via Extensions app or gnome-extensions) and re-run."
    exit 1
fi

echo "Applying GNOME shell settings from $DIR..."
dconf load /org/gnome/shell/extensions/ < "$DIR/extensions.dconf"
dconf load /org/gnome/desktop/ < "$DIR/desktop.dconf"
dconf load /org/gnome/shell/ < "$DIR/shell.dconf"
echo "Done. Restart the GNOME Shell (Alt+F2, 'r') for changes to fully apply."