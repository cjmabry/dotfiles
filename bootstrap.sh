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
            cat <<EOF
Usage: $0 [OPTIONS]
Options:
  --skip-flatpak   Skip Flatpak apps
  --skip-nvidia    Skip NVIDIA drivers
  --skip-amd       Skip AMD drivers
  --skip-node      Skip Node/NVM
  --skip-pyenv     Skip PyEnv
  --skip-docker    Skip Docker
  --skip-gnome     Skip GNOME restore
  --dry-run        Show actions without running
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" && exit 1 ;;
    esac
    shift
done

info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
warn()    { echo -e "\e[33m[WARN]\e[0m $1"; }
run() { if [[ $DRY_RUN -eq 1 ]]; then echo "[DRY-RUN] $*"; else eval "$@"; fi; }

# ----------------------------
# Update dotfiles repo
# ----------------------------
DOTFILES_REPO="git@github.com:cjmabry/dotfiles.git"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
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
run sudo dnf upgrade -y
run sudo dnf update -y

info "Installing base packages..."
run sudo dnf install -y \
    nextcloud-client \
    vlc \
    zsh \
    gnome-tweaks \
    awscli2 \
    libffi-devel \
    postgresql-server \
    postgresql-contrib

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

    if [[ -f "$FLATHUB_LIST" ]]; then
        while IFS= read -r app; do
            [[ "$app" =~ ^#.*$ || -z "$app" ]] && continue
            run flatpak install -y flathub "$app" || warn "Failed: $app"
        done < "$FLATHUB_LIST"
    else
        warn "No flatpak.txt found — skipping Flatpak installs."
    fi
fi

# ----------------------------
# 1Password
# ----------------------------
info "Installing 1Password..."

run curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | sudo rpm --import -

run sudo bash -c 'cat > /etc/yum.repos.d/1password.repo' <<EOF
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

run sudo dnf install -y 1password

# ----------------------------
# VSCode
# ----------------------------
info "Installing VSCode..."

run curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo rpm --import -

run sudo bash -c 'cat > /etc/yum.repos.d/vscode.repo' <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

run sudo dnf install -y code

# ----------------------------
# Docker
# ----------------------------
if [[ "$INSTALL_DOCKER" == 1 ]]; then
    info "Installing Docker..."

    run sudo dnf install -y dnf-plugins-core
    run sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    run sudo dnf install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    run sudo systemctl start docker

    if ! groups "$USER" | grep -q docker; then
        run sudo usermod -aG docker "$USER"
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
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

    run nvm install node
fi

# ----------------------------
# PyEnv
# ----------------------------
if [[ "$INSTALL_PYENV" == 1 ]]; then
    info "Installing PyEnv..."
    run curl https://pyenv.run | bash

    {
        echo 'export PYENV_ROOT="$HOME/.pyenv"'
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
        echo 'eval "$(pyenv init -)"'
    } >> ~/.bashrc
fi

# ----------------------------
# GPU drivers (stub)
# ----------------------------
if [[ "$INSTALL_NVIDIA" == 1 ]]; then
    info "NVIDIA installer placeholder..."
fi

if [[ "$INSTALL_AMD" == 1 ]]; then
    info "AMD installer placeholder..."
fi

success "Bootstrap completed!"
