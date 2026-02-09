# OpenClaw Raspberry Pi - Hardened Security Installation

> **Production-ready security hardening for isolated OpenClaw deployments on Raspberry Pi**

Comprehensive, automated security hardening script for running [OpenClaw](https://github.com/openclaw/openclaw) on Raspberry Pi in a secure, isolated environment. Perfect for headless AI infrastructure, personal servers, or shareable community images.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.4-blue.svg)]()
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4%2F5-red.svg)]()

---

## 🎯 Features

**Complete Security Stack (Open Source)**
- ✅ **System Hardening**: Automatic security updates, minimal attack surface
- ✅ **Network Security**: UFW firewall, fail2ban intrusion prevention
- ✅ **Access Control**: SSH hardening, key-only authentication, modern cryptography
- ✅ **Monitoring**: AIDE file integrity, rkhunter/chkrootkit rootkit detection
- ✅ **Auditing**: auditd system monitoring, Lynis security audits
- ✅ **Automation**: Daily security scans, automated reporting

**Enhanced User Experience (v2.4)**
- ✅ **Progress Indicators**: Real-time feedback for long-running operations
- ✅ **Skip Options**: Run time-consuming tasks later if needed
- ✅ **Version Tracking**: Detects previous installations, preserves custom configs
- ✅ **Tailscale Integration**: Secure remote access via encrypted WireGuard VPN
- ✅ **OpenClaw Installer**: Automated Node.js + OpenClaw deployment
- ✅ **Homebrew (Linuxbrew)**: Automatic installation for OpenClaw plugin support

**Production Ready**
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Smart Detection**: Works on fresh or existing systems
- ✅ **Non-Interactive Mode**: Perfect for automated deployments
- ✅ **Community Shareable**: No commercial dependencies, fully open source

---

## 📋 Prerequisites

### **Hardware Requirements**

**Recommended Devices (Best Experience):**
- **Raspberry Pi 5** - Latest hardware, best performance
- **Raspberry Pi 4 Model B (2GB+)** - Excellent price/performance
- **Raspberry Pi 4/5 Compute Module** - Industrial and embedded applications

**Minimum Requirements:**
- 1GB RAM, 1 CPU core, 500MB disk (per OpenClaw docs)
- Recommended: Raspberry Pi 4 (2GB+) or Pi 5
- Storage: 16GB+ SD card or **USB SSD** (strongly recommended for performance and reliability)
- Power supply: Official Raspberry Pi power adapter
- Network: Ethernet recommended for initial setup

> **⚠️ Pi Zero 2 W is not recommended** — insufficient resources for reliable operation.

> **💡 Performance Tips:**
> - Use a **USB SSD** instead of SD card for significantly better I/O performance
> - For systems with **2GB or less RAM**, add swap space (the script does not configure this automatically)

**Why These Models?**
- 64-bit ARM (aarch64) architecture required — Node.js 22 and modern tools need 64-bit OS
- OpenClaw acts as a lightweight Gateway to cloud AI models — the Pi doesn't run models locally, so minimal resources are needed
- Good I/O performance for AIDE file integrity monitoring
- Active community support

### **Operating System**

**Recommended: Raspberry Pi OS Lite (64-bit)**

```bash
# Use Raspberry Pi Imager to install:
# OS: Raspberry Pi OS Lite (64-bit)
# Headless — no desktop environment needed
```

**Why Lite (64-bit)?**
- OpenClaw runs headless — no GUI/desktop required
- Smaller footprint, less attack surface, fewer unnecessary services
- All dependencies are CLI-based (`git`, `curl`, `build-essential`, Node.js 22+)
- 64-bit (aarch64) is mandatory — Node.js 22 requires it

> **Note:** The Desktop version also works but wastes resources on a GUI that OpenClaw doesn't use. If you need browser automation features, you can install Chromium on either version: `sudo apt install chromium-browser`

### **Network Isolation**

**⚠️ CRITICAL: Run on isolated network**

OpenClaw executes code and interacts with external services. For security, deploy on:

**Option A: Guest Network (Easiest)**
1. Configure guest network on your router
2. Isolate from main LAN (no device-to-device communication)
3. Allow internet access only

**Option B: VLAN (Recommended for Advanced Users)**
1. Create dedicated VLAN for OpenClaw infrastructure
2. Configure firewall rules between VLANs
3. Allow only necessary traffic (SSH, OpenClaw Gateway port)

**Not sure how? Ask Claude or ChatGPT:**
```
Prompt: "How do I set up a guest network on [YOUR ROUTER MODEL] 
to isolate a Raspberry Pi from my main network?"
```

### **Remote Access Setup**

**Raspberry Pi Connect (Recommended for Initial Setup)**

Configure during OS installation with Raspberry Pi Imager:

1. Open **Raspberry Pi Imager**
2. Choose OS: **Raspberry Pi OS Lite (64-bit)**
3. Click **⚙️ Settings** (gear icon)
4. Enable **"Enable Raspberry Pi Connect"**
5. Set hostname: `rpi-openclaw`
6. Configure WiFi if needed
7. Set username and password
8. Write to SD card (or USB SSD)

**Benefits:**
- Secure remote access from any device
- No port forwarding required
- Works through firewalls and NAT
- Browser-based or terminal-only access

**After Installation:**
- Access via [https://connect.raspberrypi.com](https://connect.raspberrypi.com)
- Use terminal-only mode (much faster than desktop)

---

## 🚀 Quick Start

### **One-Line Installer**

```bash
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/install.sh | sudo bash
```

**What This Does:**
1. Downloads the latest hardening script
2. Runs comprehensive security hardening
3. Optionally installs Tailscale for better remote access
4. Optionally installs and configures OpenClaw
5. Sets up automated monitoring and scanning

**Installation Time:** 15-45 minutes (depending on options chosen)

### **Manual Installation**

```bash
# 1. Download the script
wget https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/harden-openclaw-pi.sh

# Or use curl
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/harden-openclaw-pi.sh -o harden-openclaw-pi.sh

# 2. Make executable
chmod +x harden-openclaw-pi.sh

# 3. Run (interactive mode)
sudo ./harden-openclaw-pi.sh

# 4. Or non-interactive mode (uses defaults)
sudo ./harden-openclaw-pi.sh --non-interactive

# 5. Or skip long operations (for testing)
sudo ./harden-openclaw-pi.sh --skip-long-ops
```

---

## 📦 What Gets Installed

### **System Hardening**
| Component | Purpose | Configuration |
|-----------|---------|---------------|
| `unattended-upgrades` | Automatic security updates | Daily, auto-reboot at 3 AM if needed |
| `ufw` | Firewall | Deny incoming by default, allow SSH |
| `fail2ban` | Intrusion prevention | 3 failed SSH attempts = 1 hour ban |
| SSH hardening | Secure remote access | No root login, modern crypto only |

### **Security Monitoring**
| Tool | Function | Schedule |
|------|----------|----------|
| `AIDE` | File integrity monitoring | Daily checks at 2 AM |
| `rkhunter` | Rootkit detection | Weekly updates, daily scans |
| `chkrootkit` | Additional rootkit scanning | Daily scans |
| `auditd` | System call auditing | Real-time monitoring |
| `Lynis` | Security auditing | On-demand |

### **User Accounts**
- **`openclaw`** user created (no sudo access)
- Home directory permissions: `700`
- Follows principle of least privilege

### **File Permissions**
- `/home/openclaw/`: `700` (owner-only access)
- `~/.openclaw/openclaw.json`: `600` (config file)
- `~/.openclaw/credentials/`: `700` with `600` files
- `/tmp`: Mounted with `noexec` (prevents script execution)

### **Automated Tasks**
- **Daily 2:00 AM**: Comprehensive security scan
- **Sunday 3:00 AM**: Rootkit database updates
- **Ongoing**: Automatic security update installation

### **Optional Components**
| Component | Purpose | When |
|-----------|---------|------|
| Tailscale | Encrypted remote access | Optional during install |
| Node.js 22+ | Runtime for OpenClaw | Optional during install |
| Claude Code CLI | Coding assistance | Optional during install |
| OpenClaw | AI agent framework | Optional during install |

---

## ⚙️ Configuration

### **Environment Variables**

**Set API keys securely** (never in config files):

```bash
# As openclaw user
su - openclaw

# Add to ~/.bashrc
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
echo 'export OPENROUTER_API_KEY="sk-or-..."' >> ~/.bashrc

# Reload
source ~/.bashrc
```

### **OpenClaw Configuration**

Edit `~/.openclaw/openclaw.json`:

```json
{
  "agents": [
    {
      "id": "main-assistant",
      "name": "Main Assistant",
      "model": {
        "provider": "openrouter",
        "model": "anthropic/claude-opus-4-5",
        "apiKey": "env:OPENROUTER_API_KEY"
      },
      "sandbox": {
        "mode": "all"
      },
      "tools": {
        "groupPolicy": "allowlist",
        "allow": ["file_read", "file_write"],
        "exec": {
          "host": "sandbox",
          "approval": "required"
        }
      }
    }
  ]
}
```

**Critical Settings:**
- `sandbox.mode: "all"` - Isolate tool execution
- `groupPolicy: "allowlist"` - Deny by default
- `exec.host: "sandbox"` - Never use "gateway"
- `exec.approval: "required"` - Require confirmation

### **Firewall Rules**

```bash
# View current rules
sudo ufw status verbose

# Allow additional ports (e.g., OpenClaw Gateway)
sudo ufw allow 3030/tcp comment 'OpenClaw Gateway'

# Reload
sudo ufw reload
```

### **Tailscale Setup**

If installed during setup:

```bash
# Check status
tailscale status

# Get your Tailscale IP
tailscale ip

# Set custom hostname
tailscale set --hostname my-openclaw-pi

# Connect from other devices
ssh openclaw@rpi-openclaw
ssh openclaw@100.x.y.z  # Tailscale IP
```

**OpenClaw Gateway Integration:**

OpenClaw has native Tailscale Gateway support with three modes:
- **serve** — Tailnet-only access with identity-based authentication (no passwords)
- **funnel** — Public internet access via Tailscale Funnel (shared password required)
- **off** — No Tailscale Gateway automation (default)

During installation, the script will offer to configure your preferred Gateway mode. For manual setup or more details, see the [OpenClaw Tailscale documentation](https://docs.openclaw.ai/gateway/tailscale).

**Prerequisites for serve/funnel modes:**
- MagicDNS enabled in your [Tailscale admin console](https://login.tailscale.com/admin/dns)
- HTTPS certificates enabled in DNS settings
- For funnel: Tailscale v1.38.3+ and funnel node attributes enabled

### **Developer Tools & API Proxy**

OpenClaw works alongside modern AI-powered coding tools. Consider installing these on your Pi or a connected machine:

| Tool | Description |
|------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Anthropic's CLI coding assistant |
| [OpenAI Codex CLI](https://github.com/openai/codex) | OpenAI's terminal coding agent |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Google's AI coding tool |

**Sharing API Access with CLIProxyAPI:**

If you use OAuth-based coding plans (e.g., Claude Pro/Max, ChatGPT Plus/Pro) and want to share that API access with your OpenClaw instance without managing raw API keys, consider [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI):

- **Multi-account load balancing** — Pool multiple OAuth sessions behind one endpoint
- **No direct API key management** — Uses your existing OAuth-based subscriptions
- **Unified API interface** — Compatible with OpenAI-format API calls
- **Controlled access** — Proxy manages rate limits and session rotation

```bash
# See full setup instructions at:
# https://github.com/router-for-me/CLIProxyAPI
```

> **Note:** CLIProxyAPI is a third-party community tool. Review its documentation and security implications before deploying in your environment.

### **Claude Code Session Persistence** *(Future OpenClaw Skill)*

Once OpenClaw is installed, a future skill will provide automatic session persistence
for Claude Code, keeping your AI sessions alive across SSH disconnects using
`loginctl enable-linger` and systemd user services. Until then, you can manually verify
lingering is active:

```bash
# Already configured by the hardening script:
loginctl enable-linger openclaw

# Verify:
loginctl show-user openclaw | grep Linger
# Linger=yes
```

> **Why this matters:** Without lingering enabled, user systemd services (including
> OpenClaw Gateway) terminate when the SSH session disconnects. The hardening script
> enables this automatically during user creation.

---

## 🔧 Common Tasks

### **Manual Security Scan**

```bash
# Run full scan
sudo /usr/local/bin/security-scan.sh

# View results
sudo tail -f /var/log/security-scan.log
```

### **Update AIDE Database**

After making legitimate system changes:

```bash
sudo /usr/local/bin/update-aide-db.sh
```

### **Run OpenClaw Security Audit**

```bash
# As openclaw user
su - openclaw

# Deep audit
openclaw security audit --deep

# Apply fixes
openclaw security audit --fix
```

### **Check Audit Logs**

```bash
# View OpenClaw config changes
sudo ausearch -k openclaw_config

# View command execution
sudo ausearch -k openclaw_exec

# Recent events
sudo ausearch -ts recent
```

### **Check System Status**

```bash
# Firewall
sudo ufw status

# fail2ban
sudo fail2ban-client status sshd

# AIDE database status
ls -lh /var/lib/aide/

# Automated scans
sudo crontab -l
```

---

## 🐛 Troubleshooting

### **AIDE Initialization Stuck**

**Symptom:** Script appears frozen during AIDE initialization

**Cause:** AIDE takes 10-30 minutes on Raspberry Pi

**Solution:**
```bash
# In another terminal, monitor progress
watch -n 5 ls -lh /var/lib/aide/aide.db.new

# Database grows from 0 to ~5-15 MB when complete
```

**Or skip and run later:**
```bash
# Skip during script run, then manually:
sudo aideinit
# Wait 10-30 minutes
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### **Locked Out of SSH**

**Prevention:**
- Set up SSH keys BEFORE disabling password auth
- Test SSH key login before confirming password auth disable

**Recovery:**
- Use Raspberry Pi Connect (browser or terminal)
- Or physical access (keyboard + monitor)
- Check firewall: `sudo ufw status`
- Ensure SSH allowed: `sudo ufw allow 22/tcp`

### **AIDE False Positives**

**Symptom:** AIDE reports changes after legitimate updates

**Solution:**
```bash
# Update baseline after legitimate changes
sudo /usr/local/bin/update-aide-db.sh

# Or manually
sudo aide --update
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### **Tailscale Connection Issues**

```bash
# Check status
tailscale status

# Reconnect
tailscale up

# View logs
journalctl -u tailscaled -f

# Restart service
sudo systemctl restart tailscaled
```

### **OpenClaw Installation Failed**

```bash
# Check Node.js
su - openclaw
source ~/.nvm/nvm.sh
node --version  # Should be v22.x.x

# Reinstall Node.js
nvm install 22
nvm use 22

# Try OpenClaw install again
cd ~/openclaw
npm install
npm run build
npm link
```

---

## 🏗️ Architecture

### **Security Layers**

```
┌─────────────────────────────────────────────────────────┐
│                    Internet                             │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────▼──────────┐
         │   Router/Firewall    │
         │   Guest Network      │
         │   or VLAN            │
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │   UFW Firewall       │ ← Deny incoming by default
         │   fail2ban           │ ← Block brute force
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │   SSH (hardened)     │ ← No root, keys only
         │   Tailscale          │ ← Optional encrypted overlay
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │   openclaw user      │ ← No sudo, least privilege
         │   (sandbox mode)     │ ← Tool execution isolated
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │   OpenClaw           │ ← Agent framework
         │   (tools isolated)   │ ← Allowlist policies
         └──────────────────────┘
```

> **Lightweight Architecture:** The Raspberry Pi doesn't run AI models locally. OpenClaw acts as a Gateway that connects to cloud-based AI services (Claude, GPT, etc.) over the internet. All heavy AI processing happens in the cloud, which is why OpenClaw can run effectively on minimal hardware with just Node.js and basic tools.

### **File System Layout**

```
/home/openclaw/
├── .openclaw/
│   ├── openclaw.json          (600) - Config file
│   ├── agents/                (700) - Agent configs
│   ├── credentials/           (700) - API keys
│   ├── extensions/            (755) - Plugins
│   ├── sessions/              (755) - Session data
│   └── logs/                  (755) - Log files
├── openclaw/                  (755) - Git repo
├── .nvm/                      (755) - Node.js versions
└── SECURITY_README.txt        (644) - Documentation

/var/log/
├── security-scan.log                - Daily scan results
├── openclaw-hardening-*.log         - Installation logs
└── aide/                            - AIDE logs

/usr/local/bin/
├── security-scan.sh                 - Manual scan script
└── update-aide-db.sh                - AIDE update helper

/etc/
├── openclaw-hardening-version       - Version tracking
├── ufw/                             - Firewall rules
├── fail2ban/                        - Intrusion prevention
├── aide/                            - File integrity config
└── audit/rules.d/                   - Audit rules
```

### **Network Flow**

```
User Device
    │
    ├─[Option A]─→ Raspberry Pi Connect (HTTPS)
    │                    │
    │                    ▼
    │              Pi Terminal/Desktop
    │
    └─[Option B]─→ Tailscale (WireGuard encrypted)
                       │
                       ▼
                  SSH to Pi (port 22 on tailscale0)
                       │
                       ▼
                  openclaw user shell
                       │
                       ▼
                  OpenClaw agent (sandboxed)
                       │
                       ├─→ API calls (OpenRouter, Anthropic, etc.)
                       └─→ Local tool execution (in sandbox)
```

---

## 🖥️ Headless Optimization

If you installed **Raspberry Pi OS Desktop** instead of Lite, the hardening script will automatically detect the desktop environment and offer to optimize your system for headless operation.

You can also run the optimizer separately:

```bash
sudo ./optimize-headless.sh [--simulate] [--non-interactive]
```

**Options:**
| Flag | Description |
|------|-------------|
| `--simulate` | Preview changes without applying them |
| `--non-interactive` | Run without prompts (defaults to disable-only) |

**What it does:**
- **Disable only (reversible)**: Switches to multi-user target, keeps desktop installed
  - Re-enable anytime: `sudo systemctl set-default graphical.target && sudo reboot`
- **Remove entirely**: Purges desktop packages, office suite, games — saves ~1GB+ disk
  - Chromium is always preserved (required by OpenClaw for browser automation)

**Phases:**
1. Safety & baseline recording
2. Desktop mode decision (disable vs remove)
3. Remove bloat packages (LibreOffice, games, media players)
4. Disable unnecessary services (display managers, colord, etc.)
5. Desktop plumbing removal (only in "remove" mode)
6. Housekeeping (autoremove, cache cleanup, journal vacuum)
7. Verification & before/after comparison

---

## 🗺️ Roadmap

### **Version 2.5 (Current)**
- [x] **Headless optimization**: Desktop-to-headless conversion utility (`optimize-headless.sh`)
- [x] **Automatic desktop detection**: Main script detects and offers cleanup
- [x] **Chromium safety gate**: Browser always preserved for OpenClaw automation
- [x] **Disable vs remove modes**: Reversible disable or full purge of desktop packages

### **Version 2.4**
- [x] **Homebrew (Linuxbrew)**: Automatic installation for OpenClaw plugin support
- [x] **User session environment**: DBUS/XDG_RUNTIME_DIR setup for OpenClaw Gateway service
- [x] **OpenClaw Gateway Tailscale integration**: Native serve/funnel/off mode configuration
- [x] **Developer tools guidance**: CLIProxyAPI and AI coding tool recommendations

### **Version 3.0 (Future)**
- [ ] **Multi-distro support**: Detect and adapt to Ubuntu, Debian, etc.
- [ ] **Docker deployment option**: Container-based installation
- [ ] **Backup/restore automation**: Easy system snapshots
- [ ] **Email notifications**: Alert on security scan failures
- [ ] **Full TUI installer**: Interactive ncurses-based interface using `dialog` or `whiptail`
- [ ] **Tmux integration**: Built-in terminal multiplexer support
- [ ] **Configuration profiles**: Quick-select security levels (minimal, standard, paranoid)
- [ ] **Plugin system**: Community-contributed hardening modules

### **VM Support (Lightweight Distros)**
Auto-detect and adapt installation for:
- [ ] Ubuntu Server (ARM64)
- [ ] Debian (ARM64)
- [ ] Alpine Linux (minimal footprint)
- [ ] Arch Linux ARM
- [ ] Fedora Server ARM

### **Community Features**
- [ ] Pre-built images: Download and flash ready-to-use images
- [ ] Image builder: Automated image creation pipeline
- [ ] Hardware profiles: Optimized configs for different Pi models
- [ ] Performance tuning: CPU governor, I/O scheduler optimization

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

**Areas for Contribution:**
- Additional security tools integration
- Support for more Linux distributions
- TUI/GUI improvements
- Documentation and tutorials
- Testing and bug reports

**How to Contribute:**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Why MIT?**
- ✅ Commercial use allowed
- ✅ Modification allowed
- ✅ Distribution allowed
- ✅ Private use allowed
- ✅ No warranty (use at your own risk)

---

## 🙏 Acknowledgments

**Built on the shoulders of giants:**
- [OpenClaw](https://github.com/openclaw/openclaw) - AI agent framework
- [AIDE](https://aide.github.io/) - File integrity monitoring
- [rkhunter](http://rkhunter.sourceforge.net/) - Rootkit detection
- [Lynis](https://cisofy.com/lynis/) - Security auditing
- [Tailscale](https://tailscale.com/) - Secure networking
- [Raspberry Pi Foundation](https://www.raspberrypi.org/) - Amazing hardware

**Inspired by:**
- Debian security best practices
- CIS Benchmarks
- NIST Cybersecurity Framework
- Community security hardening guides

---

## 📞 Support

**Issues and Questions:**
- GitHub Issues: [Report a bug or request a feature](https://github.com/KHAEntertainment/openclaw-pi/issues)
- Discussions: [Ask questions and share tips](https://github.com/KHAEntertainment/openclaw-pi/discussions)

**Security Vulnerabilities:**
- **DO NOT** open public issues for security vulnerabilities
- Use [GitHub's private vulnerability reporting](https://github.com/KHAEntertainment/openclaw-pi/security/advisories/new)
- See [SECURITY.md](SECURITY.md) for details

---

## ⚠️ Disclaimer

**Use at your own risk.** This script modifies critical system security settings. While thoroughly tested, no security solution is perfect.

**Recommendations:**
- ✅ Test on a non-production Pi first
- ✅ Keep backups of important data
- ✅ Review the script before running
- ✅ Understand what each component does
- ✅ Monitor logs regularly
- ✅ Keep the system updated

**Not suitable for:**
- ❌ Production systems without testing
- ❌ Systems with existing security configurations (without review)
- ❌ Environments where you can't recover from lockout

---

## 📊 Statistics

| Metric | Value |
|--------|-------|
| Script Version | 2.5 |
| Lines of Code | ~2960 |
| Security Components | 10+ |
| Supported Pi Models | 4, 5, CM4 |
| Installation Time | 15-45 min |
| Tested Environments | Raspberry Pi OS 64-bit (Lite recommended) |
| License | MIT |

---

**Made with ❤️ for the OpenClaw community**

*Secure your AI infrastructure. Deploy with confidence.*

[⬆ Back to top](#openclaw-raspberry-pi---hardened-security-installation)
