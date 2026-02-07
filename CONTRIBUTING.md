# Contributing to OpenClaw Pi

Thank you for your interest in contributing to OpenClaw Pi! This project hardens Raspberry Pi systems for running OpenClaw securely.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/KHAEntertainment/openclaw-pi/issues) first
2. Open a new issue with:
   - Hardware model and OS version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant log output (`/var/log/openclaw-hardening-*.log`)

### Suggesting Features

Open an issue with the `feature request` label describing:
- The problem your feature solves
- Your proposed solution
- Any alternatives you considered

### Submitting Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Ensure `shellcheck` passes (see below)
5. Test on actual Raspberry Pi hardware if possible
6. Commit your changes (`git commit -m 'Add your feature'`)
7. Push to the branch (`git push origin feature/your-feature`)
8. Open a Pull Request

## Code Standards

### Shell Script Requirements

- All scripts must pass `shellcheck` with no errors or warnings
- Use `bash` (not `sh`) for all scripts
- Follow existing patterns:
  - Use `print_header`, `print_success`, `print_error`, etc. for output
  - Use `confirm` for interactive prompts
  - Use `is_package_installed`, `is_service_active` for checks
  - Make all operations idempotent (safe to run multiple times)

### Running ShellCheck

```bash
# Install shellcheck
sudo apt install shellcheck

# Run against scripts
shellcheck harden-openclaw-pi.sh
shellcheck install.sh
```

### Commit Messages

- Use clear, descriptive messages
- Start with a verb: "Add", "Fix", "Update", "Remove"
- Reference issues when applicable: "Fix #42: AIDE false positive on Raspbian"

## Testing

### Before Submitting

1. Test on a fresh Raspberry Pi OS 64-bit Full installation
2. Verify idempotency: run the script twice and confirm no errors
3. Test both interactive and `--non-interactive` modes
4. Test with `--skip-long-ops` flag
5. Verify all security tools install and configure correctly

### Supported Platforms

- Raspberry Pi 4 Model B (2GB/4GB/8GB)
- Raspberry Pi 5 (4GB/8GB)
- Raspberry Pi OS 64-bit Full (Debian-based)

## Security

If you discover a security vulnerability, **DO NOT** open a public issue. See [SECURITY.md](SECURITY.md) for responsible disclosure instructions.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
