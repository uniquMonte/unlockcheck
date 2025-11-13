#!/bin/bash

echo "========================================"
echo "Gemini 浏览器检测 (自动安装版)"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检测 Python
echo "【步骤 1】检测 Python 环境..."

PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    echo "✓ 找到: $(python3 --version)"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    echo "✓ 找到: $(python --version)"
else
    echo "✗ 未找到 Python"
    echo ""
    echo "请安装 Python 3:"
    echo "  Ubuntu/Debian: apt-get install -y python3 python3-pip"
    echo "  CentOS/RHEL:   yum install -y python3 python3-pip"
    exit 1
fi

echo ""

# 检测 pip
echo "【步骤 2】检测 pip..."

PIP_CMD=""
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
    echo "✓ 找到 pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
    echo "✓ 找到 pip"
else
    echo "✗ 未找到 pip，尝试安装..."

    # 尝试安装 pip
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y python3-pip
        PIP_CMD="pip3"
    elif command -v yum &> /dev/null; then
        yum install -y python3-pip
        PIP_CMD="pip3"
    else
        # 使用 ensurepip
        $PYTHON_CMD -m ensurepip --upgrade 2>/dev/null
        if [ $? -eq 0 ]; then
            PIP_CMD="$PYTHON_CMD -m pip"
            echo "✓ pip 安装成功"
        else
            echo "✗ pip 安装失败"
            echo ""
            echo "请手动安装 pip:"
            echo "  wget https://bootstrap.pypa.io/get-pip.py"
            echo "  $PYTHON_CMD get-pip.py"
            exit 1
        fi
    fi
fi

echo ""

# 检测 Playwright
echo "【步骤 3】检测 Playwright..."

if $PYTHON_CMD -c "import playwright" 2>/dev/null; then
    echo "✓ Playwright 已安装"
else
    echo "✗ Playwright 未安装，开始安装..."
    echo ""

    # 尝试正常安装
    $PIP_CMD install playwright --quiet --no-warn-script-location 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✓ Playwright 安装成功"
    else
        # 如果失败，尝试使用 --break-system-packages（新版 Debian/Ubuntu）
        echo "  ⚠ 正常安装失败，尝试使用系统包管理标志..."
        $PIP_CMD install playwright --break-system-packages --quiet --no-warn-script-location

        if [ $? -eq 0 ]; then
            echo "✓ Playwright 安装成功"
        else
            echo "✗ Playwright 安装失败"
            echo ""
            echo "请尝试手动安装:"
            echo "  $PIP_CMD install playwright --break-system-packages"
            exit 1
        fi
    fi
fi

echo ""

# 检测 Chromium
echo "【步骤 4】检测 Chromium 浏览器..."

# 检查 playwright 浏览器是否已安装
BROWSER_INSTALLED=false

if [ -d "$HOME/.cache/ms-playwright/chromium-"* ] 2>/dev/null; then
    BROWSER_INSTALLED=true
    echo "✓ Chromium 已安装"
elif [ -d "/root/.cache/ms-playwright/chromium-"* ] 2>/dev/null; then
    BROWSER_INSTALLED=true
    echo "✓ Chromium 已安装"
fi

if [ "$BROWSER_INSTALLED" = false ]; then
    echo "✗ Chromium 未安装，开始安装..."
    echo "   (这可能需要几分钟，下载约 300MB)"
    echo ""

    $PYTHON_CMD -m playwright install chromium

    if [ $? -eq 0 ]; then
        echo "✓ Chromium 安装成功"
    else
        echo "⚠ Chromium 安装可能失败，尝试继续..."
    fi
fi

echo ""

# 检测系统依赖
echo "【步骤 5】检测系统依赖..."

if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    MISSING_DEPS=false

    for dep in libgbm1 libxkbcommon0 libnss3; do
        if ! dpkg -l | grep -q "^ii  $dep"; then
            MISSING_DEPS=true
            break
        fi
    done

    if [ "$MISSING_DEPS" = true ]; then
        echo "⚠ 缺少系统依赖，尝试安装..."
        apt-get install -y libgbm1 libxkbcommon0 libnss3 libnspr4 libatk1.0-0 \
            libatk-bridge2.0-0 libcups2 libdrm2 libdbus-1-3 libxcb1 \
            libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 \
            libpango-1.0-0 libcairo2 libasound2 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "✓ 系统依赖安装成功"
        else
            echo "⚠ 系统依赖安装可能不完整，尝试继续..."
        fi
    else
        echo "✓ 系统依赖已满足"
    fi
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    echo "⚠ CentOS/RHEL 系统，可能需要手动安装依赖"
    echo "   yum install -y libXcomposite libXdamage libXrandr mesa-libgbm"
else
    echo "⚠ 未知系统，跳过依赖检查"
fi

echo ""
echo ""

# 运行检测
echo "========================================"
echo "【开始检测 Gemini】"
echo "========================================"
echo ""

# 创建临时 Python 脚本（简化版）
cat > /tmp/gemini_check_temp.py << 'PYEOF'
#!/usr/bin/env python3
import sys
import asyncio
import re

try:
    from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    print("错误: Playwright 导入失败")
    sys.exit(1)

async def check():
    print("启动浏览器...")
    async with async_playwright() as p:
        try:
            browser = await p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
            )

            context = await browser.new_context(
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            )

            page = await context.new_page()

            print("访问 https://gemini.google.com/ ...")

            try:
                await page.goto("https://gemini.google.com/", wait_until="networkidle", timeout=30000)
            except PlaywrightTimeout:
                print("⚠ 页面加载超时")
                await browser.close()
                return "timeout"

            print("等待 JavaScript 执行...")
            await asyncio.sleep(3)

            print("检查页面内容...")
            body_text = await page.text_content('body')

            # 检测限制
            restriction_patterns = [
                r"isn't currently supported",
                r"not currently supported",
                r"not available in your country",
                r"not supported in your region",
            ]

            found_restriction = False
            for pattern in restriction_patterns:
                if re.search(pattern, body_text, re.IGNORECASE):
                    print(f"✗ 找到限制: '{pattern}'")
                    found_restriction = True
                    break

            # 检测可用
            if not found_restriction:
                if re.search(r"sign in|get started", body_text, re.IGNORECASE):
                    print("✓ 页面显示正常")

            # 保存截图
            try:
                await page.screenshot(path="/tmp/gemini_check.png")
                print("✓ 截图已保存: /tmp/gemini_check.png")
            except:
                pass

            await browser.close()

            if found_restriction:
                return "restricted"
            else:
                return "available"

        except Exception as e:
            print(f"错误: {e}")
            return "error"

result = asyncio.run(check())

print("")
print("=" * 50)
if result == "restricted":
    print("🔴 结果: Gemini 该地区不支持")
    sys.exit(1)
elif result == "available":
    print("🟢 结果: Gemini 正常访问")
    sys.exit(0)
elif result == "timeout":
    print("⚪ 结果: 页面加载超时")
    sys.exit(2)
else:
    print("⚪ 结果: 检测失败")
    sys.exit(3)
PYEOF

chmod +x /tmp/gemini_check_temp.py

# 运行检测
$PYTHON_CMD /tmp/gemini_check_temp.py

exit_code=$?

# 清理
rm -f /tmp/gemini_check_temp.py

exit $exit_code
