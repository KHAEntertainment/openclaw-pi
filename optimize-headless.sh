#!/bin/bash

###############################################################################
# OpenClaw Pi - Headless Optimization Utility
#
# Version: 2.5
#
# Converts a Raspberry Pi OS Desktop installation into a lean headless server
# optimized for running OpenClaw. Offers two modes:
#   - Disable only (reversible): Switches boot target, keeps desktop installed
#   - Remove entirely: Purges desktop packages for maximum disk savings
#
# SAFETY: Chromium is ALWAYS preserved (required by OpenClaw for browser
# automation features).
#
# Usage: sudo ./optimize-headless.sh [--simulate] [--non-interactive]
#
# Author: Community Contribution
# License: MIT
# Version: 2.5
###############################################################################

set -e

# Script configuration
SCRIPT_VERSION="2.5"
SIMULATE=false
NON_INTERACTIVE=false
LOGFILE="/var/log/openclaw-headless-$(date +%Y%m%d-%H%M%S).log"
DESKTOP_ACTION=""
BASELINE_DISK=""
BASELINE_PKGS=0
BASELINE_SVCS=0

# Signal trap for clean interrupts
cleanup() {
    echo ""
    echo -e "\033[1;33m⚠ Headless optimization interrupted!\033[0m"
    echo -e "\033[0;36mℹ The system may be partially configured.\033[0m"
    echo -e "\033[0;36mℹ Re-run this script to complete optimization.\033[0m"
    echo -e "\033[0;36mℹ Log file: $LOGFILE\033[0m"
    exit 1
}
trap cleanup INT TERM

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --simulate)
            SIMULATE=true
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            ;;
        --help|-h)
            cat << 'HELPEOF'
OpenClaw Pi - Headless Optimization Utility v2.5

Usage: sudo ./optimize-headless.sh [OPTIONS]

Options:
  --simulate         Preview all changes without applying them
  --non-interactive  Run without prompts (defaults to disable-only mode)
  --help, -h         Show this help message

Modes:
  Disable only:  Switches to multi-user target, keeps desktop installed
                 Reversible with: sudo systemctl set-default graphical.target
  Remove entirely: Purges desktop packages, saves ~1GB+ disk space
                   Chromium is always preserved (required by OpenClaw)

Documentation: https://github.com/KHAEntertainment/openclaw-pi
HELPEOF
            exit 0
            ;;
    esac
done

# Logging setup
exec > >(tee -a "$LOGFILE")
exec 2>&1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Gum (TUI) configuration
GUM_VERSION_DEFAULT="0.17.0"
GUM_VERSION="${GUM_VERSION:-$GUM_VERSION_DEFAULT}"
TTY_DEV="/dev/tty"
USE_GUM=false

###############################################################################
# Helper Functions
###############################################################################

ensure_gum() {
    if command -v gum &>/dev/null; then
        USE_GUM=true
        return 0
    fi

    local version="$GUM_VERSION"
    local os arch tmp base url
    os="$(uname -s)"
    arch="$(uname -m)"

    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

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
        echo "ERROR: Could not find a gum release asset for ${os}/${arch} (gum v${version})." >&2
        echo "Tried: ${candidates[*]}" >&2
        return 1
    fi

    echo "Installing gum v${version} (${os}/${arch})..."
    curl -fsSL "$url" -o "${tmp}/gum.tar.gz"
    tar -xzf "${tmp}/gum.tar.gz" -C "$tmp"

    local gum_path
    gum_path="$(find "$tmp" -type f -name gum -perm -111 2>/dev/null | head -n 1)"
    if [ -z "$gum_path" ]; then
        echo "ERROR: gum binary not found after extracting ${url}" >&2
        return 1
    fi

    install -m 0755 "$gum_path" /usr/local/bin/gum
    USE_GUM=true
}

gum_tty() {
    if [ -r "$TTY_DEV" ]; then
        gum "$@" <"$TTY_DEV"
    else
        gum "$@"
    fi
}

print_header() {
    if [ "$USE_GUM" = true ] && [ "$NON_INTERACTIVE" = false ]; then
        gum_tty style --border double --bold --padding "0 2" "$1"
        echo ""
    else
        echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}  $1${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    fi
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_skip() {
    echo -e "${MAGENTA}⊘ $1${NC}"
}

print_progress() {
    echo -e "${MAGENTA}⟳ $1${NC}"
}

confirm() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi

    ensure_gum

    local prompt="$1"
    local default="${2:-n}"

    local default_flag="--default=false"
    if [ "$default" = "y" ]; then
        default_flag="--default=true"
    fi

    gum_tty confirm $default_flag "$prompt"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        echo "Usage: sudo $0"
        exit 1
    fi
}

simulate_prefix() {
    if [ "$SIMULATE" = true ]; then
        echo "[SIMULATE] "
    fi
}

###############################################################################
# Phase 0: Safety & Baseline
###############################################################################

phase_safety_baseline() {
    print_header "Phase 0: Safety & Baseline"

    check_root

    if [ "$SIMULATE" = true ]; then
        print_warning "SIMULATE MODE — no changes will be made"
        echo ""
    fi

    # Detect desktop environment
    print_info "Checking for desktop environment..."

    local desktop_found=false
    local desktop_packages=("lxde-common" "lxsession" "lightdm" "xserver-xorg" "desktop-base" "xfce4" "gnome-shell" "gdm3" "sddm")

    for pkg in "${desktop_packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            print_info "Found desktop package: $pkg"
            desktop_found=true
        fi
    done

    if [ "$desktop_found" = false ]; then
        print_success "No desktop environment found — nothing to optimize"
        print_info "This system is already running in headless mode"
        exit 0
    fi

    print_warning "Desktop environment detected — optimization available"
    echo ""

    # Record baseline
    print_info "Recording baseline measurements..."

    BASELINE_DISK=$(df -h / | awk 'NR==2 {print $4}')
    BASELINE_PKGS=$(dpkg --get-selections | grep -cv "deinstall$")
    BASELINE_SVCS=$(systemctl list-units --type=service --state=active --no-legend 2>/dev/null | wc -l)

    print_info "Available disk space: $BASELINE_DISK"
    print_info "Installed packages: $BASELINE_PKGS"
    print_info "Active services: $BASELINE_SVCS"
    echo ""

    # Save baseline package list
    local baseline_file
    baseline_file="/var/log/openclaw-headless-baseline-$(date +%Y%m%d-%H%M%S).txt"
    if [ "$SIMULATE" = false ]; then
        dpkg --get-selections > "$baseline_file"
        print_success "Baseline package list saved to $baseline_file"
    else
        print_info "$(simulate_prefix)Would save baseline package list to $baseline_file"
    fi
}

###############################################################################
# Phase 1: Desktop Decision
###############################################################################

phase_desktop_decision() {
    print_header "Phase 1: Desktop Mode Decision"

    echo "How would you like to handle the desktop environment?"
    echo ""
    echo "  A) Disable only (reversible)"
    echo "     - Switches boot target to multi-user (CLI)"
    echo "     - Desktop packages remain installed"
    echo "     - Re-enable anytime: sudo systemctl set-default graphical.target"
    echo ""
    echo "  B) Remove entirely"
    echo "     - Disables desktop AND purges desktop packages"
    echo "     - Saves ~1GB+ of disk space"
    echo "     - Harder to reverse (requires reinstalling packages)"
    echo ""
    echo "  Chromium is ALWAYS preserved (required by OpenClaw)"
    echo ""

    if [ "$NON_INTERACTIVE" = true ]; then
        DESKTOP_ACTION="disable"
        print_info "Non-interactive mode: defaulting to disable-only"
        return
    fi

    ensure_gum

    local choice
    choice=$(gum_tty choose --header "Choose mode" \
        "Disable only (reversible)" \
        "Remove entirely") || choice="Disable only (reversible)"

    case "$choice" in
        "Remove entirely")
            DESKTOP_ACTION="remove"
            print_success "Selected: Remove entirely"
            ;;
        *)
            DESKTOP_ACTION="disable"
            print_success "Selected: Disable only (reversible)"
            ;;
    esac

    echo ""

    # Disable desktop target (both modes)
    print_info "$(simulate_prefix)Setting default boot target to multi-user (CLI)..."
    if [ "$SIMULATE" = false ]; then
        systemctl set-default multi-user.target
        print_success "Boot target set to multi-user.target"

        # Disable display manager if running
        for dm in lightdm gdm3 sddm; do
            if systemctl is-enabled "$dm" 2>/dev/null | grep -q "enabled"; then
                systemctl disable "$dm" 2>/dev/null || true
                systemctl stop "$dm" 2>/dev/null || true
                print_success "Disabled display manager: $dm"
            fi
        done
    else
        print_info "[SIMULATE] Would set multi-user.target and disable display manager"
    fi
}

###############################################################################
# Phase 2: Remove Bloat Packages
###############################################################################

phase_remove_bloat() {
    print_header "Phase 2: Remove Bloat Packages"

    # Chromium safety gate — mark as manually installed so autoremove never touches it
    print_info "$(simulate_prefix)Protecting Chromium (required by OpenClaw)..."
    if [ "$SIMULATE" = false ]; then
        apt-mark manual chromium-browser 2>/dev/null || true
        apt-mark manual chromium 2>/dev/null || true
        apt-mark manual chromium-codecs-ffmpeg-extra 2>/dev/null || true
        print_success "Chromium marked as manually installed (protected from removal)"
    else
        print_info "[SIMULATE] Would mark chromium packages as manually installed"
    fi

    echo ""

    # Build package removal list
    # Using arrays to avoid word splitting issues with globs
    local bloat_packages=(
        # Office / productivity
        libreoffice-base libreoffice-base-core libreoffice-calc
        libreoffice-common libreoffice-core libreoffice-draw
        libreoffice-gtk3 libreoffice-help-common libreoffice-impress
        libreoffice-math libreoffice-writer
        gimp gimp-data
        inkscape
        scribus

        # Games
        python3-pygame
        gnome-mines gnome-sudoku gnome-mahjongg

        # Media (NOT chromium)
        vlc vlc-data vlc-plugin-base vlc-plugin-video-output
        rhythmbox
        shotwell
        cheese

        # Education / Misc
        scratch scratch3
        sonic-pi
        thonny
        geany geany-common
        bluej greenfoot
        mu-editor

        # Screen savers
        xscreensaver xscreensaver-data

        # Print system
        cups cups-browsed cups-client cups-common cups-core-drivers
        cups-daemon cups-filters cups-ipp-utils cups-pk-helper
        cups-ppdc cups-server-common
        system-config-printer system-config-printer-common

        # Accessibility (desktop-only)
        orca
        brltty

        # Misc desktop bloat
        rpd-plym-splash
        piwiz
        nuscratch
        smartsim
        penguinspuzzle
    )

    # Filter to only packages that are actually installed
    local installed_bloat=()
    for pkg in "${bloat_packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            installed_bloat+=("$pkg")
        fi
    done

    if [ ${#installed_bloat[@]} -eq 0 ]; then
        print_success "No bloat packages found — system is already clean"
        return
    fi

    print_info "Found ${#installed_bloat[@]} bloat packages to remove"
    echo ""

    # Show dry-run
    print_info "Simulating package removal..."
    echo ""

    # shellcheck disable=SC2068
    local dry_run_output
    dry_run_output=$(apt-get -s purge "${installed_bloat[@]}" 2>&1) || true

    # Extract disk savings estimate from dry-run
    local disk_savings
    disk_savings=$(echo "$dry_run_output" | grep -oP "After this operation, \K.*(?= of)" || echo "unknown amount")
    print_info "Estimated disk savings: $disk_savings"

    local remove_count
    remove_count=$(echo "$dry_run_output" | grep -oP "\K\d+(?= to remove)" || echo "0")
    print_info "Packages to remove: $remove_count"
    echo ""

    if [ "$SIMULATE" = true ]; then
        print_info "[SIMULATE] Would remove the following packages:"
        printf '  %s\n' "${installed_bloat[@]}"
        print_info "[SIMULATE] No packages were actually removed"
        return
    fi

    # Confirm before actual removal
    if ! confirm "Remove ${#installed_bloat[@]} bloat packages (saves $disk_savings)?"; then
        print_skip "Skipping bloat package removal"
        return
    fi

    print_progress "Removing bloat packages..."

    # Re-protect Chromium before purge (belt and suspenders)
    apt-mark manual chromium-browser 2>/dev/null || true
    apt-mark manual chromium 2>/dev/null || true

    apt-get purge -y "${installed_bloat[@]}" 2>&1 | tail -5
    print_success "Bloat packages removed"
}

###############################################################################
# Phase 3: Disable Unnecessary Services
###############################################################################

phase_disable_services() {
    print_header "Phase 3: Disable Unnecessary Services"

    local services_to_disable=(
        # Display managers
        lightdm.service
        gdm3.service
        sddm.service

        # Desktop-related
        ModemManager.service
        colord.service
        packagekit.service
        speech-dispatcher.service

        # Multimedia
        pipewire.service
        pipewire-pulse.service
        wireplumber.service
    )

    local disabled_count=0

    for service in "${services_to_disable[@]}"; do
        if systemctl list-unit-files "$service" &>/dev/null; then
            local is_enabled
            is_enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "not-found")

            if [ "$is_enabled" = "enabled" ] || [ "$is_enabled" = "static" ]; then
                if [ "$SIMULATE" = true ]; then
                    print_info "[SIMULATE] Would disable $service"
                    disabled_count=$((disabled_count + 1))
                else
                    systemctl stop "$service" 2>/dev/null || true
                    systemctl disable "$service" 2>/dev/null || true
                    print_success "Disabled $service"
                    disabled_count=$((disabled_count + 1))
                fi
            fi
        fi
    done

    # Special case: wpa_supplicant (only offer to disable if user confirms ethernet-only)
    if systemctl is-enabled wpa_supplicant.service 2>/dev/null | grep -q "enabled"; then
        echo ""
        print_warning "wpa_supplicant is running (handles WiFi connections)"

        if [ "$SIMULATE" = true ]; then
            print_info "[SIMULATE] Would ask about wpa_supplicant"
        elif confirm "Is this Pi connected via Ethernet ONLY? (disabling WiFi manager)"; then
            systemctl stop wpa_supplicant.service 2>/dev/null || true
            systemctl disable wpa_supplicant.service 2>/dev/null || true
            print_success "Disabled wpa_supplicant.service"
            disabled_count=$((disabled_count + 1))
        else
            print_skip "Keeping wpa_supplicant (WiFi support retained)"
        fi
    fi

    echo ""
    if [ $disabled_count -eq 0 ]; then
        print_success "No unnecessary services found to disable"
    else
        print_success "Disabled $disabled_count services"
    fi
}

###############################################################################
# Phase 4: Desktop Plumbing Removal (only if DESKTOP_ACTION=remove)
###############################################################################

phase_remove_desktop_plumbing() {
    if [ "$DESKTOP_ACTION" != "remove" ]; then
        print_header "Phase 4: Desktop Plumbing Removal"
        print_skip "Skipped — desktop set to disable-only mode"
        return
    fi

    print_header "Phase 4: Desktop Plumbing Removal"
    print_warning "This will remove X server, window managers, and desktop environment packages"
    echo ""

    local desktop_plumbing=(
        # Window managers / desktop environments
        lxde lxde-common lxde-core
        lxpanel lxsession lxappearance lxinput lxtask lxrandr lxterminal
        lxplug-bluetooth lxplug-cputemp lxplug-ejecter lxplug-network
        lxplug-ptbatt lxplug-volume lxplug-volumepulse

        # Display managers
        lightdm lightdm-gtk-greeter

        # Desktop base
        desktop-base rpd-wallpaper

        # File manager / image viewer
        pcmanfm
        gpicview

        # GTK theme engines
        gtk2-engines gtk2-engines-pixbuf

        # X session utilities
        x11-utils x11-xserver-utils xdg-utils
        xarchiver
        zenity

        # Notifications
        dunst notification-daemon

        # Polkit (desktop authentication dialogs)
        lxpolkit policykit-1-gnome
    )

    # Re-protect Chromium
    if [ "$SIMULATE" = false ]; then
        apt-mark manual chromium-browser 2>/dev/null || true
        apt-mark manual chromium 2>/dev/null || true
        apt-mark manual chromium-codecs-ffmpeg-extra 2>/dev/null || true
    fi

    # Filter to installed packages
    local installed_plumbing=()
    for pkg in "${desktop_plumbing[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            installed_plumbing+=("$pkg")
        fi
    done

    if [ ${#installed_plumbing[@]} -eq 0 ]; then
        print_success "No desktop plumbing packages found to remove"
        return
    fi

    print_info "Found ${#installed_plumbing[@]} desktop plumbing packages"

    if [ "$SIMULATE" = true ]; then
        print_info "[SIMULATE] Would remove the following desktop packages:"
        printf '  %s\n' "${installed_plumbing[@]}"
        print_info "[SIMULATE] No packages were actually removed"
        return
    fi

    if ! confirm "Remove ${#installed_plumbing[@]} desktop environment packages?"; then
        print_skip "Skipping desktop plumbing removal"
        return
    fi

    print_progress "Removing desktop environment packages..."

    apt-get purge -y "${installed_plumbing[@]}" 2>&1 | tail -5
    print_success "Desktop plumbing removed"

    # Autoremove orphaned dependencies
    print_progress "Removing orphaned dependencies..."
    apt-get autoremove --purge -y 2>&1 | tail -3
    print_success "Orphaned dependencies removed"
}

###############################################################################
# Phase 5: Housekeeping
###############################################################################

phase_housekeeping() {
    print_header "Phase 5: Housekeeping"

    if [ "$SIMULATE" = true ]; then
        print_info "[SIMULATE] Would run apt-get autoremove --purge"
        print_info "[SIMULATE] Would run apt-get autoclean"
        print_info "[SIMULATE] Would vacuum journal logs (keep 7 days)"
        print_info "[SIMULATE] Would clean thumbnail caches"
        return
    fi

    # Final autoremove
    print_progress "Cleaning up orphaned packages..."
    apt-get autoremove --purge -y 2>&1 | tail -3
    print_success "Orphaned packages cleaned"

    # Autoclean package cache
    print_progress "Cleaning package cache..."
    apt-get autoclean -y 2>&1 | tail -3
    print_success "Package cache cleaned"

    # Vacuum journal logs
    print_progress "Trimming journal logs (keeping 7 days)..."
    journalctl --vacuum-time=7d 2>&1 | tail -3
    print_success "Journal logs trimmed"

    # Clean thumbnail cache
    if ls /home/*/.cache/thumbnails/ &>/dev/null 2>&1; then
        print_progress "Cleaning thumbnail caches..."
        rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
        print_success "Thumbnail caches cleaned"
    fi

    # Clean font cache if X was removed
    if [ "$DESKTOP_ACTION" = "remove" ]; then
        if command -v fc-cache &>/dev/null; then
            print_progress "Rebuilding font cache..."
            fc-cache -f 2>/dev/null || true
            print_success "Font cache rebuilt"
        fi
    fi
}

###############################################################################
# Phase 6: Verification & Summary
###############################################################################

phase_verification() {
    print_header "Phase 6: Verification & Summary"

    # Current measurements
    local current_disk
    current_disk=$(df -h / | awk 'NR==2 {print $4}')
    local current_pkgs
    current_pkgs=$(dpkg --get-selections | grep -cv "deinstall$")
    local current_svcs
    current_svcs=$(systemctl list-units --type=service --state=active --no-legend 2>/dev/null | wc -l)

    # Comparison
    echo ""
    echo "+----------------------------------------------+"
    echo "|          Headless Optimization Results       |"
    echo "+----------------------------------------------+"
    echo "|                                              |"
    printf "|  %-18s %-12s %-12s |\n" "Metric" "Before" "After"
    echo "|  ------------------------------------------  |"
    printf "|  %-18s %-12s %-12s |\n" "Free Disk Space" "$BASELINE_DISK" "$current_disk"
    printf "|  %-18s %-12s %-12s |\n" "Installed Pkgs" "$BASELINE_PKGS" "$current_pkgs"
    printf "|  %-18s %-12s %-12s |\n" "Active Services" "$BASELINE_SVCS" "$current_svcs"
    echo "|                                              |"

    local pkgs_removed=$((BASELINE_PKGS - current_pkgs))
    local svcs_reduced=$((BASELINE_SVCS - current_svcs))
    printf "|  Packages removed: %-24s |\n" "$pkgs_removed"
    printf "|  Services reduced: %-24s |\n" "$svcs_reduced"
    echo "|                                              |"

    if [ "$DESKTOP_ACTION" = "disable" ]; then
        echo "|  Mode: Disable only (reversible)             |"
        echo "|  Re-enable: sudo systemctl set-default       |"
        echo "|             graphical.target && sudo reboot   |"
    elif [ "$DESKTOP_ACTION" = "remove" ]; then
        echo "|  Mode: Remove entirely                        |"
        echo "|  WARNING: Reversal requires reinstalling      |"
        echo "|           desktop packages manually            |"
    fi

    echo "|                                              |"
    echo "+----------------------------------------------+"
    echo ""

    # Chromium verification
    print_info "Verifying Chromium is intact..."
    if command -v chromium-browser &>/dev/null; then
        local chromium_ver
        chromium_ver=$(chromium-browser --version 2>/dev/null || echo "installed (version check requires display)")
        print_success "Chromium: $chromium_ver"
    elif command -v chromium &>/dev/null; then
        print_success "Chromium is installed"
    else
        print_warning "Chromium not found — you may need to install it:"
        print_info "  sudo apt-get install -y chromium-browser"
    fi

    echo ""

    # Boot target verification
    local current_target
    current_target=$(systemctl get-default 2>/dev/null || echo "unknown")
    print_info "Current boot target: $current_target"

    if [ "$SIMULATE" = true ]; then
        echo ""
        print_info "SIMULATE MODE — no changes were made"
        print_info "Re-run without --simulate to apply changes"
    else
        echo ""
        print_warning "A reboot is recommended to complete the optimization"
        if confirm "Reboot now?" "n"; then
            print_info "Rebooting in 5 seconds..."
            sleep 5
            reboot
        else
            print_info "Remember to reboot when convenient: sudo reboot"
        fi
    fi
}

###############################################################################
# Main
###############################################################################

main() {
    check_root
    if [ "$NON_INTERACTIVE" = false ]; then
        ensure_gum || print_warning "gum unavailable; continuing without TUI"
    fi
    clear

    print_header "OpenClaw Pi - Headless Optimization v$SCRIPT_VERSION"

    cat << 'EOF'
This utility optimizes a Raspberry Pi OS Desktop installation for
headless operation with OpenClaw.

Phases:
 0. Safety & Baseline
 1. Desktop Mode Decision (disable vs remove)
 2. Remove Bloat Packages (office, games, media)
 3. Disable Unnecessary Services
 4. Desktop Plumbing Removal (if remove mode selected)
 5. Housekeeping (cleanup, cache, logs)
 6. Verification & Summary

Chromium is ALWAYS preserved (required by OpenClaw).

EOF

    if [ "$SIMULATE" = true ]; then
        print_warning "SIMULATE MODE — no changes will be applied"
        echo ""
    fi

    if [ "$NON_INTERACTIVE" = false ] && [ "$SIMULATE" = false ]; then
        if ! confirm "Continue with headless optimization?" "y"; then
            print_info "Optimization cancelled"
            exit 0
        fi
    fi

    # Run phases
    phase_safety_baseline
    phase_desktop_decision
    phase_remove_bloat
    phase_disable_services
    phase_remove_desktop_plumbing
    phase_housekeeping
    phase_verification

    print_success "Headless optimization complete!"
    print_info "Log file: $LOGFILE"
}

# Run main
main "$@"
