# StreamCheck - 流媒体解锁检测工具

一键检测当前网络环境对各大流媒体平台的解锁情况。

## 功能特性

- ✅ Netflix 解锁检测（支持自制剧检测）
- ✅ Disney+ 解锁检测
- ✅ YouTube Premium 解锁检测
- ✅ ChatGPT/OpenAI 访问检测
- ✅ Claude AI 访问检测
- ✅ TikTok 区域检测
- ✅ 支持 IPv4 和 IPv6
- ✅ 彩色终端输出
- ✅ 详细的地理位置信息

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
| TikTok | 区域限制检测 | ✅ |

## 输出示例

```
╔════════════════════════════════════════════════════════════╗
║         StreamCheck - 流媒体解锁检测工具 v1.0             ║
╚════════════════════════════════════════════════════════════╝

🌍 当前 IP 信息
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IPv4: 192.168.1.1
位置: 美国 加利福尼亚州 洛杉矶
ISP: Example ISP

📺 流媒体检测结果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✓] Netflix         : 完整解锁 (区域: US)
[✓] Disney+         : 完整解锁 (区域: US)
[✓] YouTube Premium : 支持
[✓] ChatGPT         : 可访问
[✓] Claude          : 可访问
[✓] TikTok          : 可访问 (区域: US)

检测完成！
```

## 工作原理

本工具通过向各个流媒体平台的 API 发送请求，分析返回的状态码和响应内容来判断：

1. **Netflix**: 访问 Netflix API，检测是否返回区域限制错误
2. **Disney+**: 检测 Disney+ 的地理位置 API
3. **YouTube Premium**: 检查 YouTube 的区域可用性
4. **ChatGPT/OpenAI**: 检测 OpenAI API 的可访问性
5. **Claude**: 检测 Anthropic 服务的可访问性
6. **TikTok**: 检测 TikTok 的区域限制

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

### v1.0 (2025-11-13)
- 初始版本发布
- 支持 6 个主流平台检测
- 提供 Python 和 Bash 两个版本

## 致谢

感谢所有为流媒体解锁检测做出贡献的开源项目。
