# Headless Optimization

Convert a Raspberry Pi OS Desktop installation into a lean headless server for OpenClaw.

---

## Do I need this?

**If you installed Raspberry Pi OS Lite:** No — you're already optimized. Skip this.

**If you installed Raspberry Pi OS Desktop:** Yes — you're running ~200+ unnecessary packages (office suite, games, media players, screen savers) that waste disk space, RAM, and CPU on a headless server.

The main hardening script will **automatically detect** a desktop environment and offer to run this for you. You can also run it standalone — no need to re-run the full hardening script.

---

## Quick Start (standalone)

Already set up and just want to clean up Desktop bloat? One command:

```bash
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/optimize-headless.sh | sudo bash
```

### Preview first (recommended)

Download it, then simulate before committing:

```bash
curl -fsSL https://raw.githubusercontent.com/KHAEntertainment/openclaw-pi/main/optimize-headless.sh -o optimize-headless.sh
chmod +x optimize-headless.sh
sudo ./optimize-headless.sh --simulate
```

### All options

```bash
# Run interactively
sudo ./optimize-headless.sh

# Preview changes without applying them
sudo ./optimize-headless.sh --simulate

# Run without prompts (defaults to disable-only mode)
sudo ./optimize-headless.sh --non-interactive
```

---

## Two modes

### Disable only (reversible)

- Switches boot target to CLI (`multi-user.target`)
- Desktop packages stay installed but don't load
- Re-enable anytime:

```bash
sudo systemctl set-default graphical.target
sudo reboot
```

### Remove entirely

- Disables desktop **and** purges desktop packages
- Saves ~1GB+ of disk space
- Removes: LibreOffice, GIMP, games, VLC, screen savers, print system, and more
- Harder to reverse (requires reinstalling packages)

**In both modes, Chromium is always preserved** — OpenClaw needs it for browser automation.

---

## What gets removed

### Bloat packages (both modes)

| Category | Examples |
|----------|----------|
| Office/Productivity | LibreOffice, GIMP, Inkscape |
| Games | Mines, Sudoku, Mahjongg |
| Media | VLC, Rhythmbox, Shotwell, Cheese |
| Education | Scratch, Sonic Pi, Thonny, Geany |
| Screen savers | xscreensaver |
| Print system | CUPS, system-config-printer |
| Accessibility | Orca, BRLTTY |

### Desktop plumbing (remove mode only)

LXDE desktop, LightDM display manager, X session utilities, GTK theme engines, desktop wallpapers, PCManFM file manager, notification daemons, polkit auth dialogs.

### Services disabled

LightDM/GDM3, ModemManager, colord, PackageKit, speech-dispatcher, PipeWire (desktop audio), and optionally wpa_supplicant (if Ethernet-only).

---

## Phases

| Phase | What it does |
|-------|-------------|
| 0. Safety & Baseline | Detects desktop, records disk/package/service counts, saves package list |
| 1. Desktop Decision | Choose disable-only or remove-entirely |
| 2. Remove Bloat | Purges office, games, media, etc. (with dry-run preview) |
| 3. Disable Services | Stops and disables unnecessary desktop services |
| 4. Desktop Plumbing | Removes X server, window manager, themes (remove mode only) |
| 5. Housekeeping | autoremove, autoclean, journal vacuum, cache cleanup |
| 6. Verification | Before/after comparison, Chromium check, reboot prompt |

---

## Safety

- **Chromium is always protected** — `apt-mark manual` is called before every purge operation
- **Dry-run preview** — You see exactly what will be removed before confirming
- **Baseline saved** — Full package list is saved to `/var/log/` before any changes
- **Simulate mode** — `--simulate` lets you preview everything without making changes

---

Back to [README](../README.md)
