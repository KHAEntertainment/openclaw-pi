# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
