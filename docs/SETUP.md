# Setup Guide

Step-by-step guide to get your Raspberry Pi ready for OpenClaw.

---

## Hardware

### Recommended

| Device | Notes |
|--------|-------|
| **Raspberry Pi 5** | Best performance |
| **Raspberry Pi 4 Model B (2GB+)** | Great price/performance |
| **Raspberry Pi 4/5 Compute Module** | For industrial/embedded use |

### Minimum requirements

- 1GB RAM, 1 CPU core, 500MB disk
- 16GB+ SD card or **USB SSD** (strongly recommended)
- Official Raspberry Pi power adapter
- Ethernet cable (recommended for initial setup)

> **Pi Zero 2 W is not recommended** — insufficient resources for reliable operation.

### Tips

- Use a **USB SSD** instead of SD card for much better I/O performance and reliability
- For 2GB or less RAM, consider adding swap space (the script doesn't configure this automatically)
- OpenClaw acts as a lightweight gateway to cloud AI — the Pi doesn't run models locally, so you don't need a powerful machine

---

## Operating System

### Install Raspberry Pi OS Lite (64-bit)

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Choose OS: **Raspberry Pi OS Lite (64-bit)**
3. Click the **gear icon** (⚙️) for settings:
   - Enable **Raspberry Pi Connect** (for browser-based remote access)
   - Set hostname: `rpi-openclaw`
   - Set username and password
   - Configure WiFi if needed
4. Write to your SD card or USB SSD

### Why Lite?

- OpenClaw runs headless — no desktop/GUI needed
- Smaller footprint, less attack surface
- All dependencies are CLI-based (`git`, `curl`, `build-essential`, Node.js 22+)
- 64-bit is mandatory — Node.js 22 requires aarch64

> The Desktop version works too, but wastes resources on a GUI that OpenClaw doesn't use. If you accidentally installed Desktop, the hardening script will detect it and offer to [optimize for headless](HEADLESS.md).

---

## Network Isolation

**This is important.** OpenClaw executes code and calls external services. Run it on an isolated network:

### Option A: Guest Network (Easiest)

1. Set up a guest network on your router
2. Enable client isolation (no device-to-device communication)
3. Connect the Pi to the guest network

### Option B: VLAN (Advanced)

1. Create a dedicated VLAN for OpenClaw
2. Configure firewall rules between VLANs
3. Allow only SSH and OpenClaw Gateway traffic

> **Not sure how?** Ask an AI:
> *"How do I set up a guest network on [YOUR ROUTER MODEL] to isolate a Raspberry Pi?"*

---

## Remote Access

### Raspberry Pi Connect (Recommended)

If you enabled Raspberry Pi Connect during OS setup:

1. Visit [connect.raspberrypi.com](https://connect.raspberrypi.com)
2. Use terminal-only mode (much faster than desktop mode)
3. Works through firewalls and NAT — no port forwarding needed

### SSH (After Hardening)

```bash
# From your computer (same network)
ssh your-username@rpi-openclaw

# Or by IP
ssh your-username@192.168.x.x
```

### Tailscale (After Installation)

The hardening script can install Tailscale for encrypted remote access from anywhere:

```bash
ssh openclaw@rpi-openclaw   # Tailscale hostname
ssh openclaw@100.x.y.z      # Tailscale IP
```

See [Configuration Guide](CONFIGURATION.md#tailscale) for details.

---

## Next Step

Once your Pi is booted and you can SSH in, run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/install.sh | sudo bash
```

Back to [README](../README.md)
