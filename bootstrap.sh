#!/usr/bin/env bash
set -e

DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_DIR="$DOTFILES_DIR/config"

# Defaults
INSTALL_FLATPAK=1
INSTALL_NVIDIA=1
INSTALL_AMD=0
INSTALL_NODE=1
INSTALL_PYENV=1
INSTALL_DOCKER=1
RESTORE_GNOME=1
DRY_RUN=0

# ----------------------------
# Command-line flags
# ----------------------------
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --skip-flatpak) INSTALL_FLATPAK=0 ;;
        --skip-nvidia) INSTALL_NVIDIA=0 ;;
        --skip-amd) INSTALL_AMD=0 ;;
        --skip-node) INSTALL_NODE=0 ;;
        --skip-pyenv) INSTALL_PYENV=0 ;;
        --skip-docker) INSTALL_DOCKER=0 ;;
        --skip-gnome) RESTORE_GNOME=0 ;;
        --dry-run) DRY_RUN=1 ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-flatpak   Skip Flatpak apps"
            echo "  --skip-nvidia    Skip NVIDIA drivers"
            echo "  --skip-amd       Skip AMD drivers"
            echo "  --skip-node      Skip Node/NVM"
            echo "  --skip-pyenv     Skip PyEnv"
            echo "  --skip-docker    Skip Docker"
            echo "  --skip-gnome     Skip GNOME restore"
            echo "  --dry-run        Show actions without running"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
warn()    { echo -e "\e[33m[WARN]\e[0m $1"; }
run() { if [[ $DRY_RUN -eq 1 ]]; then echo "[DRY-RUN] $*"; else eval "$@"; fi }

# ----------------------------
# Update dotfiles repo
# ----------------------------
DOTFILES_REPO="git@github.com:cjmabry/dotfiles.git"
if [ -d "$DOTFILES_DIR/.git" ]; then
    info "Updating existing dotfiles repo..."
    run git -C "$DOTFILES_DIR" pull origin main
else
    info "Cloning dotfiles repo..."
    run git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# ----------------------------
# Base system
# ----------------------------
info "Updating Fedora..."
run sudo dnf upgrade -y && sudo dnf update -y

PACKAGES_FILE="$CONFIG_DIR/packages.txt"
if [ -f "$PACKAGES_FILE" ]; then
    info "Installing DNF packages..."
    while IFS= read -r pkg; do
        [[ "$pkg" =~ ^#.*$ || -z "$pkg" ]] && continue
        run sudo dnf install -y "$pkg"
    done < "$PACKAGES_FILE"
fi

info "Installing Development Tools..."
run sudo dnf groupinstall -y "Development Tools"

info "Setting up PostgreSQL..."
run sudo systemctl enable postgresql
run sudo postgresql-setup --initdb --unit postgresql
run sudo systemctl start postgresql

# ----------------------------
# Flatpak
# ----------------------------
if [[ "$INSTALL_FLATPAK" == 1 ]]; then
    info "Installing Flatpak apps..."
    FLATHUB_LIST="$CONFIG_DIR/flatpak.txt"
    if [ -f "$FLATHUB_LIST" ]; then
        while IFS= read -r app; do
            [[ "$app" =~ ^#.*$ || -z "$app" ]] && continue
            run flatpak install -y flathub "$app" || warn "Failed: $app"
        done < "$FLATHUB_LIST"
    else
        warn "$FLATHUB_LIST not found, skipping Flatpak apps."
    fi
fi

# ----------------------------
# VSCode
# ----------------------------
info "Installing VSCode..."
run sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
run sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
run sudo dnf install -y code

# ----------------------------
# Docker
# ----------------------------
if [[ "$INSTALL_DOCKER" == 1 ]]; then
    info "Installing Docker..."
    run sudo dnf install -y dnf-plugins-core
    run sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    run sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run sudo systemctl start docker
    if ! groups $USER | grep -q '\bdocker\b'; then
        run sudo usermod -aG docker $USER
    fi
    run newgrp docker
    run docker run hello-world || warn "Docker test failed"
fi

# ----------------------------
# Node / NVM
# ----------------------------
if [[ "$INSTALL_NODE" == 1 ]]; then
    info "Installing NVM and Node..."
    run curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    run nvm install node
fi

# ----------------------------
# PyEnv
# ----------------------------
if [[ "$INSTALL_PYENV" == 1 ]]; then
    info "Installing PyEnv..."
    run curl https://pyenv.run | bash
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
fi

# ----------------------------
# GPU drivers
# ----------------------------
if [[ "$INSTALL_NVIDIA" == 1 ]]; then
    info "Installing NVIDIA drivers..."
    run sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
elif [[ "$INSTALL_AMD" == 1 ]]; then
    info "Installing AMD drivers..."
    run sudo dnf install -y xorg-x11-drv-amdgpu
else
    info "Skipping GPU drivers."
fi

# ----------------------------
# GNOME settings
# ----------------------------
if [[ "$RESTORE_GNOME" == 1 ]]; then
    GNOME_DIR="$CONFIG_DIR/gnome"
    BACKUP_DIR="$HOME/.config/gnome-backup-$(date +%Y%m%d%H%M%S)"
    if [ -d "$GNOME_DIR" ]; then
        info "Backing up existing GNOME settings..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$HOME/.config/gnome/"* "$BACKUP_DIR/" || true

        info "Restoring GNOME settings..."
        for f in wm-keybindings media-keys terminal-profiles interface gnome-shell gnome-extensions wm-preferences peripherals nautilus; do
            if [ -f "$GNOME_DIR/$f.ini" ]; then
                case $f in
                    wm-keybindings) dconf load /org/gnome/desktop/wm/keybindings/ < "$GNOME_DIR/$f.ini" ;;
                    media-keys)     dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$GNOME_DIR/$f.ini" ;;
                    terminal-profiles) dconf load /org/gnome/terminal/legacy/profiles:/ < "$GNOME_DIR/$f.ini" ;;
                    interface)      dconf load /org/gnome/desktop/interface/ < "$GNOME_DIR/$f.ini" ;;
                    gnome-shell)    dconf load /org/gnome/shell/ < "$GNOME_DIR/$f.ini" ;;
                    gnome-extensions) dconf load /org/gnome/shell/extensions/ < "$GNOME_DIR/$f.ini" ;;
                    wm-preferences) dconf load /org/gnome/desktop/wm/preferences/ < "$GNOME_DIR/$f.ini" ;;
                    peripherals)    dconf load /org/gnome/desktop/peripherals/ < "$GNOME_DIR/$f.ini" ;;
                    nautilus)       dconf load /org/gnome/nautilus/ < "$GNOME_DIR/$f.ini" ;;
                esac
                info "Restored $f.ini"
            fi
        done
    else
        warn "$GNOME_DIR not found — skipping GNOME restore."
    fi
fi

# ----------------------------
# Input Remapper
# ----------------------------
sudo dnf install input-remapper
sudo systemctl enable --now input-remapper

success "Bootstrap complete!"
