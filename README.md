# UnlockCheck - Service Unlock Detection Tool

One-click detection of streaming media and AI services unlock status for your current network environment.

## Quick Start

### 🚀 One-Click Run (Recommended)

**Dual-Stack Detection (Default):**
```bash
# Automatically detects IPv4/IPv6 and runs appropriate tests
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/main/unlockcheck.sh)
```

**IPv4 Only:**
```bash
# Test IPv4 connectivity only
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/main/unlockcheck.sh) -4
```

**IPv6 Only:**
```bash
# Test IPv6 connectivity only
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/main/unlockcheck.sh) -6
```

**Development Version (Latest Features):**
```bash
# Default: Dual-stack detection
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/claude/ai-service-status-check-011CV5tiAjexptjDhAwugkLT/unlockcheck.sh)

# IPv4 only
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/claude/ai-service-status-check-011CV5tiAjexptjDhAwugkLT/unlockcheck.sh) -4

# IPv6 only
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/claude/ai-service-status-check-011CV5tiAjexptjDhAwugkLT/unlockcheck.sh) -6
```

### 📝 Usage Notes

- **Dual-Stack Detection**: By default, the script automatically detects your network environment:
  - If both IPv4 and IPv6 are available, it tests both
  - If only IPv4 is available, it automatically uses IPv4 only
  - If only IPv6 is available, it automatically uses IPv6 only

- **Manual Selection**: Use `-4` or `-6` to force IPv4 or IPv6 testing:
  - Useful for troubleshooting specific protocol issues
  - The script will exit with an error if the selected protocol is not available

## Acknowledgments

- [IPQuality](https://github.com/xykt/IPQuality) - IP quality detection script with streaming media unlock detection capabilities.

## License

MIT License
