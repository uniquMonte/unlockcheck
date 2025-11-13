# StreamCheck - 流媒体解锁检测工具

一键检测当前网络环境对各大流媒体平台的解锁情况。

## 快速开始

### 🚀 一键运行（推荐）

无需克隆仓库，直接运行以下命令即可开始检测：

```bash
# 从main分支运行（稳定版）
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/streamcheck/main/install.sh)
```

**开发版本（v1.2 最新功能）：**
```bash
# 临时使用：从开发分支运行
BRANCH=claude/streaming-unlock-detector-011CV57GxrMmMPUDAAu5JKt6 bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/streamcheck/claude/streaming-unlock-detector-011CV57GxrMmMPUDAAu5JKt6/install.sh)
```

这将自动下载并运行最新版本的检测脚本。

## 功能特性

- ✅ Netflix 解锁检测（支持自制剧检测）
- ✅ Disney+ 解锁检测
- ✅ YouTube Premium 解锁检测
- ✅ ChatGPT/OpenAI 访问检测
- ✅ Claude AI 访问检测
- ✅ Google Gemini 访问检测
- ✅ Google Scholar 学术访问检测
- ✅ TikTok 区域检测
- ✅ Imgur 访问检测
- ✅ Reddit 访问检测
- ✅ Spotify 访问检测
- ✅ 支持 IPv4 和 IPv6
- ✅ 彩色终端输出
- ✅ 详细的地理位置信息（含IP类型判断：原生/广播）
- ✅ 一键安装运行

## 安装

### Python 版本（推荐）

```bash
# 克隆项目
git clone https://github.com/yourusername/streamcheck.git
cd streamcheck

# 安装依赖
pip install -r requirements.txt

# 运行检测
python streamcheck.py
```

### Bash 版本（轻量级）

```bash
# 克隆项目
git clone https://github.com/yourusername/streamcheck.git
cd streamcheck

# 添加执行权限
chmod +x streamcheck.sh

# 运行检测
./streamcheck.sh
```

## 使用方法

### Python 版本

```bash
# 完整检测
python streamcheck.py

# 只检测特定服务
python streamcheck.py --service netflix

# 检测 IPv6
python streamcheck.py --ipv6

# 详细模式
python streamcheck.py --verbose
```

### Bash 版本

```bash
# 完整检测
./streamcheck.sh

# 快速检测模式
./streamcheck.sh --fast
```

## 支持的平台

| 平台 | 检测内容 | 状态 |
|------|---------|------|
| Netflix | 是否解锁、支持的区域、自制剧 | ✅ |
| Disney+ | 是否解锁、支持的区域 | ✅ |
| YouTube Premium | Premium 功能可用性 | ✅ |
| ChatGPT | OpenAI 服务可访问性 | ✅ |
| Claude | Anthropic 服务可访问性 | ✅ |
| Google Gemini | Google AI 服务可访问性 | ✅ |
| Google Scholar | 学术搜索访问性（AI IP限制检测） | ✅ |
| TikTok | 区域限制检测 | ✅ |
| Imgur | 图片托管服务可访问性 | ✅ |
| Reddit | 社区平台可访问性 | ✅ |
| Spotify | 音乐流媒体服务可访问性 | ✅ |

## 输出示例

```
============================================================
          StreamCheck - 流媒体解锁检测工具 v1.2
============================================================

[INFO] 正在获取 IP 信息...

🌍 当前 IP 信息
────────────────────────────────────────────────────────────
IP 地址: 104.21.45.123
IP 类型: 广播IP/数据中心               # 黄色显示
使用地: 美国                           # IP地理位置国家
注册地: 美国                           # IP段注册国家
ISP: Cloudflare Inc.
ASN: AS13335 Cloudflare, Inc.

📺 流媒体检测结果
────────────────────────────────────────────────────────────
[✓] Netflix         : 完整解锁 (区域: US)
[✓] Disney+         : 完整解锁 (区域: US)
[✓] YouTube Premium : 支持
[✓] ChatGPT         : 可访问
[✓] Claude          : 可访问
[✓] Gemini          : 可访问 (区域: US)
[✓] Google Scholar  : 可访问 (区域: US)
[✓] TikTok          : 可访问 (区域: US)
[✓] Imgur           : 可访问 (区域: US)
[✓] Reddit          : 可访问 (区域: US)
[✓] Spotify         : 可访问 (区域: US)

────────────────────────────────────────────────────────────
检测完成! 11/11 项服务可用
```

### IP类型说明

- **原生住宅IP** (绿色): 真实家庭宽带IP，流媒体友好度最高
- **广播IP/数据中心** (黄色): VPS/云服务器IP，可能被部分服务限制
- **移动网络** (青色): 移动运营商IP，通常支持流媒体
- **未知** (白色): 无法判断IP类型

**使用地 vs 注册地：**
- **使用地**：IP地址的实际地理位置国家（通过GeoIP定位）
- **注册地**：IP段在RIR注册的国家（通过ASN查询）
- **判断原则**：
  - ✅ **使用地 = 注册地**：可能是原生IP（例：使用地=美国，注册地=美国）
  - ⚠️ **使用地 ≠ 注册地**：很可能是数据中心IP（例：使用地=德国，注册地=美国）
  - 💡 注册地显示"数据中心"：明确标识为托管服务商IP

### Google Scholar检测说明

Google Scholar 对使用数据中心IP或某些VPN的用户会显示验证页面或限制访问，通过此检测可以了解当前IP是否被Google识别为可疑流量。

## 工作原理

### 流媒体检测
本工具通过向各个平台的 API 发送请求，分析返回的状态码和响应内容来判断：

1. **Netflix**: 访问 Netflix 原创内容，检测区域限制和自制剧支持
2. **Disney+**: 检测 Disney+ 的地理位置 API
3. **YouTube Premium**: 检查 YouTube Premium 页面的区域可用性
4. **ChatGPT/OpenAI**: 检测 OpenAI 服务的可访问性
5. **Claude**: 检测 Anthropic 服务的可访问性
6. **Google Gemini**: 检测 Google AI 服务的可访问性和区域限制
7. **Google Scholar**: 检测学术搜索的访问性和IP限制（重要的AI训练数据来源）
8. **TikTok**: 检测 TikTok 的区域限制
9. **Imgur**: 检测图片托管服务的可访问性
10. **Reddit**: 检测社区平台的可访问性和内容限制
11. **Spotify**: 检测音乐流媒体服务的可访问性

### IP信息检测
- 使用多个IP查询API（ipapi.co, ipinfo.io, ip-api.com）获取详细信息
- 通过检测IP的hosting、proxy、mobile属性判断IP类型
- 区分原生住宅IP、数据中心IP和移动网络IP
- 显示ASN信息帮助了解IP归属
- **使用地检测**：通过GeoIP数据库获取IP的地理位置国家
- **注册地检测**：
  - 首选：通过BGP View API查询ASN的注册国家（最准确）
  - 备选：基于ISP名称匹配常见托管商的注册国家
  - 兜底：标识为"数据中心"
- **原生IP判断**：对比使用地和注册地是否一致，不一致则很可能是数据中心IP

## 依赖要求

### Python 版本
- Python 3.7+
- requests
- colorama

### Bash 版本
- curl
- jq (可选，用于 JSON 解析)

## 注意事项

- 检测结果仅供参考，实际可用性可能因账号、支付方式等因素而异
- 某些平台可能会限制 API 访问频率
- 建议使用 VPN 或代理时进行检测
- 本工具仅用于个人学习和测试，请勿用于商业用途

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 更新日志

### v1.2 (2025-11-13)
- 🎓 新增 Google Scholar 学术检测（检测AI IP限制）
- 🔍 增强IP信息显示：
  - 新增IP类型判断（原生住宅IP/广播IP/数据中心/移动网络）
  - **使用地显示**：IP地理位置国家
  - **注册地显示**：IP段注册国家（通过ASN查询）
  - 通过对比使用地和注册地，一眼识别是否为原生IP
  - 显示ASN信息
  - 彩色区分不同IP类型
- 📊 优化输出界面，信息更直观
- 🚀 支持 11 个主流平台检测
- 🔧 修复Imgur 429状态码处理

### v1.1 (2025-11-13)
- 新增 Google Gemini AI 检测
- 新增 Imgur 图片托管服务检测
- 新增 Reddit 社区平台检测
- 新增 Spotify 音乐流媒体检测
- 添加一键安装运行脚本 (install.sh)
- 支持 10 个主流平台检测
- 优化 Bash 脚本的快速模式

### v1.0 (2025-11-13)
- 初始版本发布
- 支持 6 个主流平台检测
- 提供 Python 和 Bash 两个版本

## 致谢

感谢所有为流媒体解锁检测做出贡献的开源项目。
