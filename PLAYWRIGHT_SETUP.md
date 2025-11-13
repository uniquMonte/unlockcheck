# Playwright 无头浏览器检测方案

## 为什么需要 Playwright？

某些服务（如 Gemini）的地区限制信息是通过 JavaScript 动态加载的，传统的 curl/requests 无法检测到。Playwright 可以：

- ✅ 执行 JavaScript，检测动态内容
- ✅ 监听网络请求，捕获 403 错误
- ✅ 截图保存，便于调试
- ✅ 模拟真实浏览器行为

## 缺点

- ❌ 更慢（约 5-10 秒 vs 1-2 秒）
- ❌ 更重（需要下载 Chromium，约 300MB）
- ❌ 更多资源（内存占用更高）

## 安装步骤

### 方案 1: 本地安装（推荐）

```bash
# 1. 安装 Python 包
pip install playwright

# 2. 安装浏览器
playwright install chromium

# 3. 测试
python3 check_gemini_playwright.py
```

### 方案 2: Docker（适合无 root 权限）

```bash
# 使用官方 Playwright Docker 镜像
docker run -it --rm -v $(pwd):/work -w /work \
    mcr.microsoft.com/playwright/python:v1.40.0-jammy \
    python3 check_gemini_playwright.py
```

### 方案 3: 仅安装依赖（不下载浏览器）

如果您的系统已有 Chromium：

```bash
pip install playwright
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
```

## 使用方法

### 基本使用

```bash
# 运行检测
python3 check_gemini_playwright.py
```

### 查看输出

脚本会生成：
- `/tmp/gemini_screenshot.png` - 页面截图
- `/tmp/gemini_playwright.html` - 完整 HTML
- 终端输出 - 详细检测过程

### 返回值

- `0` - 正常访问
- `1` - 地区受限
- `2` - 检测失败
- `3` - 运行错误

## 集成到主脚本

### 选项 A: 可选增强检测

在主脚本中添加环境变量：

```bash
# 启用 Playwright 检测（可选）
export USE_PLAYWRIGHT=1

# 运行主脚本
python3 unlockcheck.py
```

### 选项 B: 仅在不确定时使用

当 curl 检测结果不确定时，自动回退到 Playwright：

```python
# 伪代码
result = check_gemini_with_curl()
if result == "uncertain":
    result = check_gemini_with_playwright()
```

### 选项 C: 单独运行

保持主脚本轻量，Playwright 作为独立工具：

```bash
# 快速检测（curl）
python3 unlockcheck.py

# 深度检测（Playwright，当结果有疑问时）
python3 check_gemini_playwright.py
```

## 性能对比

| 方法 | 速度 | 准确度 | 资源占用 | 适用场景 |
|------|------|--------|---------|---------|
| curl | ⚡⚡⚡ 快 | 🎯🎯 中 | 💾 低 | 常规检测 |
| Playwright | ⚡ 慢 | 🎯🎯🎯 高 | 💾💾💾 高 | 深度检测 |

## 故障排除

### 错误: "playwright not found"

```bash
pip install playwright
```

### 错误: "Executable doesn't exist"

```bash
playwright install chromium
```

### 错误: "Browser closed"

可能是内存不足，尝试：

```bash
# 增加超时时间
export PLAYWRIGHT_TIMEOUT=60000

# 或使用更轻量的浏览器
playwright install firefox
```

### 在 VPS 上运行失败

某些 VPS 缺少图形库：

```bash
# Ubuntu/Debian
apt-get install -y libgbm1 libxkbcommon0 libgtk-3-0

# CentOS/RHEL
yum install -y libXcomposite libXdamage libXrandr mesa-libgbm
```

## 建议

**默认使用 curl 检测，以下情况使用 Playwright：**

1. ✅ curl 检测返回"正常访问"但用户报告不可用
2. ✅ 需要验证动态加载的内容
3. ✅ 调试和截图
4. ✅ 一次性深度检测

**不建议用 Playwright 的场景：**

1. ❌ 批量检测多个服务
2. ❌ 频繁定时检测
3. ❌ 资源受限的环境

## 推荐方案

对于 UnlockCheck 项目：

```
✅ 主脚本: 保持轻量，使用 curl（覆盖 95% 场景）
✅ Playwright: 作为可选工具（处理特殊情况）
✅ 文档: 告知用户何时使用 Playwright
```

这样可以：
- 保持主脚本快速
- 满足深度检测需求
- 用户可按需选择
