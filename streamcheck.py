#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
StreamCheck - Media Unlock Detection Tool
One-click detection of media platform unlock status for your network environment
"""

import requests
import json
import sys
import argparse
import time
from typing import Dict, Tuple, Optional
from colorama import init, Fore, Style

# Initialize colorama
init(autoreset=True)

# Configuration
VERSION = "1.2"
TIMEOUT = 10
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


class StreamChecker:
    """Main stream checker class"""

    def __init__(self, verbose=False, ipv6=False):
        self.verbose = verbose
        self.ipv6 = ipv6
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': USER_AGENT,
            'Accept-Language': 'en-US,en;q=0.9',
        })
        self.ip_info = {}

    def log(self, message, level="info"):
        """Log output"""
        if level == "info":
            print(f"{Fore.CYAN}[INFO]{Style.RESET_ALL} {message}")
        elif level == "success":
            print(f"{Fore.GREEN}[✓]{Style.RESET_ALL} {message}")
        elif level == "error":
            print(f"{Fore.RED}[✗]{Style.RESET_ALL} {message}")
        elif level == "warning":
            print(f"{Fore.YELLOW}[!]{Style.RESET_ALL} {message}")
        elif level == "debug" and self.verbose:
            print(f"{Fore.MAGENTA}[DEBUG]{Style.RESET_ALL} {message}")

    def print_header(self):
        """Print program header"""
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"{' '*10}StreamCheck - Media Unlock Detection Tool v{VERSION}")
        print(f"{'='*60}{Style.RESET_ALL}\n")

    def get_ip_info(self) -> Dict:
        """Get current IP information (enhanced: includes native IP detection, registration location, etc.)"""
        self.log("Fetching IP information...", "info")

        try:
            # Try using ipapi.co to get detailed information
            response = self.session.get(
                "https://ipapi.co/json/",
                timeout=TIMEOUT
            )
            if response.status_code == 200:
                data = response.json()

                # Basic information
                self.ip_info = {
                    'ip': data.get('ip', 'N/A'),
                    'country': data.get('country_name', 'N/A'),
                    'region': data.get('region', 'N/A'),
                    'city': data.get('city', 'N/A'),
                    'isp': data.get('org', 'N/A'),
                    'country_code': data.get('country_code', 'Unknown'),
                    'asn': data.get('asn', 'N/A'),
                    'timezone': data.get('timezone', 'N/A')
                }

                if self.ip_info['ip'] != 'N/A' and self.ip_info['country_code'] != 'Unknown':
                    # Try to get IP type information (native IP detection)
                    self._detect_ip_type()
                    return self.ip_info
        except Exception as e:
            self.log(f"ipapi.co fetch failed: {e}", "debug")

        # Fallback 1: Use ipinfo.io
        try:
            response = self.session.get(
                "https://ipinfo.io/json",
                timeout=TIMEOUT
            )
            if response.status_code == 200:
                data = response.json()
                self.ip_info = {
                    'ip': data.get('ip', 'N/A'),
                    'country': data.get('country', 'N/A'),
                    'region': data.get('region', 'N/A'),
                    'city': data.get('city', 'N/A'),
                    'isp': data.get('org', 'N/A'),
                    'country_code': data.get('country', 'Unknown'),
                    'timezone': data.get('timezone', 'N/A')
                }

                if self.ip_info['ip'] != 'N/A' and self.ip_info['country_code'] != 'Unknown':
                    # Try to get IP type information
                    self._detect_ip_type()
                    return self.ip_info
        except Exception as e:
            self.log(f"ipinfo.io fetch failed: {e}", "debug")

        # Fallback 2: Use ip-api.com
        try:
            response = self.session.get(
                "http://ip-api.com/json/?fields=status,country,countryCode,region,city,isp,org,as,query",
                timeout=TIMEOUT
            )
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 'success':
                    self.ip_info = {
                        'ip': data.get('query', 'N/A'),
                        'country': data.get('country', 'N/A'),
                        'region': data.get('region', 'N/A'),
                        'city': data.get('city', 'N/A'),
                        'isp': data.get('isp', 'N/A'),
                        'country_code': data.get('countryCode', 'Unknown'),
                        'as_info': data.get('as', 'N/A')
                    }

                    if self.ip_info['ip'] != 'N/A' and self.ip_info['country_code'] != 'Unknown':
                        # Try to get IP type information
                        self._detect_ip_type()
                        return self.ip_info
        except Exception as e:
            self.log(f"ip-api.com fetch failed: {e}", "debug")

        # Final fallback: Only get IP address
        try:
            ip = self.session.get("https://api.ipify.org", timeout=5).text.strip()
            if ip:
                self.log(f"Only IP address obtained: {ip}", "warning")
                self.ip_info = {
                    'ip': ip,
                    'country_code': 'Unknown',
                    'ip_type': 'Unknown'
                }
                self._detect_ip_type()
                return self.ip_info
        except:
            pass

        self.log("Unable to get IP information, continuing detection (region info may be inaccurate)", "warning")
        self.ip_info = {'country_code': 'Unknown'}
        return self.ip_info

    def _detect_ip_type(self):
        """Detect IP type (native IP or broadcast IP)"""
        try:
            # Get more detailed IP information through ip-api.com
            response = self.session.get(
                f"http://ip-api.com/json/{self.ip_info.get('ip')}?fields=status,country,countryCode,region,regionName,city,isp,org,as,hosting,proxy,mobile",
                timeout=TIMEOUT
            )

            if response.status_code == 200:
                data = response.json()

                # Determine if it's datacenter IP/proxy IP
                is_hosting = data.get('hosting', False)
                is_proxy = data.get('proxy', False)
                is_mobile = data.get('mobile', False)

                # Store IP type information
                self.ip_info['is_hosting'] = is_hosting
                self.ip_info['is_proxy'] = is_proxy
                self.ip_info['is_mobile'] = is_mobile

                # Determine IP type
                if is_hosting or is_proxy:
                    self.ip_info['ip_type'] = 'Datacenter/Hosting'
                elif is_mobile:
                    self.ip_info['ip_type'] = 'Mobile Network'
                else:
                    self.ip_info['ip_type'] = 'Residential'

                # Get AS information for registration location
                if 'as' in data:
                    self.ip_info['as_info'] = data.get('as', 'N/A')

                # Usage location: IP's actual geographic location (country only)
                self.ip_info['usage_location'] = data.get('country', 'N/A')

                # Registration location: Try to get IP block registration country from ASN
                import re
                as_info = data.get('as', '')
                asn_match = re.search(r'AS(\d+)', as_info)

                if asn_match:
                    asn_num = asn_match.group(1)
                    try:
                        # Query ASN registration country
                        asn_response = self.session.get(
                            f"https://api.bgpview.io/asn/{asn_num}",
                            timeout=3
                        )
                        if asn_response.status_code == 200:
                            asn_data = asn_response.json()
                            reg_country_code = asn_data.get('data', {}).get('country_code', '')
                            if reg_country_code:
                                self.ip_info['registration_location'] = self._convert_country_code(reg_country_code)
                    except:
                        pass

                # If unable to get from ASN, use fallback
                if 'registration_location' not in self.ip_info:
                    org = data.get('org', '')
                    self.ip_info['registration_location'] = self._guess_isp_country(org)

        except Exception as e:
            self.log(f"IP type detection failed: {e}", "debug")
            # If detection fails, use default value
            self.ip_info['ip_type'] = 'Unknown'

    def _convert_country_code(self, code: str) -> str:
        """Convert country code to country name"""
        country_map = {
            'US': 'United States', 'CA': 'Canada', 'GB': 'United Kingdom', 'DE': 'Germany',
            'FR': 'France', 'JP': 'Japan', 'CN': 'China', 'HK': 'Hong Kong',
            'SG': 'Singapore', 'AU': 'Australia', 'NL': 'Netherlands', 'KR': 'South Korea',
            'TW': 'Taiwan', 'IN': 'India', 'BR': 'Brazil', 'RU': 'Russia'
        }
        return country_map.get(code.upper(), code)

    def _guess_isp_country(self, org: str) -> str:
        """Guess country based on ISP name"""
        isp_country_map = {
            'HostPapa': 'Canada',
            'Cloudflare': 'United States',
            'Google': 'United States',
            'Amazon': 'United States',
            'Microsoft': 'United States',
            'Alibaba': 'China',
            'Tencent': 'China',
            'OVH': 'France',
            'Hetzner': 'Germany',
            'DigitalOcean': 'United States',
            'Linode': 'United States',
            'Vultr': 'United States'
        }

        for key, country in isp_country_map.items():
            if key.lower() in org.lower():
                return country

        return 'Datacenter'

    def print_ip_info(self):
        """Print IP information (enhanced version)"""
        if not self.ip_info:
            return

        print(f"\n{Fore.YELLOW}🌍 Current IP Information{Style.RESET_ALL}")
        print(f"{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")

        # IP address
        print(f"IP Address: {Fore.GREEN}{self.ip_info.get('ip', 'N/A')}{Style.RESET_ALL}")

        # IP type (native IP or broadcast IP)
        ip_type = self.ip_info.get('ip_type', 'Unknown')
        if ip_type == 'Residential':
            type_color = Fore.GREEN
        elif ip_type == 'Datacenter/Hosting':
            type_color = Fore.YELLOW
        elif ip_type == 'Mobile Network':
            type_color = Fore.CYAN
        else:
            type_color = Fore.WHITE

        print(f"IP Type: {type_color}{ip_type}{Style.RESET_ALL}")

        # Usage location (IP's actual geographic location)
        if 'usage_location' in self.ip_info and self.ip_info.get('usage_location', '').strip():
            usage_loc = self.ip_info.get('usage_location', '').strip()
            if usage_loc != 'N/A' and usage_loc:
                print(f"Usage Location: {usage_loc}")
        else:
            # If no usage_location, use basic location information
            location = f"{self.ip_info.get('country', 'N/A')} {self.ip_info.get('region', '')} {self.ip_info.get('city', '')}"
            print(f"Usage Location: {location.strip()}")

        # Registration location (inferred from ISP/ASN)
        if 'registration_location' in self.ip_info:
            reg_loc = self.ip_info.get('registration_location', '')
            if reg_loc:
                print(f"Registered In: {reg_loc}")

        # ISP information
        print(f"ISP: {self.ip_info.get('isp', 'N/A')}")

        # ASN information
        if 'as_info' in self.ip_info:
            print(f"ASN: {self.ip_info.get('as_info', 'N/A')}")

        print()  # Empty line

    def check_netflix(self) -> Tuple[str, str, str]:
        """
        Check Netflix unlock status
        Returns: (status, region, detail)
        """
        self.log("Checking Netflix...", "debug")

        try:
            # Method 1: Check Netflix original content
            response = self.session.get(
                "https://www.netflix.com/title/80018499",  # Original series
                timeout=TIMEOUT,
                allow_redirects=False
            )

            if response.status_code == 200:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Full Access"
            elif response.status_code == 403:
                return "failed", "N/A", "Not Available"
            elif response.status_code == 404:
                # Might be originals only
                return "partial", self.ip_info.get('country_code', 'Unknown'), "Originals Only"

            # Method 2: Check Netflix API
            response = self.session.get(
                "https://www.netflix.com/",
                timeout=TIMEOUT
            )

            if "Not Available" in response.text or "not available" in response.text.lower():
                return "failed", "N/A", "Not Available"

            return "success", self.ip_info.get('country_code', 'Unknown'), "Full Access"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Netflix check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_disney(self) -> Tuple[str, str, str]:
        """
        Check Disney+ unlock status
        Returns: (status, region, detail)
        """
        self.log("Checking Disney+...", "debug")

        try:
            # Check Disney+ homepage
            response = self.session.get(
                "https://www.disneyplus.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if redirected to unsupported region page
            if "not available" in response.text.lower() or response.status_code == 403:
                return "failed", "N/A", "Not Available"

            # Try to get region information
            try:
                headers = {
                    'User-Agent': USER_AGENT,
                    'Accept': 'application/json'
                }
                geo_response = self.session.get(
                    "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql",
                    headers=headers,
                    timeout=TIMEOUT
                )

                if geo_response.status_code == 200:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Full Access"
            except:
                pass

            # Judge based on response status
            if response.status_code == 200:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Available"

            return "partial", self.ip_info.get('country_code', 'Unknown'), "Possibly Available"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Disney+ check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_youtube_premium(self) -> Tuple[str, str, str]:
        """
        Check YouTube Premium availability
        Returns: (status, region, detail)
        """
        self.log("Checking YouTube Premium...", "debug")

        try:
            # Check YouTube region restrictions
            response = self.session.get(
                "https://www.youtube.com/premium",
                timeout=TIMEOUT
            )

            if response.status_code == 200:
                # Check page content to determine Premium support
                if "premium" in response.text.lower():
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Available"
                else:
                    return "failed", "N/A", "Not Available"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"YouTube Premium check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_chatgpt(self) -> Tuple[str, str, str]:
        """
        Check ChatGPT/OpenAI accessibility
        Returns: (status, region, detail)
        """
        self.log("Checking ChatGPT/OpenAI...", "debug")

        try:
            # Check OpenAI homepage
            response = self.session.get(
                "https://chat.openai.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted
            if response.status_code == 403:
                return "failed", "N/A", "Region Restricted"

            if "not available" in response.text.lower():
                return "failed", "N/A", "Not Available"

            # Check if accessible
            if response.status_code == 200:
                # Some countries/regions are completely inaccessible
                if "unsupported" in response.text.lower():
                    return "failed", "N/A", "Not Available"
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"ChatGPT check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_claude(self) -> Tuple[str, str, str]:
        """
        Check Claude AI accessibility
        Returns: (status, region, detail)
        """
        self.log("Checking Claude AI...", "debug")

        try:
            # Check Claude homepage
            response = self.session.get(
                "https://claude.ai/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted
            if response.status_code == 403:
                return "failed", "N/A", "Region Restricted"

            if "not available" in response.text.lower():
                return "failed", "N/A", "Not Available"

            if response.status_code == 200:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Claude check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_tiktok(self) -> Tuple[str, str, str]:
        """
        Check TikTok region restrictions
        Returns: (status, region, detail)
        """
        self.log("Checking TikTok...", "debug")

        try:
            # Check TikTok homepage
            response = self.session.get(
                "https://www.tiktok.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # TikTok is banned in certain regions
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "Region Restricted"

            if "blocked" in response.text.lower() or "banned" in response.text.lower():
                return "failed", "N/A", "Blocked"

            if response.status_code == 200:
                # Try to get region information
                region = self.ip_info.get('country_code', 'Unknown')
                return "success", region, "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"TikTok check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_imgur(self) -> Tuple[str, str, str]:
        """
        Check Imgur accessibility
        Returns: (status, region, detail)
        """
        self.log("Checking Imgur...", "debug")

        try:
            # Check Imgur homepage with retry logic
            response = self.session.get(
                "https://imgur.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "Region Restricted"

            if "not available" in response.text.lower() or "blocked" in response.text.lower():
                return "failed", "N/A", "Not Available"

            # 200 or redirect both count as success
            if response.status_code == 200 or (300 <= response.status_code < 400):
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            # 429 means rate limit, indicates service is accessible
            if response.status_code == 429:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible (Rate Limited)"

            # If main domain fails, try image domain
            try:
                alt_response = self.session.get(
                    "https://i.imgur.com/",
                    timeout=TIMEOUT,
                    allow_redirects=True
                )
                if alt_response.status_code == 200:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"
            except:
                pass

            return "error", "N/A", f"Inaccessible ({response.status_code})"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Connection Timeout"
        except requests.exceptions.ConnectionError:
            return "error", "N/A", "Connection Failed"
        except Exception as e:
            self.log(f"Imgur check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_reddit(self) -> Tuple[str, str, str]:
        """
        Check Reddit accessibility
        Returns: (status, region, detail)
        """
        self.log("Checking Reddit...", "debug")

        try:
            # Check Reddit homepage
            response = self.session.get(
                "https://www.reddit.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "Region Restricted"

            # Reddit is banned in some countries
            if "blocked" in response.text.lower() or "banned" in response.text.lower():
                return "failed", "N/A", "Blocked"

            if response.status_code == 200:
                # Reddit may have NSFW content restrictions
                if "over18" in response.url or "location_blocking" in response.text.lower():
                    return "partial", self.ip_info.get('country_code', 'Unknown'), "Partially Restricted"
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Reddit check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_gemini(self) -> Tuple[str, str, str]:
        """
        Check Google Gemini AI accessibility
        Returns: (status, region, detail)
        """
        self.log("Checking Google Gemini...", "debug")

        try:
            # Check Gemini homepage
            response = self.session.get(
                "https://gemini.google.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted
            if response.status_code == 403:
                return "failed", "N/A", "Region Restricted"

            # Check for region unavailable prompts
            if "not available" in response.text.lower() or "unavailable" in response.text.lower():
                # May show "not available in your country/region"
                return "failed", "N/A", "Not Available"

            if response.status_code == 200:
                # Check if redirected to error page
                if "error" in response.url.lower() or "/sorry/" in response.url:
                    return "failed", "N/A", "Not Available"
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Gemini check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_spotify(self) -> Tuple[str, str, str]:
        """
        Check Spotify availability
        Returns: (status, region, detail)
        """
        self.log("Checking Spotify...", "debug")

        try:
            # Check Spotify Web Player
            response = self.session.get(
                "https://open.spotify.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted
            if response.status_code == 403:
                return "failed", "N/A", "Region Restricted"

            if response.status_code == 200:
                # Check for region restriction prompts
                if "not available" in response.text.lower():
                    return "failed", "N/A", "Not Available"

                # Spotify is available in most regions
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Spotify check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_scholar(self) -> Tuple[str, str, str]:
        """
        Check Google Scholar accessibility
        Returns: (status, region, detail)
        """
        self.log("Checking Google Scholar...", "debug")

        try:
            # Check Google Scholar homepage
            response = self.session.get(
                "https://scholar.google.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # Check if region restricted or verification required
            if response.status_code == 403:
                return "failed", "N/A", "Region Restricted"

            # Google Scholar may return CAPTCHA or verification page
            if "sorry" in response.url.lower() or response.status_code == 429:
                return "failed", "N/A", "Verification Required/IP Restricted"

            # Check for unusual traffic detection
            if "unusual traffic" in response.text.lower() or "captcha" in response.text.lower():
                return "failed", "N/A", "Unusual Traffic Detected"

            if response.status_code == 200:
                # Check if accessible normally
                if "scholar" in response.text.lower() or "google" in response.text.lower():
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible"

            return "error", "N/A", "Inaccessible"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Google Scholar check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def format_result(self, service_name: str, status: str, region: str, detail: str):
        """Format output for individual check result"""
        # Status icon and color
        if status == "success":
            icon = f"{Fore.GREEN}[✓]{Style.RESET_ALL}"
            color = Fore.GREEN
        elif status == "failed":
            icon = f"{Fore.RED}[✗]{Style.RESET_ALL}"
            color = Fore.RED
        elif status == "partial":
            icon = f"{Fore.YELLOW}[◐]{Style.RESET_ALL}"
            color = Fore.YELLOW
        else:
            icon = f"{Fore.MAGENTA}[?]{Style.RESET_ALL}"
            color = Fore.MAGENTA

        # Format service name (fixed width)
        service_formatted = f"{service_name:<15}"

        # Build detailed information
        info = f"{detail}"
        if region != "N/A" and region != "Unknown":
            info += f" {Fore.CYAN}(Region: {region}){Style.RESET_ALL}"

        print(f"{icon} {service_formatted}: {color}{info}{Style.RESET_ALL}")

    def run_all_checks(self):
        """Run all checks"""
        self.print_header()

        # Get and display IP information
        self.get_ip_info()
        self.print_ip_info()

        # Display detection start
        print(f"{Fore.YELLOW}📺 Streaming Media Detection Results{Style.RESET_ALL}")
        print(f"{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")

        # Check each service
        checks = [
            ("Netflix", self.check_netflix),
            ("Disney+", self.check_disney),
            ("YouTube Premium", self.check_youtube_premium),
            ("ChatGPT", self.check_chatgpt),
            ("Claude", self.check_claude),
            ("Gemini", self.check_gemini),
            ("Google Scholar", self.check_scholar),
            ("TikTok", self.check_tiktok),
            ("Imgur", self.check_imgur),
            ("Reddit", self.check_reddit),
            ("Spotify", self.check_spotify),
        ]

        results = []
        for service_name, check_func in checks:
            status, region, detail = check_func()
            results.append((service_name, status, region, detail))
            self.format_result(service_name, status, region, detail)
            time.sleep(0.5)  # Avoid requests too fast

        # Statistics
        success_count = sum(1 for _, status, _, _ in results if status == "success")
        total_count = len(results)

        print(f"\n{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")
        print(f"Detection Complete! {Fore.GREEN}{success_count}/{total_count}{Style.RESET_ALL} services available\n")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='StreamCheck - Media Unlock Detection Tool'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Verbose mode, show debug info'
    )
    parser.add_argument(
        '--ipv6',
        action='store_true',
        help='Use IPv6 for detection'
    )
    parser.add_argument(
        '--service', '-s',
        type=str,
        choices=['netflix', 'disney', 'youtube', 'chatgpt', 'claude', 'gemini', 'scholar', 'tiktok', 'imgur', 'reddit', 'spotify'],
        help='Check specific service only'
    )

    args = parser.parse_args()

    # Create checker instance
    checker = StreamChecker(verbose=args.verbose, ipv6=args.ipv6)

    try:
        if args.service:
            # Check single service
            checker.print_header()
            checker.get_ip_info()
            checker.print_ip_info()

            print(f"{Fore.YELLOW}📺 Streaming Media Detection Results{Style.RESET_ALL}")
            print(f"{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")

            service_map = {
                'netflix': ('Netflix', checker.check_netflix),
                'disney': ('Disney+', checker.check_disney),
                'youtube': ('YouTube Premium', checker.check_youtube_premium),
                'chatgpt': ('ChatGPT', checker.check_chatgpt),
                'claude': ('Claude', checker.check_claude),
                'gemini': ('Gemini', checker.check_gemini),
                'scholar': ('Google Scholar', checker.check_scholar),
                'tiktok': ('TikTok', checker.check_tiktok),
                'imgur': ('Imgur', checker.check_imgur),
                'reddit': ('Reddit', checker.check_reddit),
                'spotify': ('Spotify', checker.check_spotify),
            }

            service_name, check_func = service_map[args.service]
            status, region, detail = check_func()
            checker.format_result(service_name, status, region, detail)
            print()
        else:
            # Check all services
            checker.run_all_checks()

    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}Detection cancelled{Style.RESET_ALL}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Fore.RED}Error occurred: {e}{Style.RESET_ALL}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
