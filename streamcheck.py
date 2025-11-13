#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
StreamCheck - 流媒体解锁检测工具
一键检测当前网络环境对各大流媒体平台的解锁情况
"""

import requests
import json
import sys
import argparse
import time
from typing import Dict, Tuple, Optional
from colorama import init, Fore, Style

# 初始化 colorama
init(autoreset=True)

# 配置
VERSION = "1.2"
TIMEOUT = 10
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


class StreamChecker:
    """流媒体检测器主类"""

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
        """日志输出"""
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
        """打印程序头部"""
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"{' '*10}StreamCheck - 流媒体解锁检测工具 v{VERSION}")
        print(f"{'='*60}{Style.RESET_ALL}\n")

    def get_ip_info(self) -> Dict:
        """获取当前 IP 信息（增强版：包含原生IP判断、注册地等）"""
        self.log("正在获取 IP 信息...", "info")

        try:
            # 尝试使用 ipapi.co 获取详细信息
            response = self.session.get(
                "https://ipapi.co/json/",
                timeout=TIMEOUT
            )
            if response.status_code == 200:
                data = response.json()

                # 基础信息
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
                    # 尝试获取IP类型信息（原生IP判断）
                    self._detect_ip_type()
                    return self.ip_info
        except Exception as e:
            self.log(f"ipapi.co获取失败: {e}", "debug")

        # 备用方案1：使用 ipinfo.io
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
                    # 尝试获取IP类型信息
                    self._detect_ip_type()
                    return self.ip_info
        except Exception as e:
            self.log(f"ipinfo.io获取失败: {e}", "debug")

        # 备用方案2：使用 ip-api.com
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
                        # 尝试获取IP类型信息
                        self._detect_ip_type()
                        return self.ip_info
        except Exception as e:
            self.log(f"ip-api.com获取失败: {e}", "debug")

        # 最后fallback：只获取IP地址
        try:
            ip = self.session.get("https://api.ipify.org", timeout=5).text.strip()
            if ip:
                self.log(f"仅获取到IP地址: {ip}", "warning")
                self.ip_info = {
                    'ip': ip,
                    'country_code': 'Unknown',
                    'ip_type': '未知'
                }
                self._detect_ip_type()
                return self.ip_info
        except:
            pass

        self.log("无法获取 IP 信息，将继续检测（区域信息可能不准确）", "warning")
        self.ip_info = {'country_code': 'Unknown'}
        return self.ip_info

    def _detect_ip_type(self):
        """检测IP类型（原生IP或广播IP）"""
        try:
            # 通过 ip-api.com 获取更详细的IP信息
            response = self.session.get(
                f"http://ip-api.com/json/{self.ip_info.get('ip')}?fields=status,country,countryCode,region,regionName,city,isp,org,as,hosting,proxy,mobile",
                timeout=TIMEOUT
            )

            if response.status_code == 200:
                data = response.json()

                # 判断是否为数据中心IP/代理IP
                is_hosting = data.get('hosting', False)
                is_proxy = data.get('proxy', False)
                is_mobile = data.get('mobile', False)

                # 存储IP类型信息
                self.ip_info['is_hosting'] = is_hosting
                self.ip_info['is_proxy'] = is_proxy
                self.ip_info['is_mobile'] = is_mobile

                # 判断IP类型
                if is_hosting or is_proxy:
                    self.ip_info['ip_type'] = '广播IP/数据中心'
                elif is_mobile:
                    self.ip_info['ip_type'] = '移动网络'
                else:
                    self.ip_info['ip_type'] = '原生住宅IP'

                # 获取AS信息用于判断注册地
                if 'as' in data:
                    self.ip_info['as_info'] = data.get('as', 'N/A')

                # 实际使用地（从IP地理位置获取）
                self.ip_info['usage_location'] = f"{data.get('country', 'N/A')} {data.get('regionName', '')} {data.get('city', '')}"

                # 注册地：从ISP/组织信息推断
                org = data.get('org', '')
                if org:
                    # 对于数据中心IP，注册地通常是ISP的注册国家
                    import re
                    # 从ASN信息中提取可能的国家代码
                    as_info = data.get('as', '')
                    country_match = re.search(r'\b([A-Z]{2})\b', as_info)
                    if country_match:
                        self.ip_info['registration_location'] = country_match.group(1)
                    else:
                        self.ip_info['registration_location'] = org

        except Exception as e:
            self.log(f"检测IP类型失败: {e}", "debug")
            # 如果检测失败，使用默认值
            self.ip_info['ip_type'] = '未知'

    def print_ip_info(self):
        """打印 IP 信息（增强版）"""
        if not self.ip_info:
            return

        print(f"\n{Fore.YELLOW}🌍 当前 IP 信息{Style.RESET_ALL}")
        print(f"{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")

        # IP地址
        print(f"IP 地址: {Fore.GREEN}{self.ip_info.get('ip', 'N/A')}{Style.RESET_ALL}")

        # IP类型（原生IP或广播IP）
        ip_type = self.ip_info.get('ip_type', '未知')
        if ip_type == '原生住宅IP':
            type_color = Fore.GREEN
        elif ip_type == '广播IP/数据中心':
            type_color = Fore.YELLOW
        elif ip_type == '移动网络':
            type_color = Fore.CYAN
        else:
            type_color = Fore.WHITE

        print(f"IP 类型: {type_color}{ip_type}{Style.RESET_ALL}")

        # 使用地（IP的实际地理位置）
        if 'usage_location' in self.ip_info and self.ip_info.get('usage_location', '').strip():
            usage_loc = self.ip_info.get('usage_location', '').strip()
            if usage_loc != 'N/A' and usage_loc:
                print(f"使用地: {usage_loc}")
        else:
            # 如果没有usage_location，使用基本位置信息
            location = f"{self.ip_info.get('country', 'N/A')} {self.ip_info.get('region', '')} {self.ip_info.get('city', '')}"
            print(f"使用地: {location.strip()}")

        # 注册地（从ISP/ASN推断）
        if 'registration_location' in self.ip_info:
            reg_loc = self.ip_info.get('registration_location', '')
            if reg_loc:
                print(f"注册地: {reg_loc}")

        # ISP信息
        print(f"ISP: {self.ip_info.get('isp', 'N/A')}")

        # ASN信息
        if 'as_info' in self.ip_info:
            print(f"ASN: {self.ip_info.get('as_info', 'N/A')}")

        print()  # 空行

    def check_netflix(self) -> Tuple[str, str, str]:
        """
        检测 Netflix 解锁情况
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Netflix...", "debug")

        try:
            # 方法1: 检测 Netflix 原创内容
            response = self.session.get(
                "https://www.netflix.com/title/80018499",  # 原创剧集
                timeout=TIMEOUT,
                allow_redirects=False
            )

            if response.status_code == 200:
                return "success", self.ip_info.get('country_code', 'Unknown'), "完整解锁"
            elif response.status_code == 403:
                return "failed", "N/A", "不支持"
            elif response.status_code == 404:
                # 可能是仅解锁自制剧
                return "partial", self.ip_info.get('country_code', 'Unknown'), "仅自制剧"

            # 方法2: 检测 Netflix API
            response = self.session.get(
                "https://www.netflix.com/",
                timeout=TIMEOUT
            )

            if "Not Available" in response.text or "不可用" in response.text:
                return "failed", "N/A", "不支持"

            return "success", self.ip_info.get('country_code', 'Unknown'), "完整解锁"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Netflix 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_disney(self) -> Tuple[str, str, str]:
        """
        检测 Disney+ 解锁情况
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Disney+...", "debug")

        try:
            # 检测 Disney+ 主页
            response = self.session.get(
                "https://www.disneyplus.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被重定向到不支持的区域页面
            if "not available" in response.text.lower() or response.status_code == 403:
                return "failed", "N/A", "不支持"

            # 尝试获取区域信息
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
                    return "success", self.ip_info.get('country_code', 'Unknown'), "完整解锁"
            except:
                pass

            # 基于响应状态判断
            if response.status_code == 200:
                return "success", self.ip_info.get('country_code', 'Unknown'), "支持"

            return "partial", self.ip_info.get('country_code', 'Unknown'), "可能支持"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Disney+ 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_youtube_premium(self) -> Tuple[str, str, str]:
        """
        检测 YouTube Premium 可用性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 YouTube Premium...", "debug")

        try:
            # 检测 YouTube 区域限制
            response = self.session.get(
                "https://www.youtube.com/premium",
                timeout=TIMEOUT
            )

            if response.status_code == 200:
                # 检查页面内容判断是否支持 Premium
                if "premium" in response.text.lower():
                    return "success", self.ip_info.get('country_code', 'Unknown'), "支持"
                else:
                    return "failed", "N/A", "不支持"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"YouTube Premium 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_chatgpt(self) -> Tuple[str, str, str]:
        """
        检测 ChatGPT/OpenAI 可访问性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 ChatGPT/OpenAI...", "debug")

        try:
            # 检测 OpenAI 主页
            response = self.session.get(
                "https://chat.openai.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制
            if response.status_code == 403:
                return "failed", "N/A", "区域受限"

            if "not available" in response.text.lower() or "不可用" in response.text:
                return "failed", "N/A", "不支持"

            # 检查是否能访问
            if response.status_code == 200:
                # 某些国家/地区完全无法访问
                if "unsupported" in response.text.lower():
                    return "failed", "N/A", "不支持"
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"ChatGPT 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_claude(self) -> Tuple[str, str, str]:
        """
        检测 Claude AI 可访问性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Claude AI...", "debug")

        try:
            # 检测 Claude 主页
            response = self.session.get(
                "https://claude.ai/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制
            if response.status_code == 403:
                return "failed", "N/A", "区域受限"

            if "not available" in response.text.lower() or "不可用" in response.text:
                return "failed", "N/A", "不支持"

            if response.status_code == 200:
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Claude 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_tiktok(self) -> Tuple[str, str, str]:
        """
        检测 TikTok 区域限制
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 TikTok...", "debug")

        try:
            # 检测 TikTok 主页
            response = self.session.get(
                "https://www.tiktok.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # TikTok 在某些地区被封禁
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "区域受限"

            if "blocked" in response.text.lower() or "banned" in response.text.lower():
                return "failed", "N/A", "被封禁"

            if response.status_code == 200:
                # 尝试获取区域信息
                region = self.ip_info.get('country_code', 'Unknown')
                return "success", region, "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"TikTok 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_imgur(self) -> Tuple[str, str, str]:
        """
        检测 Imgur 可访问性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Imgur...", "debug")

        try:
            # 检测 Imgur 主页，增加重试逻辑
            response = self.session.get(
                "https://imgur.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "区域受限"

            if "not available" in response.text.lower() or "blocked" in response.text.lower():
                return "failed", "N/A", "不可用"

            # 200或重定向都算成功
            if response.status_code == 200 or (300 <= response.status_code < 400):
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            # 429表示速率限制，说明服务可访问
            if response.status_code == 429:
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问(速率限制)"

            # 如果主域名失败，尝试图片域名
            try:
                alt_response = self.session.get(
                    "https://i.imgur.com/",
                    timeout=TIMEOUT,
                    allow_redirects=True
                )
                if alt_response.status_code == 200:
                    return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"
            except:
                pass

            return "error", "N/A", f"无法访问({response.status_code})"

        except requests.exceptions.Timeout:
            return "error", "N/A", "连接超时"
        except requests.exceptions.ConnectionError:
            return "error", "N/A", "连接失败"
        except Exception as e:
            self.log(f"Imgur 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_reddit(self) -> Tuple[str, str, str]:
        """
        检测 Reddit 可访问性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Reddit...", "debug")

        try:
            # 检测 Reddit 主页
            response = self.session.get(
                "https://www.reddit.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制
            if response.status_code == 403 or response.status_code == 451:
                return "failed", "N/A", "区域受限"

            # Reddit 在某些国家被封禁
            if "blocked" in response.text.lower() or "banned" in response.text.lower():
                return "failed", "N/A", "被封禁"

            if response.status_code == 200:
                # Reddit 可能有 NSFW 内容限制
                if "over18" in response.url or "location_blocking" in response.text.lower():
                    return "partial", self.ip_info.get('country_code', 'Unknown'), "部分限制"
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Reddit 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_gemini(self) -> Tuple[str, str, str]:
        """
        检测 Google Gemini AI 可访问性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Google Gemini...", "debug")

        try:
            # 检测 Gemini 主页
            response = self.session.get(
                "https://gemini.google.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制
            if response.status_code == 403:
                return "failed", "N/A", "区域受限"

            # 检查是否有地区不可用的提示
            if "not available" in response.text.lower() or "unavailable" in response.text.lower():
                # 可能显示"在您的国家/地区不可用"
                return "failed", "N/A", "不支持"

            if response.status_code == 200:
                # 检查是否被重定向到错误页面
                if "error" in response.url.lower() or "/sorry/" in response.url:
                    return "failed", "N/A", "不支持"
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Gemini 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_spotify(self) -> Tuple[str, str, str]:
        """
        检测 Spotify 可用性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Spotify...", "debug")

        try:
            # 检测 Spotify Web Player
            response = self.session.get(
                "https://open.spotify.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制
            if response.status_code == 403:
                return "failed", "N/A", "区域受限"

            if response.status_code == 200:
                # 检查是否有区域限制提示
                if "not available" in response.text.lower():
                    return "failed", "N/A", "不支持"

                # Spotify 在大多数地区都可用
                return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Spotify 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def check_scholar(self) -> Tuple[str, str, str]:
        """
        检测 Google Scholar 可访问性
        返回: (状态, 区域, 详细信息)
        """
        self.log("检测 Google Scholar...", "debug")

        try:
            # 检测 Google Scholar 主页
            response = self.session.get(
                "https://scholar.google.com/",
                timeout=TIMEOUT,
                allow_redirects=True
            )

            # 检查是否被区域限制或需要验证
            if response.status_code == 403:
                return "failed", "N/A", "区域受限"

            # Google Scholar 可能会返回 CAPTCHA 或验证页面
            if "sorry" in response.url.lower() or response.status_code == 429:
                return "failed", "N/A", "需要验证/IP被限制"

            # 检查是否有异常流量检测
            if "unusual traffic" in response.text.lower() or "captcha" in response.text.lower():
                return "failed", "N/A", "检测到异常流量"

            if response.status_code == 200:
                # 检查是否能正常访问
                if "scholar" in response.text.lower() or "google" in response.text.lower():
                    return "success", self.ip_info.get('country_code', 'Unknown'), "可访问"

            return "error", "N/A", "无法访问"

        except requests.exceptions.Timeout:
            return "error", "N/A", "超时"
        except Exception as e:
            self.log(f"Google Scholar 检测异常: {e}", "debug")
            return "error", "N/A", "检测失败"

    def format_result(self, service_name: str, status: str, region: str, detail: str):
        """格式化输出单个检测结果"""
        # 状态图标和颜色
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

        # 格式化服务名称（固定宽度）
        service_formatted = f"{service_name:<15}"

        # 构建详细信息
        info = f"{detail}"
        if region != "N/A" and region != "Unknown":
            info += f" {Fore.CYAN}(区域: {region}){Style.RESET_ALL}"

        print(f"{icon} {service_formatted}: {color}{info}{Style.RESET_ALL}")

    def run_all_checks(self):
        """运行所有检测"""
        self.print_header()

        # 获取并显示 IP 信息
        self.get_ip_info()
        self.print_ip_info()

        # 显示检测开始
        print(f"{Fore.YELLOW}📺 流媒体检测结果{Style.RESET_ALL}")
        print(f"{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")

        # 检测各个服务
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
            time.sleep(0.5)  # 避免请求过快

        # 统计结果
        success_count = sum(1 for _, status, _, _ in results if status == "success")
        total_count = len(results)

        print(f"\n{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")
        print(f"检测完成! {Fore.GREEN}{success_count}/{total_count}{Style.RESET_ALL} 项服务可用\n")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='StreamCheck - 流媒体解锁检测工具'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='详细模式，显示调试信息'
    )
    parser.add_argument(
        '--ipv6',
        action='store_true',
        help='使用 IPv6 进行检测'
    )
    parser.add_argument(
        '--service', '-s',
        type=str,
        choices=['netflix', 'disney', 'youtube', 'chatgpt', 'claude', 'gemini', 'scholar', 'tiktok', 'imgur', 'reddit', 'spotify'],
        help='仅检测指定服务'
    )

    args = parser.parse_args()

    # 创建检测器实例
    checker = StreamChecker(verbose=args.verbose, ipv6=args.ipv6)

    try:
        if args.service:
            # 检测单个服务
            checker.print_header()
            checker.get_ip_info()
            checker.print_ip_info()

            print(f"{Fore.YELLOW}📺 流媒体检测结果{Style.RESET_ALL}")
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
            # 检测所有服务
            checker.run_all_checks()

    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}检测已取消{Style.RESET_ALL}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Fore.RED}发生错误: {e}{Style.RESET_ALL}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
