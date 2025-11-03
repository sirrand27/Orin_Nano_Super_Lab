#!/bin/bash
# Jetson Orin Nano SD Card to SSD Migration Script
# This script copies the SD card root filesystem to SSD and configures boot

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Jetson Orin Nano SD to SSD Migration"
echo -e "==========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Detect devices
SD_CARD=$(mount | grep ' / ' | cut -d' ' -f1 | sed 's/[0-9]*$//')
echo -e "${YELLOW}[INFO]${NC} Current root device: $(mount | grep ' / ' | cut -d' ' -f1)"
echo -e "${YELLOW}[INFO]${NC} SD Card device: ${SD_CARD}"
echo ""

# List available block devices
echo -e "${BLUE}Available storage devices:${NC}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL | grep -E "^(NAME|sd|nvme|mmcblk)"
echo ""

# Detect SSD
echo -e "${YELLOW}[STEP 1]${NC} Detecting SSD..."
SSD_DEVICE=""

if [ -b /dev/nvme0n1 ]; then
    SSD_DEVICE="/dev/nvme0n1"
    echo -e "${GREEN}[OK]${NC} Found NVMe SSD: ${SSD_DEVICE}"
elif [ -b /dev/sda ]; then
    SSD_DEVICE="/dev/sda"
    echo -e "${GREEN}[OK]${NC} Found SATA/USB SSD: ${SSD_DEVICE}"
else
    echo -e "${RED}[ERROR]${NC} No SSD detected!"
    echo "Please ensure your SSD is properly connected."
    exit 1
fi

# Show SSD partitions
echo ""
echo -e "${BLUE}Current SSD partitions:${NC}"
lsblk ${SSD_DEVICE}
echo ""

# Ask for partition to use
echo -e "${YELLOW}[STEP 2]${NC} Select target partition"
echo "Enter the partition number you created (e.g., 1 for ${SSD_DEVICE}p1 or ${SSD_DEVICE}1):"
read -p "Partition number: " PART_NUM

if [[ ${SSD_DEVICE} == *"nvme"* ]]; then
    SSD_PARTITION="${SSD_DEVICE}p${PART_NUM}"
else
    SSD_PARTITION="${SSD_DEVICE}${PART_NUM}"
fi

if [ ! -b "${SSD_PARTITION}" ]; then
    echo -e "${RED}[ERROR]${NC} Partition ${SSD_PARTITION} does not exist!"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Using partition: ${SSD_PARTITION}"
echo ""

# Confirm before proceeding
echo -e "${RED}WARNING: This will format ${SSD_PARTITION} and copy all data from SD card!${NC}"
echo "Current SD card size: $(df -h / | awk 'NR==2 {print $3}')"
echo "Target partition: ${SSD_PARTITION}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${YELLOW}[STEP 3]${NC} Formatting SSD partition with ext4..."
mkfs.ext4 -F -L "JetsonSSD" ${SSD_PARTITION}
echo -e "${GREEN}[OK]${NC} Partition formatted"
echo ""

# Mount SSD
echo -e "${YELLOW}[STEP 4]${NC} Mounting SSD..."
SSD_MOUNT="/mnt/ssd_rootfs"
mkdir -p ${SSD_MOUNT}
mount ${SSD_PARTITION} ${SSD_MOUNT}
echo -e "${GREEN}[OK]${NC} SSD mounted at ${SSD_MOUNT}"
echo ""

# Copy root filesystem
echo -e "${YELLOW}[STEP 5]${NC} Copying root filesystem to SSD..."
echo "This will take 10-30 minutes depending on data size..."
echo ""

rsync -aAXHv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / ${SSD_MOUNT}/

echo ""
echo -e "${GREEN}[OK]${NC} Root filesystem copied"
echo ""

# Get SSD UUID
echo -e "${YELLOW}[STEP 6]${NC} Getting SSD partition UUID..."
SSD_UUID=$(blkid -s UUID -o value ${SSD_PARTITION})
echo -e "${GREEN}[OK]${NC} SSD UUID: ${SSD_UUID}"
echo ""

# Update extlinux.conf on SSD
echo -e "${YELLOW}[STEP 7]${NC} Updating boot configuration..."
EXTLINUX_CONF="${SSD_MOUNT}/boot/extlinux/extlinux.conf"

if [ -f "${EXTLINUX_CONF}" ]; then
    # Backup original
    cp ${EXTLINUX_CONF} ${EXTLINUX_CONF}.backup
    
    # Update root= parameter to use SSD UUID
    sed -i "s|root=[^ ]*|root=UUID=${SSD_UUID}|g" ${EXTLINUX_CONF}
    
    echo -e "${GREEN}[OK]${NC} Boot configuration updated"
    echo ""
    echo "New boot configuration:"
    grep "APPEND" ${EXTLINUX_CONF}
else
    echo -e "${RED}[ERROR]${NC} extlinux.conf not found!"
    echo "You may need to manually configure boot."
fi
echo ""

# Update fstab on SSD
echo -e "${YELLOW}[STEP 8]${NC} Updating fstab..."
FSTAB="${SSD_MOUNT}/etc/fstab"

if [ -f "${FSTAB}" ]; then
    # Backup original
    cp ${FSTAB} ${FSTAB}.backup
    
    # Update root partition UUID
    sed -i "s|UUID=[^ ]*[ \t]*/[ \t]|UUID=${SSD_UUID} / |g" ${FSTAB}
    
    echo -e "${GREEN}[OK]${NC} fstab updated"
    echo ""
    echo "New fstab for root:"
    grep " / " ${FSTAB}
else
    echo -e "${YELLOW}[WARNING]${NC} fstab not found"
fi
echo ""

# Sync and unmount
echo -e "${YELLOW}[STEP 9]${NC} Syncing and unmounting..."
sync
umount ${SSD_MOUNT}
echo -e "${GREEN}[OK]${NC} SSD unmounted"
echo ""

# Create summary
echo -e "${GREEN}=========================================="
echo "Migration Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  SD Card: $(mount | grep ' / ' | cut -d' ' -f1)"
echo "  SSD: ${SSD_PARTITION}"
echo "  SSD UUID: ${SSD_UUID}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ${GREEN}Power off the Jetson${NC}"
echo "   sudo poweroff"
echo ""
echo "2. ${GREEN}Remove the SD card${NC}"
echo "   (Optional but recommended to force SSD boot)"
echo ""
echo "3. ${GREEN}Power on${NC}"
echo "   The Jetson should now boot from SSD"
echo ""
echo "4. ${GREEN}Verify after boot:${NC}"
echo "   df -h /"
echo "   lsblk"
echo ""
echo -e "${BLUE}If boot fails:${NC}"
echo "  - Insert SD card back"
echo "  - Boot from SD card"
echo "  - Check ${EXTLINUX_CONF}"
echo "  - Verify UUID matches: sudo blkid ${SSD_PARTITION}"
echo ""
echo -e "${GREEN}Backup files created:${NC}"
echo "  - ${SSD_MOUNT}/boot/extlinux/extlinux.conf.backup"
echo "  - ${SSD_MOUNT}/etc/fstab.backup"
echo ""
