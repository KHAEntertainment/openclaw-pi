# Security Reference

Detailed overview of what the hardening script installs, the security architecture, and the file system layout.

---

## Security Components

### System Hardening

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| `unattended-upgrades` | Automatic security updates | Daily, auto-reboot at 3 AM if needed |
| `ufw` | Firewall | Deny incoming by default, allow SSH |
| `fail2ban` | Intrusion prevention | 3 failed SSH attempts = 1 hour ban |
| SSH hardening | Secure remote access | No root login, modern crypto only |

### Security Monitoring

| Tool | Function | Schedule |
|------|----------|----------|
| `AIDE` | File integrity monitoring | Daily checks at 2 AM |
| `rkhunter` | Rootkit detection | Weekly updates, daily scans |
| `chkrootkit` | Additional rootkit scanning | Daily scans |
| `auditd` | System call auditing | Real-time monitoring |
| `Lynis` | Security auditing | On-demand |

### User Accounts

- **`openclaw`** user created with no sudo access
- Home directory permissions: `700` (owner-only)
- Follows principle of least privilege

### File Permissions

| Path | Permissions | Purpose |
|------|-------------|---------|
| `/home/openclaw/` | `700` | Owner-only access |
| `~/.openclaw/openclaw.json` | `600` | Config file (owner read/write only) |
| `~/.openclaw/credentials/` | `700` with `600` files | API keys |
| `/tmp` | Mounted with `noexec` | Prevents script execution from /tmp |

### Optional Components

| Component | Purpose |
|-----------|---------|
| Tailscale | Encrypted remote access (WireGuard VPN) |
| Homebrew | Package manager for OpenClaw plugins |
| Node.js 22+ | Runtime for OpenClaw |
| Claude Code CLI | AI coding assistant |
| OpenClaw | AI agent framework |

---

## Architecture

### Security Layers

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

> **Lightweight Architecture:** The Pi doesn't run AI models locally. OpenClaw acts as a Gateway to cloud AI services (Claude, GPT, etc.). All heavy processing happens in the cloud — that's why OpenClaw runs well on minimal hardware.

### Network Flow

```
User Device
    │
    ├─[Option A]─→ Raspberry Pi Connect (HTTPS)
    │                    │
    │                    ▼
    │              Pi Terminal
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

## File System Layout

```
/home/openclaw/
├── .openclaw/
│   ├── openclaw.json          (600) - Config file
│   ├── agents/                (700) - Agent configs
│   ├── credentials/           (700) - API keys
│   ├── extensions/            (755) - Plugins
│   ├── sessions/              (755) - Session data
│   └── logs/                  (755) - Log file
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

---

## Security Standards

This script is informed by:
- Debian security best practices
- CIS Benchmarks
- NIST Cybersecurity Framework
- Community security hardening guides

---

Back to [README](../README.md)
