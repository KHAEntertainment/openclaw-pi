#!/bin/bash
# OpenClaw Pi - Quick Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/install.sh | sudo bash

set -e

REPO_URL="https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main"
SCRIPT_NAME="harden-openclaw-pi.sh"
HELPER_SCRIPT="optimize-headless.sh"
INSTALL_DIR="/tmp/openclaw-pi-install"

# Verify root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "============================================"
echo "  OpenClaw Pi - Security Hardening Installer"
echo "============================================"
echo ""

# Download
echo "Downloading hardening script..."
mkdir -p "$INSTALL_DIR"
curl -fsSL "$REPO_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"
curl -fsSL "$REPO_URL/$HELPER_SCRIPT" -o "$INSTALL_DIR/$HELPER_SCRIPT"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$HELPER_SCRIPT"

# Verify download
if [ ! -s "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    echo "ERROR: Download failed or file is empty"
    rm -rf "$INSTALL_DIR"
    exit 1
fi

echo "Download complete."
echo ""

# Run
echo "Starting hardening..."
"$INSTALL_DIR/$SCRIPT_NAME" "$@"

# Cleanup
rm -rf "$INSTALL_DIR"
