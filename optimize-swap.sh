#!/bin/bash
#
# Optimize Jetson Orin Nano with Large Swap File
# Allows loading larger models than 8GB RAM by using SSD swap
#

set -e

echo "=========================================="
echo "Jetson Orin Nano Swap Optimization"
echo "=========================================="
echo ""

# Configuration
SWAP_SIZE_GB=128  # 128GB swap file (adjust as needed: 32, 64, 128, or 256)
SWAP_FILE="/swapfile"

# Check if running on SSD
ROOT_DEVICE=$(df / | grep -v Filesystem | awk '{print $1}')
if [[ $ROOT_DEVICE != *"nvme"* ]]; then
    echo "[WARNING] Not running on NVMe SSD!"
    echo "          Current root: $ROOT_DEVICE"
    echo "          Swap on SD card will be VERY slow"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "[OK] Running on NVMe SSD: $ROOT_DEVICE"
echo ""

# Check available space
AVAILABLE_GB=$(df / | grep -v Filesystem | awk '{print $4}' | awk '{print int($1/1024/1024)}')
echo "Available space: ${AVAILABLE_GB}GB"
echo "Requested swap: ${SWAP_SIZE_GB}GB"
echo ""

if [ $AVAILABLE_GB -lt $SWAP_SIZE_GB ]; then
    echo "[WARNING] Not enough space for ${SWAP_SIZE_GB}GB swap"
    echo "          Setting swap to ${AVAILABLE_GB}GB instead"
    SWAP_SIZE_GB=$((AVAILABLE_GB - 50))  # Leave 50GB free
fi

if [ $SWAP_SIZE_GB -lt 8 ]; then
    echo "[ERROR] Not enough free space for meaningful swap"
    exit 1
fi

echo "[1/6] Checking existing swap..."
EXISTING_SWAP=$(swapon --show)
if [ ! -z "$EXISTING_SWAP" ]; then
    echo "Current swap configuration:"
    swapon --show
    echo ""
    echo "Disabling existing swap..."
    sudo swapoff -a
    if [ -f "$SWAP_FILE" ]; then
        echo "Removing old swap file..."
        sudo rm -f $SWAP_FILE
    fi
fi

echo "[OK] No active swap"
echo ""

# Create new swap file
echo "[2/6] Creating ${SWAP_SIZE_GB}GB swap file..."
echo "This will take a few minutes..."
sudo fallocate -l ${SWAP_SIZE_GB}G $SWAP_FILE

if [ ! -f "$SWAP_FILE" ]; then
    echo "[ERROR] Failed to create swap file"
    exit 1
fi

echo "[OK] Swap file created: $(ls -lh $SWAP_FILE | awk '{print $5}')"
echo ""

# Set permissions
echo "[3/6] Setting swap file permissions..."
sudo chmod 600 $SWAP_FILE
echo "[OK] Permissions set (600)"
echo ""

# Format as swap
echo "[4/6] Formatting swap file..."
sudo mkswap $SWAP_FILE
echo "[OK] Swap formatted"
echo ""

# Enable swap
echo "[5/6] Enabling swap..."
sudo swapon $SWAP_FILE
echo "[OK] Swap enabled"
echo ""

# Make permanent
echo "[6/6] Making swap permanent..."
# Remove old swap entries
sudo sed -i '/\/swapfile/d' /etc/fstab
# Add new swap entry
echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
echo "[OK] Added to /etc/fstab"
echo ""

# Configure swap behavior for better performance
echo "Optimizing swap settings..."
# Set swappiness to 10 (only use swap when necessary)
sudo sysctl vm.swappiness=10
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Set cache pressure to 50 (balance between reclaiming cache and swap)
sudo sysctl vm.vfs_cache_pressure=50
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf

echo "[OK] Swap behavior optimized"
echo ""

# Show final configuration
echo "=========================================="
echo "Swap Configuration Complete!"
echo "=========================================="
echo ""
echo "Swap Status:"
swapon --show
echo ""
echo "Memory Status:"
free -h
echo ""
echo "=========================================="
echo "Optimization Summary"
echo "=========================================="
echo ""
echo "Total RAM:        8GB"
echo "Total Swap:       ${SWAP_SIZE_GB}GB"
echo "Total Available:  $((8 + SWAP_SIZE_GB))GB"
echo ""
echo "Performance Settings:"
echo "  - Swappiness: 10 (prefer RAM, use swap only when needed)"
echo "  - Cache Pressure: 50 (balanced)"
echo "  - Location: NVMe SSD (fast)"
echo ""
echo "Model Recommendations with Swap:"
echo ""
echo "Comfortable (mostly RAM):"
echo "  - llama3.2:3b        (~4GB)"
echo "  - phi3.5:3.8b        (~4GB)"
echo "  - mistral:7b-q4      (~4GB)"
echo ""
echo "With Swap (some disk usage):"
echo "  - llama3.1:8b        (~8GB)"
echo "  - codellama:13b-q4   (~8GB)"
echo "  - mistral:7b         (~9GB)"
echo ""
echo "Heavy Swap (slower but possible):"
echo "  - llama3.1:70b-q2    (~26GB)"
echo "  - mixtral:8x7b-q3    (~30GB)"
echo ""
echo "Tips:"
echo "  1. Models up to 7-8GB will run mostly in RAM (fast)"
echo "  2. Models 8-16GB will use some swap (medium speed)"
echo "  3. Models 16GB+ will use heavy swap (slower but functional)"
echo "  4. Monitor with: watch -n 1 free -h"
echo "  5. Check swap usage: swapon --show"
echo ""
echo "Ready to pull larger models!"
echo ""
