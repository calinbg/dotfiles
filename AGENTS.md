# AGENTS.md — Dotfiles Repository

This repository contains personal Ubuntu dotfiles, shell configuration, and automated setup scripts. It is not a conventional application; there are no build, test, or deploy pipelines. Changes here directly affect a user's shell environment, installed packages, and system services.

## What this repo is

- A collection of Bash/Zsh configuration files (`files/`).
- An interactive system provisioning script (`init.sh`) for Ubuntu/Debian-based machines.
- A monthly AI/dev tools updater (`ai-tools.sh`) designed to be invoked by a systemd service.
- Static data files (`data/`) that list packages, PPAs, snaps, and pip dependencies.
- A system cleanup helper (`cleanup.sh`) and a GitHub SSH key generator (`github.sh`).

## Repository layout

```
.
├── init.sh              # Main interactive provisioning runner
├── ai-tools.sh          # AI/dev tool updater (throttled to once per 30 days)
├── cleanup.sh           # Apt/snap/kernel/log cleanup commands (run as root)
├── github.sh            # Generate ed25519 SSH key for GitHub
├── requirements.txt     # Human-readable checklist, not a pip requirements file
├── data/
│   ├── essentials.list  # Base apt packages
│   ├── development.list # Dev-related apt packages
│   ├── pip.list         # Python packages installed via pip
│   ├── ppa.sh           # Extra apt repositories and post-update step
│   └── snaps.sh         # Snap install commands
├── files/
│   ├── .bash_aliases    # Git/PHP/Docker/other aliases
│   ├── .bash_functions  # Shell functions (mkcd, homestead, media helpers)
│   └── .zshrc           # Oh-My-Zsh configuration
└── config/
    ├── gnome/
    │   ├── apply-gnome-settings.sh  # Apply (or --capture) GNOME/Pop OS settings
    │   ├── extensions.dconf         # GNOME extension settings snapshot
    │   ├── desktop.dconf            # Appearance/window-manager settings snapshot
    │   └── shell.dconf              # Shell enabled-extensions/apps snapshot
    └── terminator/
        └── config       # Terminator terminal profile
```

The `config/gnome/` snapshots capture the GNOME Shell extension and appearance
settings that recreate a Pop!_OS 22.04-style GNOME desktop (Pop theme, Fira
fonts, dash-to-dock, pop-shell, ArcMenu, ArcMenu runner layout, etc.). The
wizard step "Apply GNOME settings" runs `apply-gnome-settings.sh` to reapply
them. To refresh the snapshots after changing settings:

```bash
bash config/gnome/apply-gnome-settings.sh --capture
```

The reapply script only loads dconf data and will warn (and exit) if any of
the required extensions listed in `REQUIRED_EXTENSIONS` are not installed.

## How to run the provisioning script

The main entry point is `init.sh`. It is **interactive** by default and presents a menu.

```bash
# Interactive menu
bash init.sh

# Run all pending steps non-interactively
bash init.sh --run-all
```

The script tracks completed steps in `~/.dotfiles-init-state` so interrupted runs can be resumed. Steps can also be selected by number or with menu commands (`a` = all, `n` = next pending, `q` = quit, `h` = help).

## What the provisioning script does

High-level order of operations (defined in `init.sh:step_*` functions and registered in `main`):

1. Update/upgrade apt packages.
2. Remove legacy packages (`vim-tiny`, `firefox`).
3. Install essentials from `data/essentials.list`.
4. Run `data/ppa.sh` to add repositories and update apt.
5. Install development packages from `data/development.list`.
6. Install Oh My Zsh and switch shell to `zsh`.
7. Install `spf13-vim` from a remote curl script.
8. Install snaps from `data/snaps.sh`.
9. Set up npm global packages without sudo.
10. Install PHP Composer.
11. Build `ta-lib` from source and install pip packages from `data/pip.list`.
12. Install R `IRkernel` and a JupyterLab extension.
13. Enable Docker service and add the user to the `docker` group.
14. Copy `files/` into `$HOME` (overwrites existing dotfiles).
15. Apply GNOME/Pop OS settings and extensions from `config/gnome/`.
16. Run `ai-tools.sh`.

## AI tools updater

`ai-tools.sh` is meant to be called periodically (e.g., by a systemd service). It:

- Throttles itself to once every 30 days using `~/.local/share/ai-tools-updater/last_run`.
- Logs to `~/.local/share/ai-tools-updater/update.log`.
- Installs/updates Ollama, OpenCode, Copilot CLI, Zed, Cursor, Warp, Obsidian, and Limux.
- Installs/updates the Antigravity IDE from a Google CDN tar.gz into `~/.local/opt/antigravity-ide`, with a `~/.local/bin/antigravity-ide` launcher symlink, an app icon, and a `.desktop` entry so it appears in the application menu.
- Uses `wget`, `curl`, `dpkg`, `apt-get`, and GitHub release APIs.

To force a run before the throttle window expires, remove the stamp file:

```bash
rm ~/.local/share/ai-tools-updater/last_run
bash ai-tools.sh
```

## Important gotchas and conventions

### `requirements.txt` is not a pip file
Do not treat `requirements.txt` as a Python dependency manifest. It is a free-form checklist with items like `anki x`, `vscode x`, `TA-Lib`, etc. Python packages live in `data/pip.list`.

### Data files are consumed by shell expansion
`data/essentials.list`, `data/development.list`, and `data/pip.list` are parsed with:

```bash
$(grep -v '^#' ./data/essentials.list | xargs)
```

- Lines starting with `#` are ignored.
- Blank lines are passed through `xargs` and are generally harmless but should be avoided.
- Each non-comment line becomes a separate argument, so do **not** put multiple packages on one line.

### `init.sh` uses `set -uo pipefail` but not `set -e`
The script intentionally disables `errexit` (`set -e`) so individual step failures can be captured and reported in the menu. Step functions return failure and the menu colors the step red, but the script keeps running. Do not add `set -e` at the top; it would break the interactive failure handling.

### State file tracks by array index
`~/.dotfiles-init-state` stores the integer indices of completed steps. If you reorder, insert, or delete steps in `init.sh`, previously saved state will point to the wrong steps. After changing the step list, advise the user to delete `~/.dotfiles-init-state`.

### `cleanup.sh` requires root
`cleanup.sh` runs `apt-get`, `snap`, and `journalctl` commands that need root privileges. It is not marked executable in the repo and is intended to be run with `sudo bash cleanup.sh` or similar.

### `files/` is copied recursively into `$HOME`
`step_copy_dotfiles` runs `cp -TRv ./files/ $HOME/`. The trailing slash on `files/` and the `-T` flag mean the contents are copied directly into `$HOME`, not into a `files/` subdirectory. Any file in `files/` will overwrite the corresponding file in the user's home directory.

### `ai-tools.sh` mutates system state
This script installs `.deb` packages, AppImages, apt repositories, and runs installers from the internet. It is not a dry-run or read-only tool. Review URLs before running.

### `github.sh` is a one-time setup snippet
It generates an ed25519 SSH key and adds it to the running `ssh-agent`. It is not idempotent; running it again will overwrite `~/.ssh/id_ed25519` after prompting.

### Zsh configuration sources bash files
`files/.zshrc` sources both `~/.bash_aliases` and `~/.bash_functions`. Changes to those files affect Zsh as well. The `.zshrc` also uses a hard-coded `ZSH_THEME="arrow"` and a large plugin list.

### `mkcd` is defined twice in `.bash_functions`
There are two `mkcd` definitions (lines 5–14 and 52–55). The second definition overrides the first when the file is sourced. Be careful if editing `mkcd`; the second definition is the active one but the first is more robust.

### `run_with_spinner` logs per-step
Each step invoked through `run_with_spinner` writes its output to `/tmp/init-step-${step_index}.$$..log`. On failure, the menu prints the log path. Use these logs for debugging step failures.

## Style and conventions

- Shell scripts use Bash. `init.sh` uses `#!/usr/bin/env bash`; `ai-tools.sh` uses `#!/bin/bash`.
- Indentation is tabs in `init.sh` and four spaces in `ai-tools.sh`.
- Functions are named `step_*` for provisioning steps and `snake_case` for helpers.
- Data files use one item per line and `#` for comments.
- Color output uses ANSI escape sequences directly, not `tput`.

## Testing

There is no automated test suite. Verification is manual:

1. Review `git diff` before committing.
2. Run `bash -n init.sh` and `bash -n ai-tools.sh` for syntax checking.
3. Test `init.sh` interactively on a fresh VM or container before relying on it.
4. For `ai-tools.sh`, force-run after deleting the stamp file and inspect `~/.local/share/ai-tools-updater/update.log`.

## Things to avoid

- Do not add `set -e` to `init.sh`.
- Do not convert `requirements.txt` into a real pip requirements file without also updating `init.sh` to use it.
- Do not put multiple packages on one line in `*.list` files.
- Do not move or rename step functions without considering the state file index problem.
- Do not run `cleanup.sh` on a production system without reviewing the kernel removal logic first.
