#!/bin/bash
#
# Fix SSD Boot Configuration
# Updates extlinux.conf to boot from NVMe SSD instead of SD card
#

set -e

echo "=========================================="
echo "Fixing SSD Boot Configuration"
echo "=========================================="
echo ""

# SSD UUID from lsblk output
SSD_UUID="a1167841-e021-43e6-849c-acebf9203715"
SSD_DEVICE="/dev/nvme0n1p1"

# Verify SSD exists and has data
echo "[1/5] Verifying SSD..."
if [ ! -b "$SSD_DEVICE" ]; then
    echo "[ERROR] SSD partition $SSD_DEVICE not found!"
    exit 1
fi

echo "[OK] SSD found: $SSD_DEVICE (UUID: $SSD_UUID)"

# Mount SSD to verify it has system files
echo ""
echo "[2/5] Verifying SSD has system files..."
sudo mkdir -p /mnt/ssd-temp
sudo mount $SSD_DEVICE /mnt/ssd-temp

if [ ! -d "/mnt/ssd-temp/boot" ] || [ ! -d "/mnt/ssd-temp/etc" ]; then
    echo "[ERROR] SSD doesn't appear to have system files copied!"
    echo "        Run ./migrate-to-ssd.sh first to copy files"
    sudo umount /mnt/ssd-temp
    exit 1
fi

echo "[OK] SSD has system files (boot, etc, home, usr, etc.)"
sudo umount /mnt/ssd-temp

# Backup current extlinux.conf
echo ""
echo "[3/5] Backing up extlinux.conf..."
sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.backup-$(date +%Y%m%d-%H%M%S)
echo "[OK] Backup created"

# Update extlinux.conf
echo ""
echo "[4/5] Updating extlinux.conf to boot from SSD..."
sudo sed -i "s|root=/dev/mmcblk0p1|root=UUID=$SSD_UUID|g" /boot/extlinux/extlinux.conf

# Verify the change
if grep -q "root=UUID=$SSD_UUID" /boot/extlinux/extlinux.conf; then
    echo "[OK] Boot configuration updated successfully"
else
    echo "[ERROR] Failed to update boot configuration"
    echo "        Restoring backup..."
    sudo cp /boot/extlinux/extlinux.conf.backup-* /boot/extlinux/extlinux.conf
    exit 1
fi

# Update fstab
echo ""
echo "[5/5] Updating /etc/fstab..."
OLD_UUID=$(blkid -s UUID -o value /dev/mmcblk0p1)
sudo sed -i "s|UUID=$OLD_UUID|UUID=$SSD_UUID|g" /etc/fstab

echo "[OK] fstab updated"

# Show the changes
echo ""
echo "=========================================="
echo "Configuration Updated!"
echo "=========================================="
echo ""
echo "New boot configuration:"
grep "APPEND.*root=" /boot/extlinux/extlinux.conf | head -1
echo ""
echo "New fstab root entry:"
grep "UUID=$SSD_UUID" /etc/fstab | grep -v "^#" | head -1
echo ""
echo "=========================================="
echo "READY TO REBOOT FROM SSD"
echo "=========================================="
echo ""
echo "To complete the migration:"
echo "  1. sudo poweroff"
echo "  2. Wait for complete shutdown"
echo "  3. Power back on"
echo "  4. Verify with: df -h /"
echo "     (should show /dev/nvme0n1p1)"
echo ""
echo "Optional: You can remove the SD card after"
echo "          verifying SSD boot works"
echo ""
