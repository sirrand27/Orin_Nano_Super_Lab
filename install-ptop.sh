#!/bin/bash
#
# Install ptop - Python Process Top
# A nice terminal-based system monitor for Jetson Orin Nano
#

set -e

echo "=========================================="
echo "Installing ptop on Jetson Orin Nano"
echo "=========================================="
echo ""

# Check if running on Jetson
if [ ! -f /etc/nv_tegra_release ]; then
    echo "[WARNING] This doesn't appear to be a Jetson device"
    echo "          Continuing anyway..."
fi

# Update package list
echo "[1/4] Updating package list..."
sudo apt-get update -qq

# Install Python3 and pip if not present
echo "[2/4] Ensuring Python3 and pip are installed..."
sudo apt-get install -y python3 python3-pip

# Upgrade pip to latest version
echo "[3/4] Upgrading pip..."
python3 -m pip install --upgrade pip

# Install ptop
echo "[4/4] Installing ptop..."
pip3 install ptop

# Check installation
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""

# Verify ptop is installed
if command -v ptop &> /dev/null; then
    echo "[OK] ptop is installed successfully"
    echo ""
    echo "Usage:"
    echo "  ptop              - Start ptop monitor"
    echo "  ptop --help       - Show help"
    echo ""
    echo "Keyboard shortcuts in ptop:"
    echo "  q or Ctrl+C       - Quit"
    echo "  g                 - Show graphs"
    echo "  p                 - Sort by CPU %"
    echo "  m                 - Sort by Memory %"
    echo ""
    echo "Starting ptop in 3 seconds..."
    sleep 3
    ptop
else
    echo "[ERROR] ptop installation failed"
    echo ""
    echo "Try manual installation:"
    echo "  pip3 install --user ptop"
    echo "  export PATH=\$PATH:\$HOME/.local/bin"
    echo "  ptop"
    exit 1
fi
