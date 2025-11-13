#!/bin/bash

echo "========================================"
echo "Gemini 全端点详细检测"
echo "========================================"
echo ""

# 测试 1: API 端点
echo "【测试 1】API 端点 - generativelanguage.googleapis.com"
echo "---"
api_response=$(curl -sS --max-time 5 \
    -H "Content-Type: application/json" \
    -w "\n===HTTP_CODE:%{http_code}===" \
    "https://generativelanguage.googleapis.com/v1beta/models" 2>&1)

api_code=$(echo "$api_response" | grep "===HTTP_CODE:" | cut -d: -f2 | cut -d= -f1)
api_content=$(echo "$api_response" | grep -v "===HTTP_CODE:")

echo "  HTTP 状态码: $api_code"
echo "  响应内容 (前200字符):"
echo "$api_content" | head -c 200
echo ""
echo "  是否包含 PERMISSION_DENIED: $(echo "$api_content" | grep -qi "PERMISSION_DENIED" && echo "是" || echo "否")"
echo "  是否包含 api key: $(echo "$api_content" | grep -qi "api key" && echo "是" || echo "否")"
echo ""

# 测试 2: 主域名
echo "【测试 2】主域名 - gemini.google.com"
echo "---"
web_response=$(curl -sS --max-time 5 \
    -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    -L \
    -w "\n===HTTP_CODE:%{http_code}===" \
    "https://gemini.google.com/" 2>&1)

web_code=$(echo "$web_response" | grep "===HTTP_CODE:" | cut -d: -f2 | cut -d= -f1)
web_content=$(echo "$web_response" | grep -v "===HTTP_CODE:")

echo "  HTTP 状态码: $web_code"
echo "  响应内容 (前200字符):"
echo "$web_content" | head -c 200
echo ""
echo "  是否包含 'access denied': $(echo "$web_content" | grep -qi "access denied" && echo "是" || echo "否")"
echo "  是否包含 'sign in': $(echo "$web_content" | grep -qi "sign in" && echo "是" || echo "否")"
echo "  是否包含 'not.*supported.*country': $(echo "$web_content" | grep -Eqi "not.*supported.*country|supported.*your.*country" && echo "是" || echo "否")"
echo ""

# 测试 3: 静态资源
echo "【测试 3】静态资源 - gstatic.com"
echo "---"
static_code=$(curl -sS -o /dev/null -w "%{http_code}" \
    --max-time 5 \
    "https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg" 2>&1)

echo "  HTTP 状态码: $static_code"
echo ""

# 测试 4: AI Studio
echo "【测试 4】AI Studio - aistudio.google.com"
echo "---"
studio_response=$(curl -sS --max-time 5 \
    -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    -w "\n===HTTP_CODE:%{http_code}===" \
    "https://aistudio.google.com/app/prompts/new_chat" 2>&1)

studio_code=$(echo "$studio_response" | grep "===HTTP_CODE:" | cut -d: -f2 | cut -d= -f1)
studio_content=$(echo "$studio_response" | grep -v "===HTTP_CODE:")

echo "  HTTP 状态码: $studio_code"
echo "  响应内容 (前200字符):"
echo "$studio_content" | head -c 200
echo ""

# 分析结果
echo ""
echo "========================================"
echo "【检测逻辑分析】"
echo "========================================"
echo ""

# API 判断
echo "API 端点判断："
if [ "$api_code" = "401" ] || [ "$api_code" = "400" ]; then
    echo "  → 结果: success (401/400表示需要认证)"
elif [ "$api_code" = "403" ]; then
    if echo "$api_content" | grep -qi "PERMISSION_DENIED"; then
        if echo "$api_content" | grep -qi "api key\|unregistered callers\|established identity"; then
            echo "  → 结果: success (PERMISSION_DENIED + api key提示)"
        else
            echo "  → 结果: region_restricted (PERMISSION_DENIED但无api key提示)"
        fi
    else
        echo "  → 结果: region_restricted (403但非JSON响应)"
    fi
elif [ "$api_code" = "451" ]; then
    echo "  → 结果: region_restricted (HTTP 451)"
else
    echo "  → 结果: unknown (HTTP $api_code)"
fi
echo ""

# Web 判断
echo "主域名判断："
if [ "$web_code" = "403" ]; then
    if echo "$web_content" | grep -qi "access denied"; then
        echo "  → 结果: region_restricted (403 + access denied)"
    else
        echo "  → 结果: access_denied (403但无access denied)"
    fi
elif echo "$web_content" | grep -Eqi "not.*supported.*country|supported.*your.*country"; then
    echo "  → 结果: region_restricted (包含地区限制消息)"
elif [ "$web_code" = "200" ]; then
    if echo "$web_content" | grep -qi "sign in\|get started\|continue with google\|chat with gemini"; then
        echo "  → 结果: success (200 + 登录界面)"
    else
        echo "  → 结果: unknown (200但无登录界面)"
    fi
else
    echo "  → 结果: unknown (HTTP $web_code)"
fi
echo ""

# 静态资源判断
echo "静态资源判断："
if [ "$static_code" = "403" ]; then
    echo "  → 结果: region_restricted (HTTP 403)"
elif [ "$static_code" = "200" ]; then
    echo "  → 结果: success (HTTP 200)"
else
    echo "  → 结果: unknown (HTTP $static_code)"
fi
echo ""

# AI Studio 判断
echo "AI Studio 判断："
if [ "$studio_code" = "403" ]; then
    echo "  → 结果: region_restricted (HTTP 403)"
elif [ "$studio_code" = "200" ] || [ "$studio_code" = "302" ]; then
    echo "  → 结果: success (HTTP $studio_code)"
else
    echo "  → 结果: unknown (HTTP $studio_code)"
fi
echo ""

# 最终判断
echo "========================================"
echo "【最终判断】"
echo "========================================"

# 检查是否任何端点返回地区限制
has_restriction=false
has_success=false

# 简化的判断逻辑
if [ "$api_code" = "403" ]; then
    if ! echo "$api_content" | grep -qi "PERMISSION_DENIED.*api key\|unregistered callers"; then
        has_restriction=true
        echo "✗ API 端点显示地区限制"
    fi
fi

if [ "$web_code" = "403" ]; then
    has_restriction=true
    echo "✗ 主域名返回 403"
fi

if [ "$static_code" = "403" ]; then
    has_restriction=true
    echo "✗ 静态资源返回 403"
fi

if [ "$studio_code" = "403" ]; then
    has_restriction=true
    echo "✗ AI Studio 返回 403"
fi

# 检查成功标志
if echo "$api_content" | grep -qi "PERMISSION_DENIED.*api key\|unregistered callers"; then
    has_success=true
    echo "✓ API 端点可访问 (需要密钥)"
fi

if [ "$web_code" = "200" ] && echo "$web_content" | grep -qi "sign in"; then
    has_success=true
    echo "✓ 主域名可访问"
fi

echo ""
if [ "$has_restriction" = true ]; then
    echo "🔴 最终结果: 该地区不支持"
elif [ "$has_success" = true ]; then
    echo "🟢 最终结果: 正常访问"
else
    echo "⚪ 最终结果: 检测失败"
fi
