#!/usr/bin/env bash

# Arch Linux Networking + UFW Setup Script
# WARNING: Run as root or with sudo

set -euo pipefail

echo "=== 1. Installing networking stack ==="
pacman -S --noconfirm networkmanager iwd

echo "=== 2. Installing firewall ==="
pacman -S --noconfirm ufw iptables-nft

echo "=== 3. Configuring NetworkManager to use iwd ==="
NM_CONF_DIR="/etc/NetworkManager/conf.d"
mkdir -p "$NM_CONF_DIR"

NM_CONF_FILE="$NM_CONF_DIR/wifi-backend.conf"
if [[ ! -f "$NM_CONF_FILE" ]]; then
    cat <<EOF > "$NM_CONF_FILE"
[device]
wifi.backend=iwd
EOF
    echo "Created $NM_CONF_FILE"
else
    echo "$NM_CONF_FILE already exists, skipping"
fi

echo "=== 4. Disabling conflicting services ==="
systemctl disable --now wpa_supplicant || true

echo "=== 5. Enabling services in correct order ==="
systemctl enable --now iwd
systemctl enable --now NetworkManager
systemctl enable --now ufw

echo "=== 6. Configuring UFW defaults ==="
# Standard default config
ufw default deny incoming
ufw default allow outgoing
# Set low logging
ufw logging low
# DHCP
ufw allow out 67,68/udp
# DNS
ufw allow out 53
ufw allow out 853/tcp
# Core Outbound
sudo ufw allow out 80/tcp
sudo ufw allow out 443/tcp
# Block ICMP incoming
sudo ufw deny in proto icmp
# Block multicast noise
sudo ufw deny in from 224.0.0.0/4
ufw --force enable

echo "=== 7. Connect to Wi-Fi ==="
nmcli device wifi list
read -rp "Enter SSID to connect: " WIFI_SSID
nmcli device wifi connect "$WIFI_SSID" --ask

echo "=== 8. Verification ==="
echo "--- Networking ---"
nmcli general status
nmcli device status

echo "--- Firewall ---"
ufw status verbose
iptables --version

echo "--- Backend (nftables) ---"
nft list ruleset

echo "=== Setup complete! ==="
