# UnlockCheck - Service Unlock Detection Tool

One-click detection of streaming media and AI services unlock status for your current network environment.

## Quick Start

### 🚀 One-Click Run (Recommended)

No need to clone the repository, just run the following command to start detection:

```bash
# Run from main branch (stable version)
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/main/install.sh)
```

**Development Version (v1.3 Latest Features):**
```bash
# Temporary use: Run from development branch
BRANCH=claude/ip-geolocation-check-011CV5N8uHpGcyDHU2hDWRYa bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/claude/ip-geolocation-check-011CV5N8uHpGcyDHU2hDWRYa/install.sh)
```

This will automatically download and run the latest version of the detection script.

## Features

- ✅ Netflix unlock detection (supports originals detection)
- ✅ Disney+ unlock detection
- ✅ YouTube Premium unlock detection
- ✅ ChatGPT/OpenAI access detection
- ✅ Claude AI access detection
- ✅ Google Gemini access detection
- ✅ Google Scholar academic access detection
- ✅ TikTok region detection
- ✅ Imgur access detection
- ✅ Reddit access detection
- ✅ Spotify access detection
- ✅ IPv4 and IPv6 support
- ✅ Colorful terminal output
- ✅ Detailed geolocation information (including IP type detection: residential/broadcast)
- ✅ One-click installation and run

## Installation

### Python Version (Recommended)

```bash
# Clone the project
git clone https://github.com/uniquMonte/unlockcheck.git
cd unlockcheck

# Install dependencies
pip install -r requirements.txt

# Run detection
python unlockcheck.py
```

### Bash Version (Lightweight)

```bash
# Clone the project
git clone https://github.com/uniquMonte/unlockcheck.git
cd unlockcheck

# Add execute permission
chmod +x unlockcheck.sh

# Run detection
./unlockcheck.sh
```

## Usage

### Python Version

```bash
# Full detection
python unlockcheck.py

# Check specific service only
python unlockcheck.py --service netflix

# Check with IPv6
python unlockcheck.py --ipv6

# Verbose mode
python unlockcheck.py --verbose
```

### Bash Version

```bash
# Full detection
./unlockcheck.sh

# Fast detection mode
./unlockcheck.sh --fast
```

## Supported Platforms

| Platform | Detection Content | Status |
|----------|-------------------|--------|
| Netflix | Unlock status, supported region, originals | ✅ |
| Disney+ | Unlock status, supported region | ✅ |
| YouTube Premium | Premium feature availability | ✅ |
| ChatGPT | OpenAI service accessibility | ✅ |
| Claude | Anthropic service accessibility | ✅ |
| Google Gemini | Google AI service accessibility | ✅ |
| Google Scholar | Academic search accessibility (AI IP restriction detection) | ✅ |
| TikTok | Region restriction detection | ✅ |
| Imgur | Image hosting service accessibility | ✅ |
| Reddit | Community platform accessibility | ✅ |
| Spotify | Music streaming service accessibility | ✅ |

## Output Example

```
============================================================
          UnlockCheck - Service Unlock Detection Tool v1.3
============================================================

🌍 Current IP Information
────────────────────────────────────────────────────────────
IP Address: 104.21.45.123
IP Type: Datacenter/Hosting               # Displayed in yellow
Usage Location: United States             # IP geolocation country
Registered In: United States              # IP block registration country
ISP: Cloudflare Inc.
ASN: AS13335 Cloudflare, Inc.

📺 Service Unlock Detection Results
────────────────────────────────────────────────────────────
[✓] Netflix         : Full Access (Region: US)
[✓] Disney+         : Full Access (Region: US)
[✓] YouTube Premium : Available
[✓] ChatGPT         : Accessible
[✓] Claude          : Accessible
[✓] Gemini          : Accessible (Region: US)
[✓] Google Scholar  : Accessible (Region: US)
[✓] TikTok          : Accessible (Region: US)
[✓] Imgur           : Accessible (Region: US)
[✓] Reddit          : Accessible (Region: US)
[✓] Spotify         : Accessible (Region: US)

────────────────────────────────────────────────────────────
Detection Complete! 11/11 services available
```

### IP Type Explanation

- **Residential** (green): Real residential broadband IP, highest streaming media compatibility
- **Datacenter/Hosting** (yellow): VPS/cloud server IP, may be restricted by some services
- **Mobile Network** (cyan): Mobile carrier IP, usually supports streaming media
- **Unknown** (white): Cannot determine IP type

**Usage Location vs Registered In:**
- **Usage Location**: The actual geographic location country of the IP address (via GeoIP)
- **Registered In**: The country where the IP block is registered in RIR (via ASN lookup)
- **Judgment Principle**:
  - ✅ **Usage Location = Registered In**: Likely a residential IP (e.g., Usage: US, Registered: US)
  - ⚠️ **Usage Location ≠ Registered In**: Likely a datacenter IP (e.g., Usage: Germany, Registered: US)
  - 💡 Registered In shows "Datacenter": Clearly identified as hosting provider IP

### Google Scholar Detection Explanation

Google Scholar shows verification pages or restricts access for users using datacenter IPs or certain VPNs. This detection helps you understand if your current IP is identified as suspicious traffic by Google.

## How It Works

### Streaming Media Detection
This tool sends requests to various platform APIs and analyzes the returned status codes and response content to determine:

1. **Netflix**: Access Netflix original content, detect region restrictions and originals support
2. **Disney+**: Check Disney+ geolocation API
3. **YouTube Premium**: Check YouTube Premium page regional availability
4. **ChatGPT/OpenAI**: Detect OpenAI service accessibility
5. **Claude**: Detect Anthropic service accessibility
6. **Google Gemini**: Detect Google AI service accessibility and region restrictions
7. **Google Scholar**: Detect academic search accessibility and IP restrictions (important AI training data source)
8. **TikTok**: Detect TikTok region restrictions
9. **Imgur**: Detect image hosting service accessibility
10. **Reddit**: Detect community platform accessibility and content restrictions
11. **Spotify**: Detect music streaming service accessibility

### IP Information Detection
- Use multiple IP query APIs (ipapi.co, ipinfo.io, ip-api.com) to get detailed information
- Detect IP type by checking hosting, proxy, mobile attributes
- Distinguish residential IP, datacenter IP, and mobile network IP
- Display ASN information to help understand IP ownership
- **Usage Location Detection**: Get IP geolocation country via GeoIP database
- **Registered In Detection**:
  - Primary: Query ASN registration country via BGP View API (most accurate)
  - Fallback: Match common hosting providers' registration countries based on ISP name
  - Final: Identify as "Datacenter"
- **Residential IP Judgment**: Compare usage location and registration location; if inconsistent, likely a datacenter IP

## Requirements

### Python Version
- Python 3.7+
- requests
- colorama

### Bash Version
- curl
- jq (optional, for JSON parsing)

## Notes

- Detection results are for reference only; actual availability may vary due to account, payment method, etc.
- Some platforms may limit API access frequency
- Recommended to use VPN or proxy for detection
- This tool is for personal learning and testing only, not for commercial use

## Contributing

Issues and Pull Requests are welcome!

## License

MIT License

## Changelog

### v1.2 (2025-11-13)
- 🎓 Added Google Scholar academic detection (detect AI IP restrictions)
- 🔍 Enhanced IP information display:
  - Added IP type detection (Residential/Datacenter/Hosting/Mobile Network)
  - **Usage Location Display**: IP geolocation country
  - **Registered In Display**: IP block registration country (via ASN lookup)
  - By comparing usage location and registration location, easily identify if it's a residential IP
  - Display ASN information
  - Color-code different IP types
- 📊 Optimized output interface for more intuitive information
- 🚀 Support for 11 major platform detection
- 🔧 Fixed Imgur 429 status code handling

### v1.1 (2025-11-13)
- Added Google Gemini AI detection
- Added Imgur image hosting service detection
- Added Reddit community platform detection
- Added Spotify music streaming detection
- Added one-click installation script (install.sh)
- Support for 10 major platform detection
- Optimized Bash script fast mode

### v1.0 (2025-11-13)
- Initial version release
- Support for 6 major platform detection
- Provides both Python and Bash versions

## Acknowledgments

Thanks to all open-source projects that contributed to streaming media unlock detection.
