#!/bin/bash

###############################################################################
# OpenClaw Raspberry Pi - Complete Security Hardening Script
#
# Version: 2.3
# Changes from 2.2:
#  - User session environment (DBUS/XDG_RUNTIME_DIR) for Gateway
#  - OpenClaw Gateway Tailscale integration (serve/funnel/off)
#  - Developer tools and API proxy guidance
#  - UFW outbound rule for Tailscale interface
#  - Fixed Gateway systemctl --user failures
#
# This script performs comprehensive security hardening for Raspberry Pi
# systems running OpenClaw. It can be run on fresh installations or existing
# systems, with smart detection of already-configured components.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/install.sh | sudo bash
#        OR
#        sudo ./harden-openclaw-pi.sh [--non-interactive] [--skip-long-ops]
#
# Author: Community Contribution
# License: MIT
# Version: 2.3
###############################################################################

set -e  # Exit on error

# Script configuration
SCRIPT_VERSION="2.3"
VERSION_FILE="/etc/openclaw-hardening-version"
OPENCLAW_USER="openclaw"
LOGFILE="/var/log/openclaw-hardening-$(date +%Y%m%d-%H%M%S).log"
NON_INTERACTIVE=false
SKIP_LONG_OPS=false

# Signal trap for clean interrupts
cleanup() {
    echo ""
    echo -e "\033[1;33m⚠ Installation interrupted!\033[0m"
    echo -e "\033[0;36mℹ The system may be partially configured.\033[0m"
    echo -e "\033[0;36mℹ Re-run this script to complete hardening.\033[0m"
    echo -e "\033[0;36mℹ Log file: $LOGFILE\033[0m"
    exit 1
}
trap cleanup INT TERM

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --skip-long-ops)
            SKIP_LONG_OPS=true
            shift
            ;;
        --help|-h)
            cat << 'HELPEOF'
OpenClaw Raspberry Pi Security Hardening Script v2.3

Usage: sudo ./harden-openclaw-pi.sh [OPTIONS]

Options:
  --non-interactive  Run without prompts (use defaults)
  --skip-long-ops    Skip time-consuming operations (AIDE init, etc.)
  --help, -h         Show this help message

Features:
  - Version tracking and upgrade detection
  - Preserves custom configurations
  - Tailscale integration
  - OpenClaw installer integration
  - Comprehensive security hardening

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

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
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
    echo -e "${YELLOW}⊘ $1${NC}"
}

print_progress() {
    echo -e "${MAGENTA}⟳ $1${NC}"
}

confirm() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi

    local prompt="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    while true; do
        read -rp "$prompt" response
        response=${response:-$default}
        case "$response" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_os() {
    print_header "System Detection"

    if [ ! -f /etc/os-release ]; then
        print_error "Cannot determine OS version"
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    print_info "OS: $PRETTY_NAME"
    print_info "Version: $VERSION_ID"
    print_info "Codename: ${VERSION_CODENAME:-unknown}"

    # Check if Raspberry Pi
    if [ -f /proc/device-tree/model ]; then
        RPI_MODEL=$(cat /proc/device-tree/model)
        print_info "Hardware: $RPI_MODEL"
    fi

    # Verify Debian-based
    if [[ ! "$ID" =~ (debian|raspbian) ]]; then
        print_warning "This script is designed for Debian/Raspbian-based systems"
        print_warning "Detected OS: $ID"

        if ! confirm "Continue anyway? This may cause issues"; then
            exit 1
        fi
    fi

    print_success "System detection complete"
}

check_version() {
    print_header "Version Detection"

    if [ -f "$VERSION_FILE" ]; then
        INSTALLED_VERSION=$(cat "$VERSION_FILE")
        print_info "Previous installation detected: v$INSTALLED_VERSION"

        if [ "$INSTALLED_VERSION" = "$SCRIPT_VERSION" ]; then
            print_info "Same version - will verify and update configurations"
        else
            print_success "Upgrading from v$INSTALLED_VERSION to v$SCRIPT_VERSION"
        fi
    else
        print_info "First-time installation"
    fi
}

check_disk_space() {
    local available_mb
    available_mb=$(df -BM / | awk 'NR==2 {print int($4)}')
    if [ "$available_mb" -lt 500 ]; then
        print_error "Less than 500MB free disk space (${available_mb}MB available)"
        print_error "Installation requires at least 500MB free"
        exit 1
    fi
    print_info "Available disk space: ${available_mb}MB"
}

save_version() {
    echo "$SCRIPT_VERSION" > "$VERSION_FILE"
    chmod 644 "$VERSION_FILE"
    print_success "Saved installation version: v$SCRIPT_VERSION"
}

is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

is_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

is_service_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

user_exists() {
    id "$1" &>/dev/null
}

file_hash() {
    md5sum "$1" 2>/dev/null | cut -d' ' -f1
}

###############################################################################
# Long-Running Process Handler
###############################################################################

run_with_progress() {
    local description="$1"
    local command="$2"
    local monitor_file="$3"
    local skip_message="$4"
    local estimated_time="$5"

    print_warning "$description"
    print_info "Estimated time: $estimated_time"

    if [ "$SKIP_LONG_OPS" = true ]; then
        print_skip "Skipping (--skip-long-ops flag set)"
        if [ -n "$skip_message" ]; then
            print_info "$skip_message"
        fi
        return 1
    fi

    if [ "$NON_INTERACTIVE" = false ]; then
        echo ""
        echo "Options:"
        echo "  1) Run now (recommended)"
        echo "  2) Skip and run manually later"
        echo ""
        read -rp "Choose [1-2]: " choice

        case "$choice" in
            2)
                print_skip "Skipping - will run manually later"
                if [ -n "$skip_message" ]; then
                    print_info "$skip_message"
                fi
                return 1
                ;;
            *)
                print_info "Starting process..."
                ;;
        esac
    fi

    # Run command in background
    eval "$command" &
    local pid=$!

    # Monitor progress
    local dots=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ -n "$monitor_file" ] && [ -f "$monitor_file" ]; then
            local size
            size=$(du -h "$monitor_file" 2>/dev/null | cut -f1)
            echo -ne "\r${MAGENTA}⟳${NC} Processing... ${size:-0} "
        else
            local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
            echo -ne "\r${MAGENTA}${spinner[$dots]}${NC} Processing... "
            dots=$(( (dots + 1) % 10 ))
        fi
        sleep 1
    done

    wait "$pid" || true
    local exit_code=$?

    echo -ne "\r"

    if [ $exit_code -eq 0 ]; then
        print_success "Process completed successfully"
        return 0
    else
        print_error "Process failed with exit code $exit_code"
        return "$exit_code"
    fi
}

###############################################################################
# Step 1: System Updates
###############################################################################

configure_system_updates() {
    print_header "Step 1: System Updates"

    if confirm "Update system packages now?" "y"; then
        print_info "Updating package lists..."
        apt-get update -y

        print_info "Upgrading installed packages..."
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

        print_success "System packages updated"
    else
        print_skip "Skipping system update"
    fi

    # Install unattended-upgrades
    if is_package_installed unattended-upgrades; then
        print_skip "unattended-upgrades already installed"
    else
        print_info "Installing unattended-upgrades..."
        apt-get install -y unattended-upgrades apt-listchanges
    fi

    # Configure automatic updates
    print_info "Configuring automatic security updates..."

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Raspbian,codename=${distro_codename}";
    "origin=Raspberry Pi Foundation,codename=${distro_codename}";
};

Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    print_success "Automatic security updates configured"
}

###############################################################################
# Step 2: Firewall
###############################################################################

configure_firewall() {
    print_header "Step 2: Firewall (UFW)"

    if ! is_package_installed ufw; then
        print_info "Installing UFW..."
        apt-get install -y ufw
    else
        print_skip "UFW already installed"
    fi

    if is_service_active ufw; then
        print_skip "UFW is already active"
        ufw status verbose

        if ! confirm "Reconfigure firewall rules?"; then
            return
        fi
    fi

    print_info "Configuring firewall rules..."

    # Set defaults
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH
    ufw allow 22/tcp comment 'SSH'

    # Enable firewall
    ufw --force enable

    print_success "Firewall configured (deny incoming, allow outgoing, SSH allowed)"
    ufw status verbose
}

###############################################################################
# Step 3: Intrusion Prevention (fail2ban)
###############################################################################

configure_fail2ban() {
    print_header "Step 3: Intrusion Prevention (fail2ban)"

    if is_package_installed fail2ban; then
        print_skip "fail2ban already installed"

        # Check for custom configuration
        if [ -f /etc/fail2ban/jail.local ]; then
            print_warning "Existing fail2ban configuration detected"

            # Backup existing config
            cp /etc/fail2ban/jail.local "/etc/fail2ban/jail.local.backup-$(date +%Y%m%d-%H%M%S)"
            print_info "Backed up existing configuration"

            if confirm "Preserve existing jail.local? (Recommended if you have custom jails)"; then
                print_skip "Skipping fail2ban reconfiguration"
                print_info "Your custom configuration has been preserved"
                return
            fi
        fi

        if ! confirm "Reconfigure fail2ban?"; then
            print_skip "Skipping fail2ban configuration"
            return
        fi
    else
        print_info "Installing fail2ban..."
        apt-get install -y fail2ban
    fi

    print_info "Configuring fail2ban..."

    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 3600
findtime = 600
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban

    print_success "fail2ban configured and running"
    sleep 2
    fail2ban-client status sshd || true
}

###############################################################################
# Step 4: User Accounts
###############################################################################

configure_users() {
    print_header "Step 4: User Account Configuration"

    # Create openclaw user
    if user_exists "$OPENCLAW_USER"; then
        print_skip "User '$OPENCLAW_USER' already exists"
    else
        print_info "Creating user '$OPENCLAW_USER' (no sudo access)..."
        useradd -m -s /bin/bash "$OPENCLAW_USER"

        if [ "$NON_INTERACTIVE" = false ]; then
            print_info "Set password for '$OPENCLAW_USER':"
            passwd "$OPENCLAW_USER"
        else
            passwd -l "$OPENCLAW_USER"
            print_warning "Account locked - set password manually: sudo passwd $OPENCLAW_USER"
        fi

        print_success "User '$OPENCLAW_USER' created"
    fi

    # Ensure correct permissions
    chmod 700 "/home/${OPENCLAW_USER:?}"
    print_success "Home directory permissions set to 700"

    # Enable persistent user session for OpenClaw Gateway
    # Without this, systemctl --user fails (missing DBUS_SESSION_BUS_ADDRESS / XDG_RUNTIME_DIR)
    print_info "Setting up user session environment for OpenClaw..."
    loginctl enable-linger "$OPENCLAW_USER" || {
        print_warning "Could not enable lingering - may need manual setup"
    }
    su - "$OPENCLAW_USER" << 'ENVVARS'
if ! grep -q "XDG_RUNTIME_DIR" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'
# User session environment for OpenClaw Gateway
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
EOF
fi
ENVVARS
    print_success "User session environment configured"

    # Optionally create admin user
    if ! user_exists "rpi-admin"; then
        if confirm "Create 'rpi-admin' user with sudo access?"; then
            useradd -m -s /bin/bash -G sudo rpi-admin

            if [ "$NON_INTERACTIVE" = false ]; then
                print_info "Set password for 'rpi-admin':"
                passwd rpi-admin
            else
                passwd -l rpi-admin
                print_warning "Account locked - set password manually: sudo passwd rpi-admin"
            fi

            print_success "Admin user 'rpi-admin' created with sudo access"
        fi
    else
        print_skip "User 'rpi-admin' already exists"
    fi
}

###############################################################################
# Step 5: SSH Hardening
###############################################################################

configure_ssh() {
    print_header "Step 5: SSH Hardening"

    local ssh_config_dir="/etc/ssh/sshd_config.d"
    local hardening_conf="$ssh_config_dir/99-openclaw-hardening.conf"

    # Backup existing config
    if [ -f "$hardening_conf" ]; then
        cp "$hardening_conf" "${hardening_conf}.backup-$(date +%Y%m%d-%H%M%S)"
        print_info "Backed up existing SSH hardening config"
    fi

    # Ensure config directory exists
    mkdir -p "$ssh_config_dir"

    print_info "Writing SSH hardening configuration..."

    cat > "$hardening_conf" << 'EOF'
# OpenClaw Pi SSH Hardening - v2.3
# Applied by harden-openclaw-pi.sh

# Disable root login
PermitRootLogin no

# Authentication settings
MaxAuthTries 3
PubkeyAuthentication yes
PermitEmptyPasswords no
LoginGraceTime 30

# Disable unnecessary features
X11Forwarding no
AllowAgentForwarding no

# Session timeouts
ClientAliveInterval 300
ClientAliveCountMax 2

# Modern cryptography only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
EOF

    # Test SSH config before applying
    if sshd -t 2>/dev/null; then
        print_success "SSH configuration valid"
        systemctl restart sshd
        print_success "SSH restarted with hardened config"
    else
        print_error "SSH configuration test failed - reverting"
        rm -f "$hardening_conf"
        # Restore most recent backup if one exists
        local latest_backup
        latest_backup=$(find "$(dirname "$hardening_conf")" -maxdepth 1 -name "$(basename "$hardening_conf").backup-*" -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            mv "$latest_backup" "$hardening_conf"
        fi
        return 1
    fi

    # Password authentication option
    print_warning "Password authentication is currently enabled"
    print_warning "IMPORTANT: Set up SSH keys BEFORE disabling password auth!"
    print_info "  From your local machine: ssh-copy-id user@raspberry-pi"
    echo ""

    if confirm "Disable password authentication? (Only do this if SSH keys are set up!)"; then
        echo "PasswordAuthentication no" >> "$hardening_conf"

        if sshd -t 2>/dev/null; then
            systemctl restart sshd
            print_success "Password authentication disabled"
        else
            # Remove the line we just added
            sed -i '/^PasswordAuthentication no$/d' "$hardening_conf"
            print_error "Failed to apply - password auth remains enabled"
        fi
    else
        print_info "Password authentication remains enabled"
        print_info "Disable later by adding 'PasswordAuthentication no' to $hardening_conf"
    fi
}

###############################################################################
# Step 6: Security Tools Installation
###############################################################################

install_security_tools() {
    print_header "Step 6: Installing Security Tools"

    local packages=(aide chkrootkit rkhunter auditd audispd-plugins lynis)
    local installed=0
    local newly_installed=0

    for pkg in "${packages[@]}"; do
        if is_package_installed "$pkg"; then
            print_skip "$pkg already installed"
            ((installed++))
        else
            print_info "Installing $pkg..."
            apt-get install -y "$pkg"
            ((newly_installed++))
        fi
    done

    print_success "Security tools ready ($installed already installed, $newly_installed newly installed)"
}

###############################################################################
# Step 6b: AIDE Configuration
###############################################################################

configure_aide() {
    print_header "Step 6b: AIDE File Integrity Monitoring"

    if [ -f /var/lib/aide/aide.db ]; then
        print_skip "AIDE database already initialized"
        print_info "Update after changes: sudo /usr/local/bin/update-aide-db.sh"
        return
    fi

    # Add OpenClaw-specific paths to monitor
    if [ -f /etc/aide/aide.conf ]; then
        if ! grep -q "openclaw" /etc/aide/aide.conf 2>/dev/null; then
            print_info "Adding OpenClaw paths to AIDE configuration..."
            cat >> /etc/aide/aide.conf << EOF

# OpenClaw monitoring
/home/${OPENCLAW_USER:?}/.openclaw CONTENT_EX
/usr/local/bin/security-scan.sh CONTENT_EX
/usr/local/bin/update-aide-db.sh CONTENT_EX
/etc/ssh/sshd_config CONTENT_EX
/etc/fail2ban/jail.local CONTENT_EX
EOF
            print_success "AIDE configuration updated with OpenClaw paths"
        fi
    fi

    # Initialize AIDE database
    run_with_progress \
        "AIDE database initialization (scans entire filesystem)" \
        "aideinit && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db" \
        "/var/lib/aide/aide.db.new" \
        "Run manually later: sudo aideinit && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db" \
        "10-30 minutes on Raspberry Pi" \
    || print_info "AIDE initialization skipped - remember to run it later"
}

###############################################################################
# Step 6c: rkhunter Configuration
###############################################################################

configure_rkhunter() {
    print_header "Step 6c: rkhunter Configuration"

    if [ ! -f /etc/rkhunter.conf ]; then
        print_error "rkhunter configuration not found"
        return 1
    fi

    print_info "Configuring rkhunter..."

    # Set WEB_CMD without quotes (quoted form breaks rkhunter)
    sed -i 's|^WEB_CMD=.*|WEB_CMD=/usr/bin/curl|' /etc/rkhunter.conf

    # Disable unreliable online mirror updates
    sed -i 's|^UPDATE_MIRRORS=.*|UPDATE_MIRRORS=0|' /etc/rkhunter.conf
    sed -i 's|^MIRRORS_MODE=.*|MIRRORS_MODE=0|' /etc/rkhunter.conf

    # SSH settings
    sed -i 's|^ALLOW_SSH_ROOT_USER=.*|ALLOW_SSH_ROOT_USER=no|' /etc/rkhunter.conf
    sed -i 's|^ALLOW_SSH_PROT_V1=.*|ALLOW_SSH_PROT_V1=0|' /etc/rkhunter.conf

    # Common Debian/Raspbian false positive allowlists
    if ! grep -q "SCRIPTWHITELIST=/usr/bin/lwp-request" /etc/rkhunter.conf 2>/dev/null; then
        echo "SCRIPTWHITELIST=/usr/bin/lwp-request" >> /etc/rkhunter.conf
    fi

    # Update signatures and file properties
    print_info "Updating rkhunter signatures..."
    rkhunter --update || print_warning "rkhunter signature update failed (may be normal on first run)"

    print_info "Updating rkhunter file properties database..."
    rkhunter --propupd

    print_success "rkhunter configured"
}

###############################################################################
# Step 6d: auditd Configuration
###############################################################################

configure_auditd() {
    print_header "Step 6d: Audit Framework (auditd)"

    local rules_file="/etc/audit/rules.d/openclaw.rules"

    # Get openclaw user UID
    local openclaw_uid
    if user_exists "$OPENCLAW_USER"; then
        openclaw_uid=$(id -u "$OPENCLAW_USER")
    else
        print_warning "User '$OPENCLAW_USER' does not exist yet - using placeholder UID"
        openclaw_uid=1001
    fi

    print_info "Creating audit rules..."

    # Always-present syscall rules (work regardless of OpenClaw install state)
    cat > "$rules_file" << EOF
# OpenClaw Security Audit Rules
# Generated by harden-openclaw-pi.sh v${SCRIPT_VERSION}

# User activity monitoring
-a always,exit -F arch=b64 -F uid=${openclaw_uid} -S execve -k openclaw_exec
-a always,exit -F arch=b64 -F uid=${openclaw_uid} -S socket -k openclaw_network
-a always,exit -F arch=b64 -F uid=${openclaw_uid} -S connect -k openclaw_network

# SSH configuration changes
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_config

# Firewall changes
-w /etc/ufw/ -p wa -k firewall_config

# Cron changes
-w /etc/crontab -p wa -k cron_config
-w /etc/cron.d/ -p wa -k cron_config
-w /var/spool/cron/ -p wa -k cron_config
EOF

    # Conditional file watches - only if OpenClaw directories exist
    if [ -d "/home/${OPENCLAW_USER:?}/.openclaw" ]; then
        cat >> "$rules_file" << EOF

# File integrity monitoring (OpenClaw installed)
-w /home/${OPENCLAW_USER}/.openclaw/openclaw.json -p wa -k openclaw_config
-w /home/${OPENCLAW_USER}/.openclaw/agents/ -p wa -k openclaw_agents
-w /home/${OPENCLAW_USER}/.openclaw/extensions/ -p wa -k openclaw_extensions
-w /home/${OPENCLAW_USER}/.openclaw/credentials/ -p wa -k openclaw_credentials
EOF
        print_info "Added OpenClaw file integrity monitoring"
    else
        print_warning "OpenClaw not installed - file watches will be added after installation"
    fi

    # Load rules
    systemctl enable auditd
    systemctl restart auditd

    # Use augenrules if available, otherwise restart is sufficient
    if command -v augenrules &>/dev/null; then
        augenrules --load 2>/dev/null || true
    fi

    # Verify rules loaded
    local rules_count
    rules_count=$(auditctl -l 2>/dev/null | grep -c openclaw || echo "0")
    if [ "$rules_count" -gt 0 ]; then
        print_success "Loaded $rules_count audit rules successfully"
    else
        print_warning "Audit rules may not have loaded yet - they will apply after reboot"
    fi
}

# Helper to update auditd rules after OpenClaw install
update_auditd_for_openclaw() {
    if [ -d "/home/${OPENCLAW_USER:?}/.openclaw" ] && [ -f /etc/audit/rules.d/openclaw.rules ]; then
        if ! grep -q "openclaw_config" /etc/audit/rules.d/openclaw.rules 2>/dev/null; then
            print_info "Adding OpenClaw file integrity monitoring to audit rules..."
            cat >> /etc/audit/rules.d/openclaw.rules << EOF

# File integrity monitoring (OpenClaw installed - added post-install)
-w /home/${OPENCLAW_USER}/.openclaw/openclaw.json -p wa -k openclaw_config
-w /home/${OPENCLAW_USER}/.openclaw/agents/ -p wa -k openclaw_agents
-w /home/${OPENCLAW_USER}/.openclaw/extensions/ -p wa -k openclaw_extensions
-w /home/${OPENCLAW_USER}/.openclaw/credentials/ -p wa -k openclaw_credentials
EOF
            if command -v augenrules &>/dev/null; then
                augenrules --load 2>/dev/null || true
            fi
            print_success "Audit rules updated with OpenClaw file watches"
        fi
    fi
}

###############################################################################
# Step 6e: Lynis Configuration
###############################################################################

configure_lynis() {
    print_header "Step 6e: Lynis Security Auditing"

    if ! command -v lynis &>/dev/null; then
        print_error "Lynis not found - install with: apt install lynis"
        return 1
    fi

    print_info "Lynis version: $(lynis show version 2>/dev/null || echo 'unknown')"
    print_info "Run anytime with: sudo lynis audit system"

    if confirm "Run initial Lynis audit now?"; then
        run_with_progress \
            "Lynis security audit" \
            "lynis audit system --no-colors > /var/log/lynis-initial-audit.log 2>&1" \
            "" \
            "Run manually: sudo lynis audit system" \
            "5-10 minutes" \
        || print_info "Lynis audit skipped"
    else
        print_skip "Lynis audit skipped - run later with: sudo lynis audit system"
    fi

    print_success "Lynis ready"
}

###############################################################################
# Step 7: Attack Surface Minimization
###############################################################################

minimize_attack_surface() {
    print_header "Step 7: Minimizing Attack Surface"

    # Disable unnecessary services
    local services_to_disable=(bluetooth.service avahi-daemon.service cups.service cups-browsed.service triggerhappy.service)

    for service in "${services_to_disable[@]}"; do
        if systemctl list-unit-files "$service" &>/dev/null && is_service_enabled "$service" 2>/dev/null; then
            if confirm "Disable $service?"; then
                systemctl stop "$service" 2>/dev/null || true
                systemctl disable "$service" 2>/dev/null || true
                print_success "Disabled $service"
            else
                print_skip "Keeping $service enabled"
            fi
        fi
    done

    # Kernel hardening
    print_info "Applying kernel security parameters..."

    cat > /etc/sysctl.d/99-openclaw-hardening.conf << 'EOF'
# OpenClaw Pi Kernel Hardening

# Enable reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0

# Ignore broadcast ICMP
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable SYN cookies (DoS protection)
net.ipv4.tcp_syncookies = 1

# Enable ASLR
kernel.randomize_va_space = 2
EOF

    sysctl --system > /dev/null 2>&1
    print_success "Kernel parameters hardened"

    # Harden /tmp
    print_info "Hardening /tmp mount..."

    if ! mount | grep -q "/tmp.*noexec"; then
        # Add to fstab if not present
        if ! grep -q "^tmpfs.*/tmp" /etc/fstab 2>/dev/null; then
            echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
            print_info "Added /tmp hardening to /etc/fstab"
        fi

        # Apply now
        mount -o remount,noexec,nosuid,nodev /tmp 2>/dev/null || \
            print_warning "Could not remount /tmp - will take effect on next reboot"

        print_success "/tmp hardened with noexec,nosuid,nodev"
    else
        print_skip "/tmp already has noexec mount option"
    fi
}

###############################################################################
# Step 8: Logging & Monitoring
###############################################################################

configure_logging() {
    print_header "Step 8: Logging & Monitoring"

    # Configure log rotation for security scans
    print_info "Configuring log rotation..."

    cat > /etc/logrotate.d/openclaw-security << 'EOF'
/var/log/security-scan.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}

/var/log/openclaw-hardening-*.log {
    monthly
    rotate 6
    compress
    missingok
    notifempty
}

/var/log/lynis-*.log {
    monthly
    rotate 6
    compress
    missingok
    notifempty
}
EOF

    print_success "Log rotation configured"

    # Configure journald persistence
    print_info "Configuring journald persistence..."

    mkdir -p /var/log/journal

    if [ -f /etc/systemd/journald.conf ]; then
        # Set Storage=persistent
        if grep -q "^#\?Storage=" /etc/systemd/journald.conf; then
            sed -i 's/^#\?Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
        else
            echo "Storage=persistent" >> /etc/systemd/journald.conf
        fi

        # Set size limit
        if grep -q "^#\?SystemMaxUse=" /etc/systemd/journald.conf; then
            sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=200M/' /etc/systemd/journald.conf
        else
            echo "SystemMaxUse=200M" >> /etc/systemd/journald.conf
        fi

        # Set retention
        if grep -q "^#\?MaxRetentionSec=" /etc/systemd/journald.conf; then
            sed -i 's/^#\?MaxRetentionSec=.*/MaxRetentionSec=1month/' /etc/systemd/journald.conf
        else
            echo "MaxRetentionSec=1month" >> /etc/systemd/journald.conf
        fi

        systemctl restart systemd-journald
        print_success "Journald persistence configured (200MB max, 1 month retention)"
    fi
}

###############################################################################
# Step 9: File System Permissions
###############################################################################

configure_file_permissions() {
    print_header "Step 9: File System Permissions"

    local openclaw_home="/home/${OPENCLAW_USER:?}"

    if [ -d "$openclaw_home" ]; then
        # Home directory
        chmod 700 "$openclaw_home"

        # Create .openclaw directory structure if it doesn't exist
        local dirs=(.openclaw .openclaw/agents .openclaw/credentials .openclaw/extensions .openclaw/sessions .openclaw/logs)
        for dir in "${dirs[@]}"; do
            if [ ! -d "$openclaw_home/$dir" ]; then
                mkdir -p "$openclaw_home/$dir"
            fi
        done

        # Set directory permissions
        chmod 700 "$openclaw_home/.openclaw"
        chmod 700 "$openclaw_home/.openclaw/agents"
        chmod 700 "$openclaw_home/.openclaw/credentials"
        chmod 755 "$openclaw_home/.openclaw/extensions"
        chmod 755 "$openclaw_home/.openclaw/sessions"
        chmod 755 "$openclaw_home/.openclaw/logs"

        # Set file permissions
        if [ -f "$openclaw_home/.openclaw/openclaw.json" ]; then
            chmod 600 "$openclaw_home/.openclaw/openclaw.json"
        fi

        # Secure credential files
        find "$openclaw_home/.openclaw/credentials" -type f -exec chmod 600 {} \; 2>/dev/null || true

        # Fix ownership
        chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "$openclaw_home"

        print_success "OpenClaw user directory permissions secured"
    else
        print_warning "Home directory $openclaw_home does not exist"
    fi

    # Restrict sensitive system files
    if [ -f /etc/ssh/sshd_config ]; then
        chmod 600 /etc/ssh/sshd_config
    fi

    if [ -f /etc/shadow ]; then
        chmod 640 /etc/shadow
    fi

    print_success "File system permissions configured"
}

###############################################################################
# Step 10: Automated Security Scanning Scripts
###############################################################################

create_security_scan_script() {
    print_header "Step 10: Automated Security Scanning"

    # Check if script exists and offer to replace
    if [ -f /usr/local/bin/security-scan.sh ]; then
        print_warning "security-scan.sh already exists"

        cp /usr/local/bin/security-scan.sh "/usr/local/bin/security-scan.sh.backup-$(date +%Y%m%d-%H%M%S)"
        print_info "Backed up existing script"

        if ! confirm "Replace with new version?"; then
            print_skip "Preserving existing security-scan.sh"
        else
            print_info "Creating updated security scan script..."
            _write_security_scan_script
        fi
    else
        print_info "Creating security scan script..."
        _write_security_scan_script
    fi

    # Create or update AIDE helper
    if [ -f /usr/local/bin/update-aide-db.sh ]; then
        print_skip "update-aide-db.sh already exists"
    else
        _write_aide_update_script
    fi
}

_write_security_scan_script() {
    cat > /usr/local/bin/security-scan.sh << 'SCANSCRIPT'
#!/bin/bash
# OpenClaw Security Scan Script
# Runs comprehensive security checks
# Scheduled via cron: daily at 2:00 AM

set -euo pipefail

LOG="/var/log/security-scan.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "========================================" >> "$LOG"
echo "Security Scan: $TIMESTAMP" >> "$LOG"
echo "========================================" >> "$LOG"

# 1. AIDE file integrity check
if command -v aide &>/dev/null && [ -f /var/lib/aide/aide.db ]; then
    echo "" >> "$LOG"
    echo "[AIDE] Running file integrity check..." >> "$LOG"
    aide --check >> "$LOG" 2>&1 || echo "[AIDE] Changes detected (review above)" >> "$LOG"
else
    echo "[AIDE] Not initialized - skipping" >> "$LOG"
fi

# 2. rkhunter rootkit scan
if command -v rkhunter &>/dev/null; then
    echo "" >> "$LOG"
    echo "[RKHUNTER] Running rootkit scan..." >> "$LOG"
    rkhunter --check --nocolors --skip-keypress >> "$LOG" 2>&1 || true
fi

# 3. chkrootkit scan
if command -v chkrootkit &>/dev/null; then
    echo "" >> "$LOG"
    echo "[CHKROOTKIT] Running rootkit scan..." >> "$LOG"
    chkrootkit >> "$LOG" 2>&1 || true
fi

# 4. Failed SSH logins (last 24 hours)
echo "" >> "$LOG"
echo "[SSH] Recent failed login attempts:" >> "$LOG"
journalctl -u sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -i "failed\|invalid" >> "$LOG" 2>&1 || echo "  No failed attempts" >> "$LOG"

# 5. fail2ban status
if command -v fail2ban-client &>/dev/null; then
    echo "" >> "$LOG"
    echo "[FAIL2BAN] Status:" >> "$LOG"
    fail2ban-client status sshd >> "$LOG" 2>&1 || echo "  fail2ban not running" >> "$LOG"
fi

# 6. Listening network ports
echo "" >> "$LOG"
echo "[NETWORK] Listening ports:" >> "$LOG"
ss -tulnp >> "$LOG" 2>&1

# 7. SUID/SGID files
echo "" >> "$LOG"
echo "[SUID] SUID files on system:" >> "$LOG"
find / -perm -4000 -type f 2>/dev/null >> "$LOG"

# 8. World-writable files in sensitive locations
echo "" >> "$LOG"
echo "[PERMS] World-writable files:" >> "$LOG"
find /etc /usr -perm -002 -type f 2>/dev/null >> "$LOG" || echo "  None found" >> "$LOG"

# 9. Disk usage
echo "" >> "$LOG"
echo "[DISK] Usage:" >> "$LOG"
df -h >> "$LOG" 2>&1

# 10. User account check
echo "" >> "$LOG"
echo "[USERS] Users with login shells:" >> "$LOG"
grep -v '/nologin\|/false' /etc/passwd >> "$LOG" 2>&1

echo "" >> "$LOG"
echo "Scan complete: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
echo "========================================" >> "$LOG"
SCANSCRIPT

    chmod +x /usr/local/bin/security-scan.sh
    print_success "Security scan script created"
}

_write_aide_update_script() {
    cat > /usr/local/bin/update-aide-db.sh << 'AIDESCRIPT'
#!/bin/bash
# Update AIDE database after legitimate system changes
# Run this after installing packages, updating configs, etc.

set -euo pipefail

echo "Updating AIDE database..."
echo "This may take several minutes on Raspberry Pi..."

if ! command -v aide &>/dev/null; then
    echo "ERROR: AIDE is not installed" >&2
    exit 1
fi

if [ ! -f /var/lib/aide/aide.db ]; then
    echo "ERROR: No existing AIDE database found" >&2
    echo "Initialize first: sudo aideinit && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db" >&2
    exit 1
fi

aide --update

if [ -f /var/lib/aide/aide.db.new ]; then
    cp /var/lib/aide/aide.db "/var/lib/aide/aide.db.bak-$(date +%Y%m%d)"
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    echo "AIDE database updated successfully."
    echo "Previous database backed up."
else
    echo "ERROR: AIDE update did not produce a new database." >&2
    exit 1
fi
AIDESCRIPT

    chmod +x /usr/local/bin/update-aide-db.sh
    print_success "AIDE update script created"
}

###############################################################################
# Step 10b: Cron Jobs
###############################################################################

setup_cron_jobs() {
    print_header "Step 10b: Scheduled Security Tasks"

    local cron_file="/etc/cron.d/openclaw-security"

    print_info "Configuring scheduled security tasks..."

    cat > "$cron_file" << 'EOF'
# OpenClaw Pi - Scheduled Security Tasks
# Installed by harden-openclaw-pi.sh

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Daily comprehensive security scan at 2:00 AM
0 2 * * * root /usr/local/bin/security-scan.sh >> /var/log/security-scan.log 2>&1

# Weekly rkhunter signature update (Sundays at 3:00 AM)
0 3 * * 0 root rkhunter --update --nocolors >> /var/log/rkhunter-update.log 2>&1

# Weekly rkhunter property update (Sundays at 3:15 AM)
15 3 * * 0 root rkhunter --propupd --nocolors >> /var/log/rkhunter-update.log 2>&1
EOF

    chmod 644 "$cron_file"

    print_success "Scheduled tasks configured:"
    print_info "  Daily 2:00 AM - Comprehensive security scan"
    print_info "  Sunday 3:00 AM - rkhunter signature and property update"
}

###############################################################################
# Tailscale Installation and Configuration
###############################################################################

install_tailscale() {
    print_header "Tailscale Installation (Optional)"

    print_info "Tailscale provides secure remote access via encrypted WireGuard VPN"
    print_info "Benefits:"
    echo "  - Faster than Raspberry Pi Connect"
    echo "  - Direct peer-to-peer connections when possible"
    echo "  - Works with standard SSH, Termux on Android, etc."
    echo "  - Zero-trust network architecture"
    echo "  - Native OpenClaw Gateway integration (serve/funnel modes)"
    echo ""

    if ! confirm "Install/configure Tailscale?"; then
        print_skip "Skipping Tailscale installation"
        return
    fi

    # Variables used across the function
    local tailscale_ip=""
    local tailscale_hostname="rpi-openclaw"

    # Check if already installed
    if command -v tailscale &> /dev/null; then
        print_skip "Tailscale already installed"

        if tailscale status &> /dev/null; then
            print_success "Tailscale is already running"
            tailscale status | head -10
            tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "")
        fi
    else
        # Fresh install
        print_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh

        print_info "Starting Tailscale..."
        print_warning "You will need to authenticate via the URL shown below"

        tailscale up

        print_info "Setting Tailscale hostname to: $tailscale_hostname"
        tailscale set --hostname "$tailscale_hostname"

        tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "")
        print_success "Tailscale installed and configured"
    fi

    if [ -n "$tailscale_ip" ]; then
        print_success "Tailscale IP: $tailscale_ip"
        print_info "Device name: $tailscale_hostname"
    fi

    # Update UFW to allow Tailscale (idempotent — ufw handles duplicate rules gracefully)
    print_info "Configuring firewall for Tailscale..."
    ufw allow in on tailscale0
    ufw allow out on tailscale0
    print_success "Firewall configured for Tailscale (inbound + outbound)"

    # SSH restriction option
    if confirm "Restrict SSH to Tailscale-only? (More secure, but requires Tailscale to access)"; then
        print_warning "Configuring SSH to only accept connections via Tailscale"

        ufw delete allow 22/tcp 2>/dev/null || true
        ufw allow in on tailscale0 to any port 22 proto tcp

        print_success "SSH now only accessible via Tailscale network"
        print_warning "Make sure you're connected via Tailscale before closing this session!"
    fi

    # =========================================================================
    # OpenClaw Gateway / Tailscale Integration
    # =========================================================================
    echo ""
    print_header "OpenClaw Gateway - Tailscale Integration"
    print_info "OpenClaw has native Tailscale integration for its Gateway service."
    print_info "Three Gateway modes available:"
    echo "  serve  - Access via your Tailnet only (identity-based auth, no passwords)"
    echo "  funnel - Public internet access via Tailscale Funnel (shared password required)"
    echo "  off    - No Tailscale Gateway automation (default)"
    echo ""
    print_info "Prerequisites for serve/funnel modes:"
    echo "  - MagicDNS enabled in Tailscale admin console"
    echo "  - HTTPS certificates enabled in Tailscale admin console"
    echo "  - For funnel: Tailscale v1.38.3+ (ports 443, 8443, or 10000 over TLS)"
    echo ""
    print_info "Documentation: https://docs.openclaw.ai/gateway/tailscale"
    echo ""

    # Variables for Gateway config
    local openclaw_home="/home/${OPENCLAW_USER:?}"
    local config_dir="$openclaw_home/.openclaw"
    local config_file="$config_dir/openclaw.json"
    local gateway_choice="3"
    local gw_password=""

    if [ "$NON_INTERACTIVE" = false ]; then
        echo "Configure OpenClaw Gateway mode?"
        echo "  1) serve  - Tailnet-only access (recommended for personal use)"
        echo "  2) funnel - Public internet access (requires shared password)"
        echo "  3) off    - Skip Gateway integration (default)"
        echo ""
        read -rp "Choose mode [1/2/3] (default: 3): " gateway_choice
        gateway_choice=${gateway_choice:-3}
    fi

    case "$gateway_choice" in
        1)
            print_info "Configuring Gateway in 'serve' mode (Tailnet-only)..."
            mkdir -p "$config_dir"

            if [ -f "$config_file" ]; then
                cp "$config_file" "${config_file}.backup-$(date +%Y%m%d-%H%M%S)"
                print_info "Backed up existing openclaw.json"

                if grep -q '"gateway"' "$config_file" 2>/dev/null; then
                    print_warning "Existing gateway configuration found in openclaw.json"
                    print_warning "Please update manually. See: https://docs.openclaw.ai/gateway/tailscale"
                else
                    if command -v python3 &>/dev/null; then
                        OC_CONFIG="$config_file" python3 << 'PYMERGE'
import json, os
cf = os.environ["OC_CONFIG"]
try:
    with open(cf, "r") as f:
        config = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    config = {}
config["gateway"] = {"bind": "loopback", "tailscale": {"mode": "serve"}}
with open(cf, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYMERGE
                    else
                        print_warning "python3 not found - writing fresh config"
                        cat > "$config_file" << 'GWCONFIG'
{
  "gateway": {
    "bind": "loopback",
    "tailscale": {
      "mode": "serve"
    }
  }
}
GWCONFIG
                    fi
                    print_success "Gateway mode set to 'serve'"
                fi
            else
                cat > "$config_file" << 'GWCONFIG'
{
  "gateway": {
    "bind": "loopback",
    "tailscale": {
      "mode": "serve"
    }
  }
}
GWCONFIG
                print_success "Created openclaw.json with Gateway serve mode"
            fi

            chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "$config_file"
            chmod 600 "$config_file"
            chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "$config_dir"
            ;;
        2)
            print_info "Configuring Gateway in 'funnel' mode (public internet)..."

            if [ "$NON_INTERACTIVE" = false ]; then
                read -rsp "Enter a shared password for Gateway access: " gw_password
                echo  # newline after silent read
                if [ -z "$gw_password" ]; then
                    print_warning "No password provided - funnel mode requires a password"
                    print_warning "Falling back to 'off' mode. Configure manually later."
                    print_info "See: https://docs.openclaw.ai/gateway/tailscale"
                    gateway_choice=3
                fi
            else
                print_warning "Funnel mode requires a password - skipping in non-interactive mode"
                gateway_choice=3
            fi

            if [ "$gateway_choice" = "2" ]; then
                mkdir -p "$config_dir"

                if [ -f "$config_file" ]; then
                    cp "$config_file" "${config_file}.backup-$(date +%Y%m%d-%H%M%S)"
                    print_info "Backed up existing openclaw.json"

                    if grep -q '"gateway"' "$config_file" 2>/dev/null; then
                        print_warning "Existing gateway configuration found in openclaw.json"
                        print_warning "Please update manually. See: https://docs.openclaw.ai/gateway/tailscale"
                    else
                        if command -v python3 &>/dev/null; then
                            OC_CONFIG="$config_file" GW_PASSWORD="$gw_password" python3 << 'PYMERGE2'
import json, os
cf = os.environ["OC_CONFIG"]
password = os.environ.get("GW_PASSWORD", "")
try:
    with open(cf, "r") as f:
        config = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    config = {}
config["gateway"] = {
    "bind": "loopback",
    "tailscale": {"mode": "funnel"},
    "auth": {"mode": "password", "password": password}
}
with open(cf, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYMERGE2
                        else
                            print_warning "python3 not found - writing fresh config"
                            cat > "$config_file" << GWFUNNEL
{
  "gateway": {
    "bind": "loopback",
    "tailscale": {
      "mode": "funnel"
    },
    "auth": {
      "mode": "password",
      "password": "$gw_password"
    }
  }
}
GWFUNNEL
                        fi
                        print_success "Gateway mode set to 'funnel' with password auth"
                    fi
                else
                    if command -v python3 &>/dev/null; then
                        OC_CONFIG="$config_file" GW_PASSWORD="$gw_password" python3 << 'PYMERGE3'
import json, os
cf = os.environ["OC_CONFIG"]
password = os.environ.get("GW_PASSWORD", "")
config = {
    "gateway": {
        "bind": "loopback",
        "tailscale": {"mode": "funnel"},
        "auth": {"mode": "password", "password": password}
    }
}
with open(cf, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYMERGE3
                    else
                        cat > "$config_file" << GWFUNNEL2
{
  "gateway": {
    "bind": "loopback",
    "tailscale": {
      "mode": "funnel"
    },
    "auth": {
      "mode": "password",
      "password": "$gw_password"
    }
  }
}
GWFUNNEL2
                    fi
                    print_success "Created openclaw.json with Gateway funnel mode"
                fi

                chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "$config_file"
                chmod 600 "$config_file"
                chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "$config_dir"
            fi
            ;;
        3|*)
            print_skip "Skipping Gateway Tailscale integration"
            print_info "Configure later by editing ~/.openclaw/openclaw.json"
            print_info "See: https://docs.openclaw.ai/gateway/tailscale"
            ;;
    esac

    echo ""
    print_info "Tailscale Gateway Notes:"
    echo "  - Enable MagicDNS: Tailscale admin console > DNS > Enable MagicDNS"
    echo "  - Enable HTTPS:    Tailscale admin console > DNS > Enable HTTPS Certificates"
    echo "  - Full docs:       https://docs.openclaw.ai/gateway/tailscale"

    echo ""
    print_success "Tailscale setup complete!"
    if [ -n "$tailscale_ip" ]; then
        print_info "Access this Pi from other devices:"
        echo "  SSH: ssh $OPENCLAW_USER@$tailscale_ip"
        echo "  SSH: ssh $OPENCLAW_USER@$tailscale_hostname"
    fi
}

###############################################################################
# OpenClaw Installation
###############################################################################

install_openclaw() {
    print_header "OpenClaw Installation"

    print_info "This will install OpenClaw as the '$OPENCLAW_USER' user"
    print_info "Steps:"
    echo "  1. Install Node.js 22+ via nvm"
    echo "  2. Install Claude Code CLI (requires API key)"
    echo "  3. Clone and build OpenClaw"
    echo "  4. Run security audit and apply fixes"
    echo ""

    if ! confirm "Install OpenClaw now?"; then
        print_skip "Skipping OpenClaw installation"
        print_info "Install later as user '$OPENCLAW_USER':"
        echo "  su - $OPENCLAW_USER"
        echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        echo "  nvm install 22"
        echo "  git clone https://github.com/openclaw/openclaw.git"
        echo "  cd openclaw && npm install && npm run build && npm link"
        return
    fi

    # Verify openclaw user exists
    if ! user_exists "$OPENCLAW_USER"; then
        print_error "User '$OPENCLAW_USER' does not exist"
        print_error "This should have been created in Step 4"
        return 1
    fi

    print_info "Installing as user: $OPENCLAW_USER"

    # Install Node.js via nvm
    print_info "Installing Node.js 22 via nvm..."

    if su - "$OPENCLAW_USER" << 'NODEINSTALL'
# Install nvm
if [ ! -d ~/.nvm ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 22
nvm install 22
nvm use 22
nvm alias default 22

echo "Node.js installed:"
node --version
npm --version
NODEINSTALL
    then
        print_success "Node.js installed"
    else
        print_error "Node.js installation failed"
        return 1
    fi

    # Install Claude Code CLI
    print_info "Claude Code CLI installation..."
    print_warning "You will need an Anthropic API key"

    if [ "$NON_INTERACTIVE" = false ]; then
        read -rsp "Enter Anthropic API key for Claude Code (or press Enter to skip): " CLAUDE_API_KEY
        echo  # newline after silent input

        if [ -n "$CLAUDE_API_KEY" ]; then
            su - "$OPENCLAW_USER" << CLAUDEINSTALL
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

npm install -g @anthropic-ai/claude-code

# Set API key
echo "export ANTHROPIC_API_KEY=\"$CLAUDE_API_KEY\"" >> ~/.bashrc

echo "Claude Code CLI installed"
CLAUDEINSTALL

            print_success "Claude Code CLI installed and configured"
        else
            print_skip "Skipping Claude Code CLI installation"
        fi
    fi

    # Clone and install OpenClaw
    print_info "Cloning OpenClaw repository..."

    if su - "$OPENCLAW_USER" << 'OPENCLAWINSTALL'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

cd ~
if [ ! -d openclaw ]; then
    git clone https://github.com/openclaw/openclaw.git
fi

cd openclaw
npm install
npm run build
npm link

echo "OpenClaw installed"
openclaw --version
OPENCLAWINSTALL
    then
        print_success "OpenClaw installed successfully"
    else
        print_error "OpenClaw installation failed"
        return 1
    fi

    # Run security audit
    print_info "Running OpenClaw security audit..."

    su - "$OPENCLAW_USER" << 'SECURITYAUDIT'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "Running security audit..."
openclaw security audit --deep

echo "Applying security fixes..."
openclaw security audit --fix

echo "Security audit complete"
SECURITYAUDIT

    print_success "OpenClaw security audit completed"

    # Set proper permissions
    local openclaw_home="/home/${OPENCLAW_USER:?}"
    if [ -d "$openclaw_home/.openclaw" ]; then
        chmod 700 "$openclaw_home/.openclaw"

        if [ -f "$openclaw_home/.openclaw/openclaw.json" ]; then
            chmod 600 "$openclaw_home/.openclaw/openclaw.json"
        fi

        if [ -d "$openclaw_home/.openclaw/credentials" ]; then
            chmod 700 "$openclaw_home/.openclaw/credentials"
            find "$openclaw_home/.openclaw/credentials" -type f -exec chmod 600 {} \;
        fi

        print_success "OpenClaw permissions secured"
    fi

    # Update auditd rules now that OpenClaw is installed
    update_auditd_for_openclaw

    print_success "OpenClaw installation complete!"
    print_info "Test with: su - $OPENCLAW_USER -c 'openclaw --version'"

    echo ""
    print_info "Developer Tools & API Proxy:"
    echo "  See the project README for recommendations on AI coding tools"
    echo "  (Claude Code, Codex, Gemini CLI) and CLIProxyAPI for sharing"
    echo "  OAuth-based API access with OpenClaw in a controlled manner."
    echo "  https://github.com/router-for-me/CLIProxyAPI"
}

###############################################################################
# Enhanced Documentation
###############################################################################

create_documentation() {
    print_header "Creating Documentation"

    local openclaw_home="/home/${OPENCLAW_USER:?}"

    cat > "$openclaw_home/SECURITY_README.txt" << EOF
═══════════════════════════════════════════════════════════════
  OpenClaw Raspberry Pi - Security Hardening Documentation
  Script Version: $SCRIPT_VERSION
  Installed: $(date)
═══════════════════════════════════════════════════════════════

This system has been hardened with comprehensive security measures.

SECURITY COMPONENTS
  - Automatic security updates (Raspberry Pi + Debian)
  - UFW firewall (deny-by-default)
  - fail2ban intrusion prevention
  - SSH hardening (no root, modern crypto)
  - AIDE file integrity monitoring
  - rkhunter/chkrootkit rootkit detection
  - auditd system auditing
  - Lynis security auditing
  - Automated daily scans

$(if command -v tailscale &> /dev/null; then
echo "TAILSCALE NETWORK
  - Secure remote access via WireGuard VPN
  - Zero-trust network overlay
  - Access from anywhere securely"
fi)

$(if command -v openclaw &> /dev/null; then
echo "OPENCLAW INSTALLED
  - Security audit applied
  - Sandbox mode configured
  - Tool policies locked down"
fi)

═══════════════════════════════════════════════════════════════
IMPORTANT COMMANDS
═══════════════════════════════════════════════════════════════

Manual Security Scan:
  sudo /usr/local/bin/security-scan.sh

View Scan Results:
  sudo tail -f /var/log/security-scan.log

Initialize AIDE (if skipped):
  sudo aideinit
  sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

Update AIDE After Changes:
  sudo /usr/local/bin/update-aide-db.sh

Run Lynis Audit:
  sudo lynis audit system

Check Audit Logs:
  sudo ausearch -k openclaw_config
  sudo ausearch -k openclaw_exec

$(if command -v tailscale &> /dev/null; then
echo "Tailscale Commands:
  tailscale status          # Check connection status
  tailscale ip              # Show your Tailscale IPs
  tailscale up              # Connect to network
  tailscale down            # Disconnect"
fi)

$(if command -v openclaw &> /dev/null; then
echo "OpenClaw Commands:
  openclaw security audit --deep    # Deep security scan
  openclaw security audit --fix     # Apply security fixes
  openclaw agent --message 'test'   # Test basic functionality"
fi)

═══════════════════════════════════════════════════════════════
FIRST-TIME SETUP
═══════════════════════════════════════════════════════════════

1. Change passwords:
   sudo passwd rpi-admin
   sudo passwd openclaw

2. Set up SSH keys:
   ssh-copy-id user@raspberry-pi

3. If AIDE was skipped, initialize:
   sudo aideinit
   sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

$(if ! command -v openclaw &> /dev/null; then
echo "4. Install OpenClaw (if not installed):
   Re-run hardening script and choose OpenClaw installation
   OR install manually as openclaw user"
fi)

$(if command -v openclaw &> /dev/null; then
echo "4. Configure OpenClaw:
   su - openclaw
   # Set API keys in environment variables
   echo 'export OPENROUTER_API_KEY=\"your-key\"' >> ~/.bashrc
   echo 'export ANTHROPIC_API_KEY=\"your-key\"' >> ~/.bashrc"
fi)

═══════════════════════════════════════════════════════════════
MAINTENANCE
═══════════════════════════════════════════════════════════════

Daily (Automated):
  - Security scans at 2 AM
  - Security updates

Weekly (Automated):
  - Rootkit database updates (Sundays)

Monthly:
  - Run: sudo lynis audit system
  - Review scan logs

After System Changes:
  - Update AIDE: sudo /usr/local/bin/update-aide-db.sh
  - Update rkhunter: sudo rkhunter --propupd

═══════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════

AIDE Skipped During Setup:
  - Initialize: sudo aideinit
  - Activate: sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

AIDE False Positives:
  - Verify changes are legitimate
  - Update: sudo /usr/local/bin/update-aide-db.sh

Locked Out:
  - Use console access or Raspberry Pi Connect
  - Check firewall: sudo ufw status

$(if command -v tailscale &> /dev/null; then
echo "Tailscale Issues:
  - Check status: tailscale status
  - Reconnect: tailscale up
  - View logs: journalctl -u tailscaled"
fi)

═══════════════════════════════════════════════════════════════
RESOURCES
═══════════════════════════════════════════════════════════════

OpenClaw: https://github.com/openclaw/openclaw
This Script: https://github.com/KHAEntertainment/openclaw-pi
Tailscale: https://tailscale.com/kb

Hardening Version: $SCRIPT_VERSION
Installation Date: $(date)
Installation Log: $LOGFILE

═══════════════════════════════════════════════════════════════
EOF

    chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "$openclaw_home/SECURITY_README.txt" 2>/dev/null || true
    print_success "Documentation created at $openclaw_home/SECURITY_README.txt"
}

###############################################################################
# Initial Security Scan
###############################################################################

run_initial_scan() {
    print_header "Initial Security Scan"

    if [ ! -x /usr/local/bin/security-scan.sh ]; then
        print_warning "Security scan script not found - skipping initial scan"
        return
    fi

    run_with_progress \
        "Running initial security scan to establish baseline" \
        "/usr/local/bin/security-scan.sh" \
        "" \
        "Run manually: sudo /usr/local/bin/security-scan.sh" \
        "5-15 minutes" \
    || print_info "Initial scan skipped - run later with: sudo /usr/local/bin/security-scan.sh"
}

###############################################################################
# Enhanced Summary
###############################################################################

display_summary() {
    print_header "Installation Complete!"

    echo -e "${GREEN}"
    cat << 'EOF'
    +-----------------------------------------------------------+
    |                                                           |
    |   OpenClaw Raspberry Pi Security Hardening Complete!      |
    |                Version 2.3                                |
    |                                                           |
    +-----------------------------------------------------------+
EOF
    echo -e "${NC}"

    echo "Security Components:"
    echo "  - System hardened and secured"
    echo "  - UFW firewall active"
    echo "  - fail2ban protecting SSH"
    echo "  - SSH hardened"
    if [ -f /var/lib/aide/aide.db ]; then
        echo "  - AIDE initialized"
    else
        echo "  - AIDE pending (run: sudo aideinit)"
    fi
    echo "  - Automated daily scans"

    if command -v tailscale &> /dev/null; then
        echo ""
        echo "Tailscale:"
        local tailscale_ip
        tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "")
        if [ -n "$tailscale_ip" ]; then
            echo "  - IP: $tailscale_ip"
            echo "  - Hostname: rpi-openclaw"
            echo "  - Status: Connected"
        fi
    fi

    if command -v openclaw &> /dev/null; then
        echo ""
        echo "OpenClaw:"
        local openclaw_version
        openclaw_version=$(su - "$OPENCLAW_USER" -c "source ~/.nvm/nvm.sh && openclaw --version" 2>/dev/null || echo "unknown")
        echo "  - Version: $openclaw_version"
        echo "  - Security audit applied"
        echo "  - Ready for use"
    fi

    echo ""
    echo "Key Files:"
    echo "  - Security scans: /var/log/security-scan.log"
    echo "  - Installation log: $LOGFILE"
    echo "  - Documentation: /home/openclaw/SECURITY_README.txt"
    echo ""

    echo "Automated Tasks:"
    echo "  - Daily scans: 2:00 AM"
    echo "  - Weekly updates: Sundays 3:00 AM"
    echo ""

    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo "1. Review documentation:"
    echo "   cat /home/openclaw/SECURITY_README.txt"
    echo ""

    if [ ! -f /var/lib/aide/aide.db ]; then
        echo "2. Initialize AIDE (skipped earlier):"
        echo "   sudo aideinit"
        echo ""
    fi

    if ! command -v openclaw &> /dev/null; then
        echo "3. OpenClaw not installed - install with:"
        echo "   sudo $0  (re-run and choose OpenClaw installation)"
        echo ""
    fi

    if command -v tailscale &> /dev/null; then
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null || echo "")
        echo "4. Access via Tailscale:"
        echo "   ssh $OPENCLAW_USER@$ts_ip"
        echo "   ssh $OPENCLAW_USER@rpi-openclaw"
        echo ""
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Hardening script v$SCRIPT_VERSION${NC}"
    echo -e "${BLUE}  Log: $LOGFILE${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################

main() {
    clear

    print_header "OpenClaw Raspberry Pi - Complete Security Hardening v$SCRIPT_VERSION"

    cat << 'EOF'
This script performs comprehensive security hardening with:

NEW IN v2.3:
  - User session environment (DBUS/XDG) for Gateway
  - OpenClaw Gateway Tailscale integration (serve/funnel/off)
  - Developer tools & API proxy guidance
  - Version tracking and upgrade detection
  - Preserves custom configurations

Hardening Steps:
 1. System Updates
 2. Firewall (UFW)
 3. Intrusion Prevention (fail2ban)
 4. User Account Creation
 5. SSH Hardening
 6. Security Tools (AIDE, rkhunter, auditd, lynis)
 7. Attack Surface Minimization
 8. Logging & Monitoring
 9. File System Permissions
10. Automated Scanning
11. Tailscale Installation (optional)
12. OpenClaw Installation (optional)

EOF

    if [ "$NON_INTERACTIVE" = false ]; then
        if ! confirm "Continue with hardening?" "y"; then
            print_info "Hardening cancelled"
            exit 0
        fi
    fi

    # Pre-flight checks
    check_root
    check_os
    check_version
    check_disk_space

    # Main hardening sequence
    configure_system_updates
    configure_firewall
    configure_fail2ban
    configure_users
    configure_ssh
    install_security_tools
    configure_aide
    configure_rkhunter
    configure_auditd
    configure_lynis
    minimize_attack_surface
    configure_logging
    configure_file_permissions
    create_security_scan_script
    setup_cron_jobs

    # Optional components
    install_tailscale
    install_openclaw

    # Documentation and summary
    create_documentation
    save_version

    # Initial scan
    run_initial_scan

    # Summary
    display_summary

    print_success "Complete! Your OpenClaw Pi is ready."
}

# Run main
main "$@"
