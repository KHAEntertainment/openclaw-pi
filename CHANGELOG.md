# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.5.0] - 2025-02-08

### Added
- Headless optimization helper script (`optimize-headless.sh`)
- Desktop environment auto-detection in main hardening script
- Disable-only (reversible) and full-remove desktop modes
- Simulate mode (`--simulate`) for previewing headless changes
- Chromium safety gate (never removed, needed by OpenClaw)
- Headless Optimization section in README
- Claude Code Linger Monitor reference in README

### Changed
- `install.sh` now downloads `optimize-headless.sh` alongside main script
- CI workflow validates new script syntax
- Roadmap updated for v2.5 features

## [2.4.0] - 2025-02-07

### Added
- Homebrew (Linuxbrew) installation inside OpenClaw installer
- Optional confirm prompt before Homebrew install
- Non-interactive Homebrew support via `NONINTERACTIVE=1` environment variable
- Brew PATH configuration in openclaw user's `.bashrc`
- Warning when Homebrew is declined (plugins may fail without it)

### Changed
- OpenClaw installation steps updated (5 steps, Homebrew first)
- Manual installation instructions now include Homebrew setup

## [2.3.0] - 2025-02-07

### Added
- User session environment setup (`XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`) for OpenClaw Gateway
- Persistent user systemd instance via `loginctl enable-linger`
- OpenClaw Gateway Tailscale integration with serve/funnel/off mode selection
- UFW outbound rule for Tailscale interface (`allow out on tailscale0`)
- Interactive Gateway mode configuration with automatic `openclaw.json` setup
- Developer Tools & API Proxy section in README (CLIProxyAPI, Claude Code, Codex, Gemini CLI)
- Post-install hint in OpenClaw installer pointing to developer tool docs

### Changed
- Tailscale installation function restructured: no longer early-returns when already installed
- Tailscale section now includes full Gateway integration workflow
- README Tailscale section updated with Gateway mode documentation
- README roadmap updated to reflect v2.3 features

### Fixed
- OpenClaw Gateway `systemctl --user` failures due to missing DBUS/XDG environment variables
- Missing UFW outbound rule for Tailscale interface (only inbound was configured)

## [2.2.0] - 2025-02-06

### Added
- Version detection and tracking (`/etc/openclaw-hardening-version`)
- Preserve custom fail2ban configurations (backup + prompt before overwrite)
- Detect modified helper scripts before overwriting (backup + prompt)
- Tailscale VPN installation and configuration (optional)
- OpenClaw automated installation with Node.js 22 via nvm (optional)
- Enhanced finalization workflow with post-install audit
- Signal trapping for clean interrupt handling (Ctrl+C)
- Disk space verification before installation (500MB minimum)
- Conditional auditd file watches (only when OpenClaw is installed)
- Post-OpenClaw-install auditd rule update
- Comprehensive security scan script (AIDE, rkhunter, chkrootkit, SSH logs, fail2ban, ports, SUID, permissions)
- AIDE database update helper script
- GitHub Actions CI with ShellCheck linting
- Community files: LICENSE, CONTRIBUTING.md, SECURITY.md, issue/PR templates
- One-liner installer wrapper (`install.sh`)

### Fixed
- API key input now uses silent read (`read -s`) to prevent screen exposure
- API key variable expansion in heredoc (single-quote to double-quote fix)
- `HOSTNAME` variable no longer shadows bash builtin (renamed to `tailscale_hostname`)
- rkhunter `WEB_CMD` uses unquoted value (quoted form breaks rkhunter)
- rkhunter `UPDATE_MIRRORS` set to 0 (disable unreliable online mirror updates)

### Changed
- Script renamed from `harden-openclaw-pi-v2.2.sh` to `harden-openclaw-pi.sh` for stable URLs
- Replaced all `apt` calls with `apt-get` for non-interactive compatibility
- All `read` calls now use `-r` flag for proper backslash handling
- Replaced `$?` exit code checks with direct `if command; then` patterns
- Summary display uses ASCII box drawing (portable across terminals)

## [2.1.0] - Internal

### Added
- Initial comprehensive security hardening
- System updates and unattended-upgrades
- UFW firewall configuration
- fail2ban intrusion prevention
- SSH hardening with modern cryptography
- AIDE file integrity monitoring
- rkhunter and chkrootkit rootkit detection
- auditd system call auditing
- Lynis security auditing
- Attack surface minimization
- Logging and monitoring configuration
- File permission hardening
- Automated cron-based security scanning
- Progress indicators for long-running operations
- Non-interactive and skip-long-ops modes
