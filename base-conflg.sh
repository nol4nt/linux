#!/usr/bin/env bash
set -euo pipefail

### ====================================================
### Cpu Microcode
### ====================================================

# sudo pacman -S --needed --noconfirm amd-ucode
# sudo pacman -S --needed --noconfirm intel-ucode

### ====================================================
### Applications
### ====================================================

# Install yay if missing
if ! command -v yay &>/dev/null; then
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir"
    pushd "$tmpdir"
    makepkg -si --noconfirm
    popd
    rm -rf "$tmpdir"
fi

# Packages to install
PACKAGES=(
    sway # desktop environment
    swaybg # background manager
    swayidle # idle daemon
    swaylock # screenlock daemon
    wofi # application launcher
    mako # notification daemon
    inotify-tools # notification middleware
    waybar # top bar
    # TERMINAL
    foot
    # BRIGHTNESS CONTROL
    brightnessctl
    # BLUETOOTH
    bluez
    bluez-utils
    # SCREENSHOT
    grim
    slurp
    # POWER MANAGEMENT
    tlp
    tlp-rdw
    # AUDIO
    pavucontrol
    pipewire
    pipewire-pulse
    pipewire-alsa
    alsa-firmware
    sof-firmware
    linux-firmware-intel
    # MEDIA
    imv
    mpv
    vlc
    # WEBROWSER
    firefox
    # TOOLS
    git
    wget
    curl
    github-cli
    podman
    podman-compose
    unzip
    tar
    rsync
    # SOFTWARE LANGUAGES
    nodejs
    npm
    python3
    # APPLICATIONS
    obsidian # notes application
    codium-bin # ide
    neovim # text editor
    nano # text editor
    # FONTS
    otf-font-awesome
    ttf-nerd-fonts-symbols
    ttf-sourcecodepro-nerd
    gnu-free-fonts
)

# Install all packages idempotently
yay -S --needed --noconfirm "${PACKAGES[@]}"

systemctl enable tlp
systemctl enable bluetooth
