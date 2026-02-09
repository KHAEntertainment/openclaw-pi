# OpenClaw Pi

> Secure your Raspberry Pi for [OpenClaw](https://github.com/openclaw/openclaw) in one command.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.5-blue.svg)]()
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4%2F5-red.svg)]()

---

## What is this?

A one-command security setup for running [OpenClaw](https://github.com/openclaw/openclaw) on a Raspberry Pi. It configures a firewall, intrusion detection, SSH hardening, file integrity monitoring, and more — then optionally installs Tailscale and OpenClaw for you.

**You get:** A locked-down, production-ready Pi that acts as a secure gateway to cloud AI services.

---

## Quick Start

### You need

- **Raspberry Pi 4 or 5** (2GB+ RAM recommended)
- **Raspberry Pi OS Lite (64-bit)** — [Download with Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- **Network connection** (Ethernet recommended for setup)
- **SSH access** to your Pi

> New to Raspberry Pi? See the full [Setup Guide](docs/SETUP.md) for step-by-step instructions.

### Install

**Recomended: Flash a new install of Raspberry Pi OS, and set it up on an isolated virtual network if possible.**

SSH into your Pi OR use Raspberry Pi Connect for isolated environments (recommended) then:

```bash
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/install.sh | sudo bash
```

That's it. The script walks you through everything interactively.

**Takes about 15-45 minutes.** It will:
1. Harden your system (firewall, fail2ban, SSH, file integrity monitoring)
2. Detect Desktop OS and offer to optimize for headless *(if applicable)*
3. Optionally install Tailscale for secure remote access
4. Optionally install OpenClaw with Node.js and Homebrew

### Already set up? Just want the headless optimizer?

If your Pi is already hardened and running Desktop OS, you can run just the cleanup utility:

```bash
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/optimize-headless.sh | sudo bash
```

Preview first with `--simulate`, or see the full [Headless Optimization guide](docs/HEADLESS.md).

### Other ways to run

```bash
# Download and run manually
wget https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/harden-openclaw-pi.sh
chmod +x harden-openclaw-pi.sh
sudo ./harden-openclaw-pi.sh

# Non-interactive mode (uses safe defaults)
sudo ./harden-openclaw-pi.sh --non-interactive

# Skip time-consuming operations (AIDE init, etc.)
sudo ./harden-openclaw-pi.sh --skip-long-ops
```

---

## What it does

| Layer | Tools | What it does |
|-------|-------|-------------|
| **Firewall** | UFW, fail2ban | Blocks unauthorized access, bans brute force attempts |
| **SSH** | OpenSSH hardened | Key-only auth, no root login, modern cryptography |
| **File Integrity** | AIDE | Detects unauthorized file changes (daily scans) |
| **Rootkit Detection** | rkhunter, chkrootkit | Scans for known rootkits and backdoors |
| **Auditing** | auditd, Lynis | System call monitoring, security benchmarking |
| **Updates** | unattended-upgrades | Automatic security patches |
| **User Isolation** | openclaw user | Dedicated user with no sudo, least-privilege |
| **Remote Access** | Tailscale *(optional)* | Encrypted WireGuard VPN overlay |

The script is **idempotent** — safe to run multiple times. It detects what's already configured and skips it.

---

## After installation

```bash
# Switch to the openclaw user
su - openclaw

# Set your API key
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc

# Run OpenClaw
openclaw
```

For full configuration (OpenClaw settings, firewall rules, Tailscale Gateway modes, developer tools), see the [Configuration Guide](docs/CONFIGURATION.md).

---

## Common commands

```bash
# Run a manual security scan
sudo /usr/local/bin/security-scan.sh

# Update file integrity database (after legitimate changes)
sudo /usr/local/bin/update-aide-db.sh

# Check firewall status
sudo ufw status

# Check fail2ban
sudo fail2ban-client status sshd
```

Having issues? See [Troubleshooting](docs/TROUBLESHOOTING.md).

---

## Documentation

| Guide | Description |
|-------|-------------|
| **[Setup Guide](docs/SETUP.md)** | Hardware requirements, OS installation, network isolation |
| **[Configuration](docs/CONFIGURATION.md)** | API keys, OpenClaw config, firewall rules, Tailscale, developer tools |
| **[Security Reference](docs/SECURITY-REFERENCE.md)** | Architecture, file layout, what gets installed, security layers |
| **[Headless Optimization](docs/HEADLESS.md)** | Convert Desktop OS to lean headless server |
| **[Troubleshooting](docs/TROUBLESHOOTING.md)** | Common issues and fixes |

---

## Roadmap

**v2.5 (Current)** — Headless optimization, desktop auto-detection, Chromium safety gate
**v2.4** — Homebrew, Tailscale Gateway integration, DBUS/XDG session fix
**v2.3** — Developer tools, CLIProxyAPI guidance
**v2.2** — Initial release with full security stack

**Coming:** Multi-distro support, Docker deployment, TUI installer, configuration profiles. See [CHANGELOG.md](CHANGELOG.md) for full version history.

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

Found a vulnerability? **Do not** open a public issue. Use [GitHub's private reporting](https://github.com/KHAEntertainment/openclaw-pi/security/advisories/new) or see [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE). Use at your own risk. Test on a non-production Pi first.

---

**Made with ❤️ for the OpenClaw community** · [Report an Issue](https://github.com/KHAEntertainment/openclaw-pi/issues) · [Back to top](#openclaw-pi)
