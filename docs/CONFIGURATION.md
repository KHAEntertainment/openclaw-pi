# Configuration Guide

How to configure OpenClaw, API keys, firewall rules, Tailscale, and developer tools after installation.

---

## API Keys

Set API keys as environment variables (never in config files):

```bash
# Switch to the openclaw user
su - openclaw

# Add your keys to .bashrc
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
echo 'export OPENROUTER_API_KEY="sk-or-..."' >> ~/.bashrc

# Reload
source ~/.bashrc
```

---

## OpenClaw Configuration

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

### Critical security settings

| Setting | Value | Why |
|---------|-------|-----|
| `sandbox.mode` | `"all"` | Isolates all tool execution |
| `groupPolicy` | `"allowlist"` | Deny by default, allow specific tools |
| `exec.host` | `"sandbox"` | Never use `"gateway"` — runs code in isolation |
| `exec.approval` | `"required"` | Requires confirmation before executing |

---

## Firewall Rules

```bash
# View current rules
sudo ufw status verbose

# Allow additional ports (e.g., OpenClaw Gateway)
sudo ufw allow 3030/tcp comment 'OpenClaw Gateway'

# Reload
sudo ufw reload
```

The script configures UFW with:
- Default: deny incoming, allow outgoing
- SSH (port 22) allowed
- Tailscale interface allowed (if installed)

---

## Tailscale

### Basic commands

```bash
# Check connection status
tailscale status

# Get your Tailscale IP
tailscale ip

# Set a custom hostname
tailscale set --hostname my-openclaw-pi

# Connect from other devices
ssh openclaw@rpi-openclaw       # By hostname
ssh openclaw@100.x.y.z          # By IP
```

### OpenClaw Gateway Integration

OpenClaw has native Tailscale Gateway support with three modes:

| Mode | Access | Authentication |
|------|--------|---------------|
| **serve** | Tailnet only (your devices) | Identity-based, no passwords |
| **funnel** | Public internet | Shared password required |
| **off** | No Tailscale Gateway | Default |

The hardening script offers to configure this during installation. For manual setup or details, see the [OpenClaw Tailscale docs](https://docs.openclaw.ai/gateway/tailscale).

**Prerequisites for serve/funnel:**
- MagicDNS enabled in your [Tailscale admin console](https://login.tailscale.com/admin/dns)
- HTTPS certificates enabled in DNS settings
- For funnel: Tailscale v1.38.3+ and funnel node attributes enabled

---

## Developer Tools

OpenClaw works alongside AI coding tools. Consider installing:

| Tool | Description |
|------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Anthropic's CLI coding assistant |
| [OpenAI Codex CLI](https://github.com/openai/codex) | OpenAI's terminal coding agent |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Google's AI coding tool |

### CLIProxyAPI

If you use OAuth-based coding plans (Claude Pro/Max, ChatGPT Plus/Pro) and want to share that API access with OpenClaw without managing raw API keys, consider [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI):

- Multi-account load balancing
- Uses your existing OAuth subscriptions
- Compatible with OpenAI-format API calls

> **Note:** CLIProxyAPI is a third-party community tool. Review its docs and security implications before deploying.

---

## Session Persistence

The hardening script enables `loginctl enable-linger` for the openclaw user, which keeps systemd user services (including OpenClaw Gateway) running after SSH disconnects.

```bash
# Verify lingering is active
loginctl show-user openclaw | grep Linger
# Linger=yes
```

> A future OpenClaw skill will provide automatic Claude Code session persistence using this same mechanism.

---

## Automated Tasks

The script sets up these cron jobs:

| Schedule | Task |
|----------|------|
| Daily 2:00 AM | Full security scan (AIDE, rkhunter, chkrootkit, SSH logs, ports) |
| Sunday 3:00 AM | Rootkit database updates |
| Ongoing | Automatic security update installation |

---

Back to [README](../README.md)
