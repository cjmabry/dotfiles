#!/bin/sh
echo "Updating Fedora"
sudo dnf upgrade -y && sudo dnf update -y 

echo "Installing apps from Fedora repos"
sudo dnf install vorta nextcloud-client vlc tmux zsh gnome-tweaks postgresql-server postgresql-contrib awscli2 gimp libffi-devel -y

echo "Installing Fedora Development Tools"
sudo dnf -y groupinstall "Development Tools"

# echo "Make zsh default shell"
# chsh --s $(which zsh)

echo "Enabling PostgreSQL and creating initail DB"
sudo systemctl enable postgresql
sudo postgresql-setup --initdb --unit postgresql
sudo systemctl start postgresql

echo "Installing Flathub apps"
flatpak install flathub com.spotify.Client md.obsidian.Obsidian fm.reaper.Reaper io.github.Figma_Linux.figma_linux com.valvesoftware.Steam com.slack.Slack flathub us.zoom.Zoom -y

echo "Adding VSCode repo and installing"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf check-update
sudo dnf install code -y # or code-insiders

echo "Adding docker repo and installing"
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

echo "Starting and testing docker"
sudo systemctl start docker
sudo docker run hello-world

echo "Adding current user to docker group"
sudo usermod -aG docker $USER
newgrp docker
echo "Verifying docker privaleges without sudo"
docker run hello-world

echo "Installing Node Version Manager (NVM)"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
source ~/.bashrc

echo "Installing Node via NVM"
nvm install node

echo "Installing PyEnv"
curl https://pyenv.run | bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc

echo "Installing Tailscale"
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install -y tailscale 
sudo systemctl enable --now tailscaled
sudo tailscale up

echo "Installing proprietart NVIDIA drivers"
sudo dnf update -y # and reboot if you are not on the latest kernel
sudo dnf install akmod-nvidia # rhel/centos users can use kmod-nvidia instead
sudo dnf install xorg-x11-drv-nvidia-cuda #optional for cuda/nvdec/nvenc support
