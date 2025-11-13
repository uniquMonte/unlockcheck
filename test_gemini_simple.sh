#!/bin/bash

# 简单测试 - 只测试 Gemini 一个端点
echo "测试 Gemini API 端点..."

api_response=$(curl -sS --max-time 5 \
    -H "Content-Type: application/json" \
    -w "\n%{http_code}" \
    "https://generativelanguage.googleapis.com/v1beta/models" 2>&1)

api_status=$(echo "$api_response" | tail -n 1)
api_content=$(echo "$api_response" | head -n -1)

echo "HTTP 状态码: $api_status"
echo ""
echo "响应内容:"
echo "$api_content"
echo ""
echo "---"

# 判断逻辑
api_result=""

if [ "$api_status" = "401" ] || [ "$api_status" = "400" ]; then
    api_result="success"
    echo "判断: success (401/400)"
elif [ "$api_status" = "403" ]; then
    echo "收到 403，检查内容..."

    if echo "$api_content" | grep -qi "PERMISSION_DENIED"; then
        echo "  → 包含 PERMISSION_DENIED"
        if echo "$api_content" | grep -qi "api key\|unregistered callers\|established identity"; then
            api_result="success"
            echo "  → 包含 api key 提示 → success"
        else
            api_result="access_denied"
            echo "  → 不包含 api key 提示 → access_denied"
        fi
    elif echo "$api_content" | grep -qi "country\|region\|territory\|not available\|not supported"; then
        api_result="region_restricted"
        echo "  → 包含地区关键词 → region_restricted"
    else
        # 403 but not JSON response = likely region restriction
        api_result="region_restricted"
        echo "  → 403 但非 JSON → region_restricted"
    fi
elif [ "$api_status" = "451" ]; then
    api_result="region_restricted"
    echo "判断: region_restricted (451)"
else
    echo "判断: unknown (HTTP $api_status)"
fi

echo ""
echo "最终结果: $api_result"
