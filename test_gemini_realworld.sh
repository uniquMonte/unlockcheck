#!/bin/bash

echo "========================================"
echo "Gemini 实际可用性测试"
echo "========================================"
echo ""
echo "说明：由于 Gemini 的地区限制是 JavaScript 动态显示的，"
echo "      我们需要测试实际功能是否可用"
echo ""

TIMEOUT=10
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

echo "【测试 1】尝试获取对话历史（需要登录状态）"
echo "---"
response=$(curl -sS --max-time $TIMEOUT \
    -A "$USER_AGENT" \
    "https://gemini.google.com/_/BardChatUi/data/batchexecute" \
    -w "\n%{http_code}" 2>&1)

code=$(echo "$response" | tail -n 1)
content=$(echo "$response" | head -n -1)

echo "HTTP 状态码: $code"
echo "响应内容 (前200字符):"
echo "$content" | head -c 200
echo ""

if [ "$code" = "401" ]; then
    echo "✓ 返回 401 = 需要登录但服务可用"
    test1_result="available"
elif [ "$code" = "403" ]; then
    if echo "$content" | grep -qi "country\|region\|not.*support\|restricted"; then
        echo "✗ 返回 403 + 地区限制"
        test1_result="restricted"
    else
        echo "? 返回 403 但原因不明"
        test1_result="unknown"
    fi
elif [ "$code" = "200" ]; then
    echo "✓ 返回 200 = 服务可用"
    test1_result="available"
else
    echo "? 返回 $code"
    test1_result="unknown"
fi

echo ""
echo ""

echo "【测试 2】检查 Gemini App 配置 API"
echo "---"
response2=$(curl -sS --max-time $TIMEOUT \
    -A "$USER_AGENT" \
    "https://gemini.google.com/app" \
    -w "\n%{http_code}" 2>&1)

code2=$(echo "$response2" | tail -n 1)
content2=$(echo "$response2" | head -n -1)

echo "HTTP 状态码: $code2"
echo "响应大小: $(echo "$content2" | wc -c) 字节"

if [ "$code2" = "403" ]; then
    echo "✗ /app 路径返回 403"
    test2_result="restricted"
elif [ "$code2" = "200" ]; then
    # 检查内容中是否有限制信息
    if echo "$content2" | grep -qi "not.*support.*country\|unavailable.*region"; then
        echo "✗ 页面包含地区限制信息"
        test2_result="restricted"
    else
        echo "✓ /app 路径正常"
        test2_result="available"
    fi
else
    echo "? 返回 $code2"
    test2_result="unknown"
fi

echo ""
echo ""

echo "【测试 3】API 模型列表（已测试）"
echo "---"
api_response=$(curl -sS --max-time $TIMEOUT \
    "https://generativelanguage.googleapis.com/v1beta/models" 2>&1)

if echo "$api_response" | grep -qi "PERMISSION_DENIED.*api key"; then
    echo "✓ API 可用（需要 API Key）"
    test3_result="available"
elif echo "$api_response" | grep -qi "country\|region\|not.*support"; then
    echo "✗ API 地区限制"
    test3_result="restricted"
else
    echo "? API 状态不明"
    test3_result="unknown"
fi

echo ""
echo ""

echo "========================================"
echo "【综合判断】"
echo "========================================"
echo ""
echo "测试结果汇总:"
echo "  - 对话接口:  $test1_result"
echo "  - App 路径:   $test2_result"
echo "  - API 接口:   $test3_result"
echo ""

# 决策逻辑
if [ "$test2_result" = "restricted" ]; then
    echo "🔴 最终判断: 该地区不支持"
    echo "   原因: /app 路径返回地区限制"
elif [ "$test1_result" = "restricted" ]; then
    echo "🔴 最终判断: 该地区不支持"
    echo "   原因: 对话接口返回地区限制"
elif [ "$test3_result" = "available" ] && [ "$test1_result" = "available" ]; then
    echo "🟢 最终判断: 正常访问"
    echo "   原因: API 和对话接口都可用"
elif [ "$test3_result" = "available" ]; then
    echo "🟡 最终判断: API 可用，网页版状态不明"
    echo "   建议: 可以通过 API 使用 Gemini"
else
    echo "⚪ 最终判断: 检测结果不确定"
    echo "   建议: 在浏览器中手动验证"
fi

echo ""
echo "========================================"
