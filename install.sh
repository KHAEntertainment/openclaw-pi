#!/bin/bash
# OpenClaw Pi - Quick Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/install.sh | sudo bash

set -e

REPO_URL="https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main"
SCRIPT_NAME="harden-openclaw-pi.sh"
HELPER_SCRIPT="optimize-headless.sh"
INSTALL_DIR="/tmp/openclaw-pi-install"

GUM_VERSION_DEFAULT="0.17.0"
GUM_VERSION="${GUM_VERSION:-$GUM_VERSION_DEFAULT}"

# Verify root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

ensure_gum() {
    command -v gum &>/dev/null && return 0

    local version="$GUM_VERSION"
    local os arch tmp base url
    os="$(uname -s)"
    arch="$(uname -m)"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    base="https://github.com/charmbracelet/gum/releases/download/v${version}"

    local candidates=(
        "gum_${version}_${os}_${arch}.tar.gz"
    )
    case "$arch" in
        aarch64) candidates+=("gum_${version}_${os}_arm64.tar.gz") ;;
        armv7l) candidates+=("gum_${version}_${os}_armv7.tar.gz") ;;
        x86_64) candidates+=("gum_${version}_${os}_amd64.tar.gz") ;;
    esac

    url=""
    for asset in "${candidates[@]}"; do
        if curl -fsSLI "${base}/${asset}" &>/dev/null; then
            url="${base}/${asset}"
            break
        fi
    done

    if [ -z "$url" ]; then
        echo "ERROR: Could not find gum release asset for ${os}/${arch} (gum v${version})." >&2
        echo "Tried: ${candidates[*]}" >&2
        return 1
    fi

    echo "Installing gum v${version} (${os}/${arch})..."
    
    # Download checksums file for verification
    local checksums_url="${base}/checksums.txt"
    if ! curl -fsSL "$checksums_url" -o "${tmp}/checksums.txt"; then
        echo "ERROR: Failed to download checksums file from ${checksums_url}" >&2
        return 1
    fi
    
    # Extract the expected checksum for our asset
    local asset_name
    asset_name="$(basename "$url")"
    local expected_checksum
    expected_checksum="$(grep "${asset_name}$" "${tmp}/checksums.txt" | awk '{print $1}')"
    
    if [ -z "$expected_checksum" ]; then
        echo "ERROR: No checksum found for ${asset_name} in checksums.txt" >&2
        return 1
    fi
    
    # Download the gum archive
    if ! curl -fsSL "$url" -o "${tmp}/gum.tar.gz"; then
        echo "ERROR: Failed to download ${url}" >&2
        return 1
    fi
    
    # Verify SHA256 checksum
    if command -v sha256sum &>/dev/null; then
        local actual_checksum
        actual_checksum="$(sha256sum "${tmp}/gum.tar.gz" | awk '{print $1}')"
        if [ "$actual_checksum" != "$expected_checksum" ]; then
            echo "ERROR: SHA256 checksum mismatch for ${asset_name}" >&2
            echo "  Expected: ${expected_checksum}" >&2
            echo "  Actual:   ${actual_checksum}" >&2
            return 1
        fi
        echo "✓ SHA256 checksum verified: ${expected_checksum}"
    else
        echo "WARNING: sha256sum not available, skipping checksum verification" >&2
    fi
    
    tar -xzf "${tmp}/gum.tar.gz" -C "$tmp"

    local gum_path
    gum_path="$(find "$tmp" -type f -name gum -perm -111 2>/dev/null | head -n 1)"
    [ -z "$gum_path" ] && echo "ERROR: gum binary not found in archive" >&2 && return 1

    install -m 0755 "$gum_path" /usr/local/bin/gum
}

ensure_gum

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
