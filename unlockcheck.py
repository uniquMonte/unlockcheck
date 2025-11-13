#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UnlockCheck - Service Unlock Detection Tool
One-click detection of streaming media and AI services unlock status for your network environment
"""

import requests
import json
import sys
import argparse
import time
import socket
from datetime import datetime
from typing import Dict, Tuple, Optional
from colorama import init, Fore, Style

# Initialize colorama
init(autoreset=True)

# Configuration
VERSION = "1.2"
TIMEOUT = 10
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ========================================================================
# 表格布局常量 - 请勿修改！这些值是精心调整过的，确保所有行完美对齐
# ========================================================================
COLUMN_WIDTH_SERVICE = 16      # 服务名称列宽度（显示字符数）
COLUMN_WIDTH_STATUS = 20       # 解锁状态列宽度（显示字符数）
COLUMN_WIDTH_UNLOCK_TYPE = 8   # 解锁类型列宽度（显示字符数）
COLUMN_WIDTH_REGION = 3        # 区域列宽度（显示字符数）
SEPARATOR_WIDTH = 58           # 分隔线长度（字符数）
# ========================================================================


def print_separator():
    """Print a separator line with configurable width"""
    print(f"{Fore.CYAN}{'─' * SEPARATOR_WIDTH}{Style.RESET_ALL}")


class UnlockChecker:
    """Main unlock checker class for streaming media and AI services"""

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

    def check_dns_unlock(self, domain: str) -> str:
        """
        Check if DNS unlock is being used for a domain

        Note: Many services use CDN (like Cloudflare), different DNS servers returning
        different IPs is normal load balancing behavior. True DNS unlock detection requires
        more complex logic (checking IP ownership, AS numbers, etc.)

        Currently disabled to avoid false positives.

        Returns: 'native' or 'dns'
        """
        # Currently always return 'native' to avoid false positives
        # DNS unlock detection is disabled because CDN services naturally return different IPs
        return "native"

        # The following code is preserved but not used:
        # try:
        #     # Resolve using system default DNS
        #     system_ip = socket.getaddrinfo(domain, None)[0][4][0]
        #
        #     # Would need to resolve using public DNS (8.8.8.8) for comparison
        #     # But this requires more complex implementation with dnspython library
        #     #
        #     # For now, just return 'native'
        #     return "native"
        # except:
        #     return "native"

    def print_header(self):
        """Print program header"""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"\n{Fore.CYAN}{'='*62}")
        print(f"{' '*8}UnlockCheck - Service Unlock Detection Tool")
        print(f"{' '*10}https://github.com/uniquMonte/unlockcheck")
        print(f"{' '*16}检测时间: {current_time}")
        print(f"{'='*62}{Style.RESET_ALL}")

    def get_ip_info(self) -> Dict:
        """Get current IP information (enhanced: includes native IP detection, registration location, etc.)"""
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
            'TW': 'Taiwan', 'IN': 'India', 'BR': 'Brazil', 'RU': 'Russia',
            'ES': 'Spain', 'IT': 'Italy', 'SE': 'Sweden', 'NO': 'Norway', 'DK': 'Denmark',
            'FI': 'Finland', 'PL': 'Poland', 'CH': 'Switzerland', 'AT': 'Austria',
            'BE': 'Belgium', 'IE': 'Ireland', 'PT': 'Portugal', 'GR': 'Greece',
            'CZ': 'Czech Republic', 'RO': 'Romania', 'HU': 'Hungary', 'BG': 'Bulgaria',
            'TR': 'Turkey', 'IL': 'Israel', 'AE': 'UAE', 'SA': 'Saudi Arabia',
            'EG': 'Egypt', 'ZA': 'South Africa', 'MX': 'Mexico', 'AR': 'Argentina',
            'CL': 'Chile', 'CO': 'Colombia', 'PE': 'Peru', 'VN': 'Vietnam',
            'TH': 'Thailand', 'ID': 'Indonesia', 'MY': 'Malaysia', 'PH': 'Philippines',
            'NZ': 'New Zealand', 'UA': 'Ukraine', 'LT': 'Lithuania', 'LV': 'Latvia',
            'EE': 'Estonia', 'SK': 'Slovakia', 'SI': 'Slovenia', 'HR': 'Croatia'
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
        print_separator()

        # IP address
        print(f"IP Address: {Fore.GREEN}{self.ip_info.get('ip', 'N/A')}{Style.RESET_ALL}")

        # IP type (native IP or broadcast IP) - determine based on registration vs usage location
        ip_type_raw = self.ip_info.get('ip_type', 'Unknown')
        reg_loc = self.ip_info.get('registration_location', '')
        usage_loc = self.ip_info.get('usage_location', '')

        # Determine if it's native or broadcast IP
        is_native = False
        ip_type_display = ip_type_raw

        if ip_type_raw == 'Residential' or ip_type_raw == 'Mobile Network':
            # Residential and mobile are always considered native
            is_native = True
            ip_type_display = "Native IP"
            type_color = Fore.GREEN
        elif ip_type_raw == 'Datacenter/Hosting':
            # For datacenter, check if registration location matches usage location
            if reg_loc and usage_loc and reg_loc == usage_loc:
                is_native = True
                ip_type_display = "Native IP"
                type_color = Fore.GREEN
            else:
                is_native = False
                ip_type_display = "Broadcast IP"
                type_color = Fore.RED
        else:
            type_color = Fore.WHITE

        print(f"IP Type: {Style.BRIGHT}{type_color}{ip_type_display}{Style.RESET_ALL}")

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
                return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
            elif response.status_code == 403:
                return "failed", "N/A", "IP Blocked"
            elif response.status_code == 404:
                # Might be originals only
                return "partial", self.ip_info.get('country_code', 'Unknown'), "Originals Only"

            # Method 2: Check Netflix homepage for error messages
            response = self.session.get(
                "https://www.netflix.com/",
                timeout=TIMEOUT
            )

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your country" in content_lower or "not available in your location" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            if "not available" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # Check if it's actually Netflix (200 with Netflix content)
            if response.status_code == 200:
                if "netflix" in content_lower:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

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

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your region" in content_lower or "not available in your country" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            if "unavailable" in content_lower or "not available" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # 403 usually means IP blocked
            if response.status_code == 403:
                return "failed", "N/A", "Not Available in This Region"

            # Check if it's actually Disney+ (200 with Disney+ content)
            if response.status_code == 200:
                if "disney" in content_lower or "disneyplus" in content_lower:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

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
            # Check YouTube Premium page
            response = self.session.get(
                "https://www.youtube.com/premium",
                timeout=TIMEOUT
            )

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your country" in content_lower or "not available in your region" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            if "unavailable" in content_lower and "premium" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # 403 usually means blocked
            if response.status_code == 403:
                return "failed", "N/A", "Not Available in This Region"

            # Check if Premium is available (200 with Premium content)
            if response.status_code == 200:
                if "premium" in content_lower and ("youtube" in content_lower or "subscribe" in content_lower):
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"YouTube Premium check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_chatgpt(self) -> Tuple[str, str, str]:
        """
        Check ChatGPT/OpenAI accessibility
        Uses geolocation-based detection: checks if IP country is in unsupported regions
        Reference: https://platform.openai.com/docs/supported-countries
        Returns: (status, region, detail)
        """
        self.log("Checking ChatGPT/OpenAI...", "debug")

        # ChatGPT/OpenAI unsupported regions (based on official documentation)
        # https://platform.openai.com/docs/supported-countries
        UNSUPPORTED_REGIONS = [
            'CN',  # China
            'HK',  # Hong Kong
            'RU',  # Russia
            'IR',  # Iran
            'KP',  # North Korea
            'SY',  # Syria
            'CU',  # Cuba
            'BY',  # Belarus
            'VE',  # Venezuela
            # Add more based on official docs
        ]

        # Step 0: Check geolocation first (most reliable)
        country_code = self.ip_info.get('country_code', '').upper()

        if country_code in UNSUPPORTED_REGIONS:
            self.log(f"ChatGPT not supported in {country_code} (geolocation check)", "debug")
            return "failed", "N/A", "Region Restricted"

        api_result = None
        has_cloudflare = False

        # Step 1: Check API endpoint
        try:
            api_response = self.session.get(
                "https://api.openai.com/v1/models",
                timeout=TIMEOUT,
                headers={'Content-Type': 'application/json'}
            )

            if api_response.status_code == 401 or api_response.status_code == 400:
                api_result = ("success", "Normal Access")
            elif api_response.status_code == 403:
                try:
                    error_data = api_response.json()
                    if 'error' in error_data:
                        error_info = error_data['error']
                        error_code = error_info.get('code', '')
                        error_msg = error_info.get('message', '').lower()

                        if error_code == 'unsupported_country_region_territory':
                            api_result = ("failed", "Region Restricted")
                        elif any(keyword in error_msg for keyword in ['country', 'region', 'territory']):
                            api_result = ("failed", "Region Restricted")
                        else:
                            api_result = ("failed", "Access Denied")
                    else:
                        api_result = ("failed", "Access Denied")
                except:
                    # Check if API returned Cloudflare
                    if "cloudflare" in api_response.text.lower() or "attention required" in api_response.text.lower():
                        has_cloudflare = True
                    else:
                        api_result = ("failed", "Region Restricted")
            elif api_response.status_code == 451:
                api_result = ("failed", "Region Restricted")
        except:
            pass

        # Step 2: Check web endpoint if needed
        if not has_cloudflare and not (api_result and "Region Restricted" in api_result[1]):
            try:
                web_response = self.session.get(
                    "https://chatgpt.com/",
                    timeout=TIMEOUT,
                    allow_redirects=True,
                    headers={'Cache-Control': 'no-cache'}
                )

                content_lower = web_response.text.lower()

                # Check for Cloudflare challenge
                if web_response.status_code in [403, 503]:
                    if "just a moment" in content_lower or "checking your browser" in content_lower or "attention required" in content_lower:
                        has_cloudflare = True

            except:
                pass

        # Step 3: Intelligent decision based on priority
        # Priority 1: Explicit region restriction from API
        if api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]:
            return "failed", "N/A", "Region Restricted"

        # Priority 2: API success indicates availability (even if web has Cloudflare)
        if api_result and api_result[0] == "success":
            if has_cloudflare:
                return "success", self.ip_info.get('country_code', 'Unknown'), f"Normal Access{Fore.YELLOW}(CF Check){Fore.GREEN}"
            else:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"

        # Priority 3: Cloudflare blocking (only if API cannot confirm availability)
        # This suggests browser might still work
        if has_cloudflare:
            return "partial", self.ip_info.get('country_code', 'Unknown'), "Script Blocked(Browser OK)"

        # Priority 4: Access denied
        if api_result and api_result[0] == "failed":
            return "failed", "N/A", "Access Denied"

        # Fallback
        return "error", "N/A", "Detection Failed"

    def check_claude(self) -> Tuple[str, str, str]:
        """
        Check Claude AI accessibility
        Uses geolocation-based detection: checks if IP country is in unsupported regions
        Reference: https://www.anthropic.com/supported-countries
        Returns: (status, region, detail)
        """
        self.log("Checking Claude AI...", "debug")

        # Claude unsupported regions (based on official documentation)
        # https://www.anthropic.com/supported-countries
        UNSUPPORTED_REGIONS = [
            'CN',  # China
            'HK',  # Hong Kong (limited)
            'RU',  # Russia
            'IR',  # Iran
            'KP',  # North Korea
            'SY',  # Syria
            'CU',  # Cuba
            'BY',  # Belarus
            # Add more based on official docs
        ]

        # Step 0: Check geolocation first (most reliable)
        country_code = self.ip_info.get('country_code', '').upper()

        if country_code in UNSUPPORTED_REGIONS:
            self.log(f"Claude not supported in {country_code} (geolocation check)", "debug")
            return "failed", "N/A", "Region Restricted"

        api_result = None
        web_result = None
        has_cloudflare = False

        # Step 1: Check API endpoint
        try:
            api_response = self.session.get(
                "https://api.anthropic.com/v1/messages",
                timeout=TIMEOUT,
                headers={
                    'Content-Type': 'application/json',
                    'anthropic-version': '2023-06-01'
                }
            )

            if api_response.status_code == 401 or api_response.status_code == 400:
                api_result = ("success", "Normal Access")
            elif api_response.status_code == 403:
                try:
                    error_data = api_response.json()
                    error_msg = str(error_data).lower()
                    if "request not allowed" in error_msg or any(keyword in error_msg for keyword in ["region", "country", "territory"]):
                        api_result = ("failed", "Region Restricted")
                    else:
                        api_result = ("failed", "Access Denied")
                except:
                    api_result = ("failed", "Region Restricted")
            elif api_response.status_code == 451:
                api_result = ("failed", "Region Restricted")
        except:
            pass

        # Step 2: Check web endpoint for additional signals
        try:
            web_response = self.session.get(
                "https://claude.ai/",
                timeout=TIMEOUT,
                allow_redirects=True,
                headers={'Cache-Control': 'no-cache'}
            )

            content_lower = web_response.text.lower()

            # Check for Cloudflare challenge
            if web_response.status_code in [403, 503]:
                if "just a moment" in content_lower or "checking your browser" in content_lower:
                    has_cloudflare = True

            # Check for explicit region restriction on web
            if "<title>claude - unavailable</title>" in content_lower:
                web_result = ("failed", "Region Restricted")
            elif "應用程式不可用" in web_response.text or "僅在特定地區提供服務" in web_response.text:
                web_result = ("failed", "Region Restricted")

        except:
            pass

        # Step 3: Intelligent decision based on priority
        # Priority 1: Explicit region restriction (from API or web)
        if api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]:
            return "failed", "N/A", "Region Restricted"
        if web_result and web_result[0] == "failed":
            return "failed", "N/A", "Region Restricted"

        # Priority 2: API success indicates availability (even if web has Cloudflare)
        if api_result and api_result[0] == "success":
            if has_cloudflare:
                return "success", self.ip_info.get('country_code', 'Unknown'), f"Normal Access{Fore.YELLOW}(CF Check){Fore.GREEN}"
            else:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"

        # Priority 3: Cloudflare blocking (only if API cannot confirm availability)
        # This suggests browser might still work
        if has_cloudflare:
            return "partial", self.ip_info.get('country_code', 'Unknown'), "Script Blocked(Browser OK)"

        # Priority 4: Access denied (not region-specific)
        if api_result and api_result[0] == "failed":
            return "failed", "N/A", "Access Denied"

        # Fallback: Unable to determine
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

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your region" in content_lower or "not available in your country" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            if "blocked" in content_lower or "banned" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # 403/451 usually means region blocked
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "Not Available in This Region"

            # Check if it's actually TikTok (200 with TikTok content)
            if response.status_code == 200:
                if "tiktok" in content_lower:
                    region = self.ip_info.get('country_code', 'Unknown')
                    return "success", region, "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

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
            # Check Imgur homepage
            response = self.session.get(
                "https://imgur.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your region" in content_lower or "not available in your country" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            if "not available" in content_lower or "blocked" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # 403/451 usually means region blocked
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "Not Available in This Region"

            # 429 means rate limit, indicates service is accessible
            if response.status_code == 429:
                return "success", self.ip_info.get('country_code', 'Unknown'), "Accessible (Rate Limited)"

            # Check if Imgur is accessible (200 with Imgur content)
            if response.status_code == 200:
                if "imgur" in content_lower:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            # If main domain fails, try image domain
            try:
                alt_response = self.session.get(
                    "https://i.imgur.com/",
                    timeout=TIMEOUT,
                    allow_redirects=True
                )
                if alt_response.status_code == 200:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
            except:
                pass

            return "error", "N/A", f"Detection Failed ({response.status_code})"

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

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your region" in content_lower or "not available in your country" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # Check for blocked/banned messages
            if "blocked by network security" in content_lower or "blocked by mistake" in content_lower:
                return "partial", self.ip_info.get('country_code', 'Unknown'), "Limited Access (Login Required)"

            if "blocked" in content_lower or "banned" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # 403/451 usually means region blocked or IP restricted
            if response.status_code == 403 or response.status_code == 451:
                # Could be IP restriction that allows access after login
                return "partial", self.ip_info.get('country_code', 'Unknown'), "Limited Access (Login Required)"

            # Check if Reddit is accessible (200 with Reddit content)
            if response.status_code == 200:
                if "reddit" in content_lower:
                    # Check for location-based content restrictions
                    if "over18" in response.url or "location_blocking" in content_lower:
                        return "partial", self.ip_info.get('country_code', 'Unknown'), "Partially Restricted"
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Reddit check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    def check_gemini(self) -> Tuple[str, str, str]:
        """
        Check Google Gemini AI accessibility
        Uses geolocation-based detection: checks if IP country is in unsupported regions
        Reference: https://ai.google.dev/gemini-api/docs/available-regions
        Returns: (status, region, detail)
        """
        self.log("Checking Google Gemini...", "debug")

        # Gemini unsupported regions (based on official documentation)
        # https://ai.google.dev/gemini-api/docs/available-regions
        UNSUPPORTED_REGIONS = [
            'CN',  # China
            'HK',  # Hong Kong
            'MO',  # Macau
            'CU',  # Cuba
            'IR',  # Iran
            'KP',  # North Korea
            'RU',  # Russia
            'BY',  # Belarus
            'SY',  # Syria
            'VE',  # Venezuela
            # Add more based on official docs
        ]

        # Step 0: Check geolocation first (most reliable for Gemini)
        country_code = self.ip_info.get('country_code', '').upper()

        if country_code in UNSUPPORTED_REGIONS:
            self.log(f"Gemini not supported in {country_code} (geolocation check)", "debug")
            return "failed", "N/A", "Region Restricted"

        api_result = None
        web_result = None
        static_result = None
        studio_result = None

        # Step 1: Check API endpoint
        try:
            api_response = self.session.get(
                "https://generativelanguage.googleapis.com/v1beta/models",
                timeout=TIMEOUT,
                headers={'Content-Type': 'application/json'}
            )

            if api_response.status_code == 401 or api_response.status_code == 400:
                api_result = ("success", "Normal Access")
            elif api_response.status_code == 403:
                try:
                    error_data = api_response.json()
                    if 'error' in error_data:
                        error_info = error_data['error']
                        error_status = error_info.get('status', '')
                        error_msg = error_info.get('message', '').lower()

                        # PERMISSION_DENIED with API Key = service available
                        if error_status == 'PERMISSION_DENIED':
                            if 'api key' in error_msg or 'unregistered callers' in error_msg or 'established identity' in error_msg:
                                api_result = ("success", "Normal Access")
                            else:
                                api_result = ("failed", "Access Denied")
                        # Check for region restriction
                        elif any(keyword in error_msg for keyword in ['country', 'region', 'territory', 'not available', 'not supported']):
                            api_result = ("failed", "Region Restricted")
                        else:
                            api_result = ("failed", "Access Denied")
                    else:
                        api_result = ("failed", "Access Denied")
                except:
                    # 403 but not JSON response = likely region restriction
                    api_result = ("failed", "Region Restricted")
            elif api_response.status_code == 451:
                api_result = ("failed", "Region Restricted")
        except:
            pass

        # Step 2: Check web endpoint
        try:
            web_response = self.session.get(
                "https://gemini.google.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            content_lower = web_response.text.lower()

            # Check for 403 - region restriction
            if web_response.status_code == 403:
                if "access denied" in content_lower:
                    web_result = ("failed", "Region Restricted")
                else:
                    web_result = ("failed", "Access Denied")
            # Check for explicit region restriction messages
            elif "supported in your country" in content_lower or "not available in your country" in content_lower:
                web_result = ("failed", "Region Restricted")
            elif web_response.status_code == 200:
                # Check if it has actual Gemini app interface (not error page)
                if any(keyword in content_lower for keyword in ["sign in", "get started", "continue with google", "chat with gemini"]):
                    web_result = ("success", "Normal Access")
        except:
            pass

        # Step 3: Check static resources (only skip if already confirmed region restriction)
        region_confirmed = (
            (api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]) or
            (web_result and web_result[0] == "failed" and "Region Restricted" in web_result[1])
        )

        if not region_confirmed:
            try:
                static_response = self.session.get(
                    "https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg",
                    timeout=TIMEOUT
                )
                if static_response.status_code == 403:
                    static_result = ("failed", "Region Restricted")
                elif static_response.status_code == 200:
                    static_result = ("success", "Normal Access")
            except:
                pass

        # Step 4: Check AI Studio (only skip if already confirmed region restriction)
        region_confirmed = (
            (api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]) or
            (web_result and web_result[0] == "failed" and "Region Restricted" in web_result[1]) or
            (static_result and static_result[0] == "failed" and "Region Restricted" in static_result[1])
        )

        if not region_confirmed:
            try:
                studio_response = self.session.get(
                    "https://aistudio.google.com/app/prompts/new_chat",
                    timeout=TIMEOUT,
                    allow_redirects=False
                )
                if studio_response.status_code == 403:
                    studio_result = ("failed", "Region Restricted")
                elif studio_response.status_code in [200, 302]:
                    studio_result = ("success", "Normal Access")
            except:
                pass

        # Step 5: Intelligent decision based on priority
        # Priority 1: Any explicit region restriction
        if api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]:
            return "failed", "N/A", "Region Restricted"
        if web_result and web_result[0] == "failed":
            return "failed", "N/A", "Region Restricted"
        if static_result and static_result[0] == "failed":
            return "failed", "N/A", "Region Restricted"
        if studio_result and studio_result[0] == "failed":
            return "failed", "N/A", "Region Restricted"

        # Priority 2: Any success indicates availability
        if api_result and api_result[0] == "success":
            return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
        if web_result and web_result[0] == "success":
            return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
        if static_result and static_result[0] == "success":
            return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
        if studio_result and studio_result[0] == "success":
            return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"

        # Priority 3: Access denied
        if api_result and api_result[0] == "failed":
            return "failed", "N/A", "Access Denied"

        # Fallback
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

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your region" in content_lower or "not available in your country" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            if "not available" in content_lower and "spotify" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # 403 usually means region blocked
            if response.status_code == 403:
                return "failed", "N/A", "Not Available in This Region"

            # Check if Spotify is accessible (200 with Spotify content)
            if response.status_code == 200:
                if "spotify" in content_lower:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

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

            content_lower = response.text.lower()

            # Check for region restriction messages
            if "not available in your region" in content_lower or "not available in your country" in content_lower:
                return "failed", "N/A", "Not Available in This Region"

            # Check if redirected to sorry page (CAPTCHA/verification)
            if "sorry" in response.url.lower():
                return "partial", self.ip_info.get('country_code', 'Unknown'), "Limited Access (Robot)"

            # Check for unusual traffic detection or CAPTCHA
            if "unusual traffic" in content_lower or "captcha" in content_lower:
                return "partial", self.ip_info.get('country_code', 'Unknown'), "Limited Access (Robot)"

            # 403 usually means IP blocked
            if response.status_code == 403:
                return "failed", "N/A", "Not Available in This Region"

            # 429 means rate limited
            if response.status_code == 429:
                return "failed", "N/A", "Rate Limited"

            # Check if Google Scholar is accessible (200 with Scholar content)
            if response.status_code == 200:
                if "scholar" in content_lower and "google" in content_lower:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "Normal Access"
                else:
                    return "failed", "N/A", "Service Unavailable"

            return "error", "N/A", "Detection Failed"

        except requests.exceptions.Timeout:
            return "error", "N/A", "Timeout"
        except Exception as e:
            self.log(f"Google Scholar check exception: {e}", "debug")
            return "error", "N/A", "Detection Failed"

    @staticmethod
    def strip_ansi_codes(text: str) -> str:
        """Remove ANSI color codes from text"""
        import re
        ansi_escape = re.compile(r'\x1b\[[0-9;]*m')
        return ansi_escape.sub('', text)

    @staticmethod
    def get_display_width(text: str) -> int:
        """Calculate display width of text (CJK chars count as 2, ASCII as 1), excluding ANSI codes"""
        # Remove ANSI color codes first
        clean_text = UnlockChecker.strip_ansi_codes(text)
        width = 0
        for char in clean_text:
            # CJK characters and other wide characters
            if ord(char) > 127:
                width += 2
            else:
                width += 1
        return width

    @staticmethod
    def pad_to_width(text: str, target_width: int) -> str:
        """Pad text to target display width (handles ANSI color codes)"""
        current_width = UnlockChecker.get_display_width(text)
        if current_width < target_width:
            return text + ' ' * (target_width - current_width)
        return text

    def format_result(self, service_name: str, status: str, region: str, detail: str):
        """Format output for individual check result with aligned columns using fixed widths

        警告：此函数使用固定的列宽常量来确保表格对齐
        请勿修改 pad_to_width 的参数，否则会破坏对齐！
        """
        # Column 1: Status icon
        if status == "success":
            icon = f"{Fore.GREEN}[✓]{Style.RESET_ALL}"
            status_color = Fore.GREEN
        elif status == "failed":
            icon = f"{Fore.RED}[✗]{Style.RESET_ALL}"
            status_color = Fore.RED
        elif status == "partial":
            icon = f"{Fore.YELLOW}[◐]{Style.RESET_ALL}"
            status_color = Fore.YELLOW
        else:
            icon = f"{Fore.MAGENTA}[?]{Style.RESET_ALL}"
            status_color = Fore.MAGENTA

        # Column 2: Service name (使用固定列宽常量)
        service_padded = self.pad_to_width(service_name, COLUMN_WIDTH_SERVICE)
        service_formatted = f"{service_padded}:"

        # Column 3: Status detail (使用固定列宽常量)
        detail_padded = self.pad_to_width(detail, COLUMN_WIDTH_STATUS)
        detail_colored = f"{status_color}{detail_padded}{Style.RESET_ALL}"

        # Column 4: Unlock type label (使用固定列宽常量)
        # Note: DNS unlock detection is currently disabled to avoid false positives from CDN services
        # In the future, this could call check_dns_unlock() for each service domain
        unlock_type_text = ""
        unlock_type_color = ""
        if status == "success":
            # Currently always show native unlock
            # TODO: Implement proper DNS unlock detection by calling check_dns_unlock() for each service
            unlock_type_text = "原生"
            unlock_type_color = Fore.GREEN

        # Pad unlock type to fixed width, then add color
        unlock_type_padded = self.pad_to_width(unlock_type_text, COLUMN_WIDTH_UNLOCK_TYPE)
        if unlock_type_color:
            unlock_type_padded = f"{unlock_type_color}{unlock_type_padded}{Style.RESET_ALL}"

        # Column 5: Region info (使用固定列宽常量)
        if region != "N/A" and region != "Unknown":
            region_padded = self.pad_to_width(region, COLUMN_WIDTH_REGION)
            region_colored = f"{Fore.CYAN}{region_padded}{Style.RESET_ALL}"
        else:
            # Use empty spaces to maintain column alignment
            region_colored = self.pad_to_width("", COLUMN_WIDTH_REGION)

        # Print aligned columns (always include region column separator for consistent alignment)
        print(f"{icon} {service_formatted} {detail_colored} : {unlock_type_padded}: {region_colored}")

    def run_all_checks(self):
        """Run all checks"""
        self.print_header()

        # Get and display IP information
        self.get_ip_info()
        self.print_ip_info()

        # Display detection start
        print(f"{Fore.YELLOW}📺 Service Unlock Detection Results{Style.RESET_ALL}")
        print_separator()

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

        # Collect all results first
        results = []
        for service_name, check_func in checks:
            status, region, detail = check_func()
            results.append((service_name, status, region, detail))
            time.sleep(0.5)  # Avoid requests too fast

        # Print table header with fixed widths (使用固定列宽常量)
        # 警告：请勿修改列宽参数，这些值与 format_result 函数保持一致
        print()
        print_separator()
        header_service = self.pad_to_width("服务名称", COLUMN_WIDTH_SERVICE)
        header_status = self.pad_to_width("解锁状态", COLUMN_WIDTH_STATUS)
        header_type = self.pad_to_width("解锁类型", COLUMN_WIDTH_UNLOCK_TYPE)
        header_region = self.pad_to_width("区域", COLUMN_WIDTH_REGION)
        print(f"    {header_service}: {header_status} : {header_type}: {header_region}")
        print_separator()

        # Print all results with aligned columns
        for service_name, status, region, detail in results:
            self.format_result(service_name, status, region, detail)

        # Statistics
        success_count = sum(1 for _, status, _, _ in results if status == "success")
        total_count = len(results)

        print()
        print_separator()
        print(f"Detection Complete! {Fore.GREEN}{success_count}/{total_count}{Style.RESET_ALL} services available\n")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='UnlockCheck - Service Unlock Detection Tool'
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
    checker = UnlockChecker(verbose=args.verbose, ipv6=args.ipv6)

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
