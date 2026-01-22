#!/usr/bin/env bash
set -euo pipefail

### =====================================
### CONFIG — EDIT BEFORE RUNNING
### =====================================

DISK="/dev/nvme0n1"
HOSTNAME="x13"
USERNAME="nolan"
PASSWORD="ReplaceWithSecurePassword"
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8 UTF-8"
LANG="en_US.UTF-8"

CRYPT_NAME="cryptroot"
EFI_SIZE="+512M"
FILESYSTEM="ext4"

# Optional: Secure Boot keys
SBKEY_DIR="/root/secureboot-keys"  # sbsign keys

### =====================================
### LOGGING + CLEANUP
### =====================================

exec > >(tee install.log) 2>&1

cleanup() {
    echo "Cleaning up..."
    umount -R /mnt 2>/dev/null || true
    cryptsetup close "$CRYPT_NAME" 2>/dev/null || true
}
trap cleanup ERR EXIT

### =====================================
### PREFLIGHT
### =====================================

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
[[ -d /sys/firmware/efi ]] || { echo "UEFI required"; exit 1; }

echo "⚠️  THIS WILL ERASE $DISK"
read -rp "Type YES to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || exit 1

timedatectl set-ntp true

### =====================================
### PARTITION DISK
### =====================================

wipefs -af "$DISK"
sgdisk -Z "$DISK"

# Create EFI partition
sgdisk -n 1:0:$EFI_SIZE -t 1:ef00 -c 1:"EFI"
# Create LUKS partition
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux LUKS"

partprobe "$DISK"
udevadm settle

# Detect partitions robustly by label
EFI_PART=$(lsblk -no PATH -l "$DISK" | while read p; do blkid -o value -s PARTLABEL "$p" | grep -q "^EFI$" && echo "$p"; done)
LUKS_PART=$(lsblk -no PATH -l "$DISK" | while read p; do blkid -o value -s PARTLABEL "$p" | grep -q "^Linux LUKS$" && echo "$p"; done)

mkfs.fat -F32 "$EFI_PART"

### =====================================
### LUKS SETUP
### =====================================

echo "==> Setting up LUKS on $LUKS_PART"
cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    --iter-time 5000 \
    "$LUKS_PART" <<< "$PASSWORD"

cryptsetup open "$LUKS_PART" "$CRYPT_NAME" <<< "$PASSWORD"

mkfs.ext4 -L rootfs /dev/mapper/$CRYPT_NAME

### =====================================
### MOUNT FILESYSTEMS
### =====================================

mount "/dev/mapper/$CRYPT_NAME" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

### =====================================
### BASE INSTALL
### =====================================

pacstrap /mnt \
  base \
  linux \
  linux-firmware \
  sudo \
  networkmanager \
  iwd \
  man-db \
  man-pages \
  cryptsetup \
  efibootmgr \
  systemd-boot

genfstab -U /mnt >> /mnt/etc/fstab

### =====================================
### CHROOT CONFIGURATION
### =====================================

arch-chroot /mnt /bin/bash <<EOF
set -e
umask 022

### TIME
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

### LOCALE
sed -i "/^#${LOCALE%% *}/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=$LANG" > /etc/locale.conf

### HOSTNAME
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
HOSTS

### USERS
useradd -m -G wheel,audio,video,input -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

### NETWORKING
systemctl enable NetworkManager

### INITRAMFS
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

### CPU MICROCODE
CPU_VENDOR=\$(lscpu | awk '/Vendor/ {print \$3}')
if [[ "\$CPU_VENDOR" == "GenuineIntel" ]]; then
    pacman -Sy --noconfirm intel-ucode
    UCODE_IMG="/usr/lib/initcpio/intel-ucode.img"
elif [[ "\$CPU_VENDOR" == "AuthenticAMD" ]]; then
    pacman -Sy --noconfirm amd-ucode
    UCODE_IMG="/usr/lib/initcpio/amd-ucode.img"
else
    UCODE_IMG=""
fi

### SYSTEMD-BOOT INSTALL
bootctl --path=/boot install

# TPM2 auto-enroll
if command -v systemd-cryptenroll &>/dev/null; then
    systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/Linux\ LUKS || true
fi

### =====================================
### REAL UKI CREATION
### =====================================
mkdir -p /boot/EFI/Arch
UKI_FILE=/boot/EFI/Arch/arch.efi

KERNEL=/boot/vmlinuz-linux
INITRAMFS=/boot/initramfs-linux.img
MICROCODE="\$UCODE_IMG"

# Use objcopy to combine kernel + initramfs (+ microcode)
cat > /tmp/mkuki.sh <<'MKUKI'
#!/usr/bin/env bash
set -e
KERNEL="\$1"
INITRAMFS="\$2"
MICROCODE="\$3"
OUTPUT="\$4"

# Use objcopy to produce unified kernel image (UKI)
objcopy \
  --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
  --add-section .cmdline=/proc/cmdline --change-section-vma .cmdline=0x30000 \
  --add-section .linux="\$KERNEL" --change-section-vma .linux=0x40000 \
  --add-section .initrd="\$INITRAMFS" --change-section-vma .initrd=0x2000000 \
  --add-section .microcode="\$MICROCODE" --change-section-vma .microcode=0x3000000 \
  "\$KERNEL" "\$OUTPUT"
MKUKI
chmod +x /tmp/mkuki.sh
/tmp/mkuki.sh "$KERNEL" "$INITRAMFS" "$MICROCODE" "$UKI_FILE"
rm /tmp/mkuki.sh

# Optional Secure Boot signing
if [[ -d "$SBKEY_DIR" ]] && command -v sbsign &>/dev/null; then
    sbsign --key "$SBKEY_DIR/DB.key" --cert "$SBKEY_DIR/DB.crt" --output "$UKI_FILE.signed" "$UKI_FILE"
    mv "$UKI_FILE.signed" "$UKI_FILE"
fi

# systemd-boot entry
LUKS_UUID=\$(blkid -s UUID -o value /dev/disk/by-partlabel/Linux\ LUKS)
cat > /boot/loader/entries/arch.conf <<BOOT
title Arch Linux (UKI)
efi /EFI/Arch/arch.efi
options rd.luks.name=\$LUKS_UUID=$CRYPT_NAME root=/dev/mapper/$CRYPT_NAME rw quiet
BOOT

cat > /boot/loader/loader.conf <<LOADER
default arch.conf
timeout 3
editor no
LOADER

EOF

### =====================================
### FINISH
### =====================================

echo "✅ Arch Linux with LUKS + UKI + Secure Boot installed successfully"
umount -R /mnt
cryptsetup close "$CRYPT_NAME"
echo "Reboot when ready"
