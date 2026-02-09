# Troubleshooting

Common issues and how to fix them.

---

## AIDE Initialization Stuck

**Symptom:** Script appears frozen during AIDE setup

**Why:** AIDE scans every file on disk to build its integrity database. This takes 10-30 minutes on a Raspberry Pi.

**Fix:** Wait it out, or monitor progress in another terminal:

```bash
watch -n 5 ls -lh /var/lib/aide/aide.db.new
# Database grows from 0 to ~5-15 MB when complete
```

**Alternative:** Skip it and run later:

```bash
# Use --skip-long-ops during install, then manually:
sudo aideinit
# Wait 10-30 minutes...
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

## Locked Out of SSH

### Prevention

- Set up SSH keys **before** the script disables password auth
- Test SSH key login before confirming password auth is disabled
- Enable Raspberry Pi Connect as a backup access method

### Recovery

1. **Raspberry Pi Connect:** Access via [connect.raspberrypi.com](https://connect.raspberrypi.com)
2. **Physical access:** Plug in a keyboard and monitor
3. Then check:

```bash
# Is SSH running?
sudo systemctl status sshd

# Is the firewall blocking you?
sudo ufw status
sudo ufw allow 22/tcp

# Re-enable password auth temporarily
sudo nano /etc/ssh/sshd_config.d/99-openclaw-hardening.conf
# Set: PasswordAuthentication yes
sudo systemctl restart sshd
```

---

## AIDE False Positives

**Symptom:** AIDE reports file changes after legitimate updates or package installs

**Fix:** Update the baseline database:

```bash
sudo /usr/local/bin/update-aide-db.sh

# Or manually:
sudo aide --update
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

## Tailscale Connection Issues

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

---

## OpenClaw Installation Failed

```bash
# Switch to openclaw user
su - openclaw

# Check Node.js
source ~/.nvm/nvm.sh
node --version  # Should be v22.x.x

# Reinstall Node.js if needed
nvm install 22
nvm use 22

# Retry OpenClaw install
cd ~/openclaw
npm install
npm run build
npm link
```

---

## OpenClaw Gateway Won't Start

**Symptom:** `systemctl --user` commands fail with DBUS errors

**Fix:** The hardening script should have configured this, but verify:

```bash
# Check lingering is enabled
loginctl show-user openclaw | grep Linger

# If not:
sudo loginctl enable-linger openclaw

# Verify DBUS environment
su - openclaw
echo $DBUS_SESSION_BUS_ADDRESS
echo $XDG_RUNTIME_DIR
# Should show: unix:path=/run/user/XXXX/bus and /run/user/XXXX
```

---

## Homebrew / Plugin Install Failures

```bash
su - openclaw

# Check if brew is in PATH
which brew

# If not found, add to PATH:
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc

# Retry plugin install
brew install <package-name>
```

---

## Script Won't Run

```bash
# Make sure it's executable
chmod +x harden-openclaw-pi.sh

# Make sure you're root
sudo ./harden-openclaw-pi.sh

# Check for disk space
df -h /
# Need at least 500MB free
```

---

## Check System Health

Quick commands to verify everything is working:

```bash
# Firewall
sudo ufw status

# fail2ban
sudo fail2ban-client status sshd

# AIDE database exists
ls -lh /var/lib/aide/aide.db

# Cron jobs are set
sudo crontab -l

# OpenClaw user exists
id openclaw

# Security scan script exists
ls -l /usr/local/bin/security-scan.sh
```

---

Back to [README](../README.md)
