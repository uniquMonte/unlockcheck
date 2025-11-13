#!/bin/bash

echo "=========================================="
echo "Gemini 详细调试脚本"
echo "=========================================="
echo ""

# Test 1: API endpoint
echo "【测试 1】Gemini API 端点检测"
echo "URL: https://generativelanguage.googleapis.com/v1beta/models"
echo "---"

api_response=$(curl -sS -w "\nHTTP_CODE:%{http_code}\n" \
    -H "Content-Type: application/json" \
    --max-time 10 \
    "https://generativelanguage.googleapis.com/v1beta/models" 2>&1)

api_code=$(echo "$api_response" | grep "HTTP_CODE:" | cut -d: -f2)
api_content=$(echo "$api_response" | grep -v "HTTP_CODE:")

echo "HTTP Status: $api_code"
echo ""
echo "完整响应内容:"
echo "$api_content"
echo ""

echo "【分析 API 响应】"
if [ "$api_code" = "403" ]; then
    echo "✓ 状态码 403"

    if echo "$api_content" | grep -qi "PERMISSION_DENIED"; then
        echo "✓ 找到 PERMISSION_DENIED"

        if echo "$api_content" | grep -qi "api key"; then
            echo "✓ 找到 'API Key' → 判定：服务可用（缺少 API key）"
        elif echo "$api_content" | grep -qi "unregistered callers"; then
            echo "✓ 找到 'unregistered callers' → 判定：服务可用（缺少 API key）"
        elif echo "$api_content" | grep -qi "established identity"; then
            echo "✓ 找到 'established identity' → 判定：服务可用（缺少 API key）"
        else
            echo "✗ 没有找到 API key 相关提示 → 判定：访问被拒"
        fi
    fi

    if echo "$api_content" | grep -qi "country\|region\|territory\|not available\|not supported"; then
        echo "⚠ 找到地区限制关键词 → 判定：地区限制"
    fi
elif [ "$api_code" = "401" ]; then
    echo "✓ 状态码 401 → 判定：服务可用（缺少 API key）"
elif [ "$api_code" = "400" ]; then
    echo "✓ 状态码 400 → 判定：服务可用"
else
    echo "✗ 未预期的状态码: $api_code"
fi

echo ""
echo "=========================================="
echo ""

# Test 2: Web endpoint
echo "【测试 2】Gemini 网页端检测"
echo "URL: https://gemini.google.com/"
echo "---"

web_response=$(curl -sS -w "\nHTTP_CODE:%{http_code}\n" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -L \
    --max-time 10 \
    "https://gemini.google.com/" 2>&1)

web_code=$(echo "$web_response" | grep "HTTP_CODE:" | cut -d: -f2)
web_content=$(echo "$web_response" | grep -v "HTTP_CODE:")

echo "HTTP Status: $web_code"
echo ""
echo "响应大小: $(echo "$web_content" | wc -c) 字节"
echo ""

echo "【检查网页内容】"

# Check for region restriction
if echo "$web_content" | grep -qi "supported in your country"; then
    echo "✓ 找到: 'supported in your country'"
    echo "  上下文:"
    echo "$web_content" | grep -i "supported in your country" -C 2 | head -10
    echo "  → 判定：地区限制"
elif echo "$web_content" | grep -qi "not available in your country"; then
    echo "✓ 找到: 'not available in your country'"
    echo "  上下文:"
    echo "$web_content" | grep -i "not available in your country" -C 2 | head -10
    echo "  → 判定：地区限制"
elif echo "$web_content" | grep -qi "isn.*t.*available"; then
    echo "✓ 找到: 'isn't available' 相关"
    echo "  上下文:"
    echo "$web_content" | grep -iE "isn.*t.*available" -C 2 | head -10
    echo "  → 可能是地区限制"
else
    echo "✗ 未找到明确的地区限制消息"
fi

echo ""

# Check for app interface
if echo "$web_content" | grep -qi "sign in"; then
    echo "✓ 找到: 'sign in' → 有登录界面"
fi

if echo "$web_content" | grep -qi "get started"; then
    echo "✓ 找到: 'get started' → 有开始使用界面"
fi

if echo "$web_content" | grep -qi "continue with google"; then
    echo "✓ 找到: 'continue with google' → 有 Google 登录"
fi

if echo "$web_content" | grep -qi "chat with gemini"; then
    echo "✓ 找到: 'chat with gemini' → 有聊天界面"
fi

echo ""

# Check page title
echo "【页面标题】"
title=$(echo "$web_content" | grep -oP '<title[^>]*>\K[^<]+' | head -1)
if [ -n "$title" ]; then
    echo "  $title"
else
    echo "  (未找到标题)"
fi

echo ""
echo "=========================================="
echo ""

# Final decision simulation
echo "【智能检测逻辑模拟】"
echo ""

api_result=""
web_result=""

# Simulate API result
if [ "$api_code" = "401" ] || [ "$api_code" = "400" ]; then
    api_result="success"
elif [ "$api_code" = "403" ]; then
    if echo "$api_content" | grep -qi "PERMISSION_DENIED"; then
        if echo "$api_content" | grep -qi "api key\|unregistered callers\|established identity"; then
            api_result="success"
        else
            api_result="access_denied"
        fi
    elif echo "$api_content" | grep -qi "country\|region\|territory"; then
        api_result="region_restricted"
    else
        api_result="access_denied"
    fi
fi

# Simulate web result
if echo "$web_content" | grep -qi "supported in your country\|not available in your country"; then
    web_result="region_restricted"
elif echo "$web_content" | grep -qi "sign in\|get started\|continue with google\|chat with gemini"; then
    web_result="success"
fi

echo "API 判定: $api_result"
echo "网页判定: $web_result"
echo ""

echo "【最终判定（按优先级）】"
if [ "$api_result" = "region_restricted" ] || [ "$web_result" = "region_restricted" ]; then
    echo "→ 该地区不支持（明确的地区限制）"
elif [ "$api_result" = "success" ] || [ "$web_result" = "success" ]; then
    echo "→ 正常访问（服务可用）"
elif [ "$api_result" = "access_denied" ]; then
    echo "→ 访问被拒"
else
    echo "→ 检测失败"
fi

echo ""
echo "=========================================="
echo "调试完成"
echo ""
echo "请将上述输出发送给开发者"
echo "特别是【分析 API 响应】和【检查网页内容】部分"
echo "=========================================="
