#!/bin/bash

check_gemini_lightweight() {
    echo "检测 Gemini AI..."

    local status="unknown"
    local available=false

    # 测试点 1: API Models 端点
    echo "  [1/4] 检测 API 端点..."
    local api_test=$(curl -s -m 5 \
        "https://generativelanguage.googleapis.com/v1/models" 2>&1)

    if echo "$api_test" | grep -qi "PERMISSION_DENIED\|requires authentication"; then
        available=true
        echo "      ✓ API 端点响应正常"
    else
        echo "      ✗ API 端点: $(echo "$api_test" | head -c 100)"
    fi

    # 测试点 2: 检测 Gemini 主域名
    echo "  [2/4] 检测主域名..."
    local main_status=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -L "https://gemini.google.com/")

    if [[ "$main_status" == "200" ]]; then
        echo "      ✓ 主域名可访问 (HTTP $main_status)"
    else
        echo "      ✗ 主域名: HTTP $main_status"
    fi

    # 测试点 3: 检测静态资源
    echo "  [3/4] 检测静态资源..."
    local static_test=$(curl -s -m 5 \
        "https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg" \
        -w "%{http_code}" -o /dev/null)

    if [[ "$static_test" == "200" ]]; then
        echo "      ✓ 静态资源可访问 (HTTP $static_test)"
        available=true
    else
        echo "      ✗ 静态资源: HTTP $static_test"
    fi

    # 测试点 4: 检测 AI Studio（备选）
    echo "  [4/4] 检测 AI Studio..."
    local studio_test=$(curl -s -m 5 \
        "https://aistudio.google.com/app/prompts/new_chat" \
        -w "%{http_code}" -o /dev/null)

    if [[ "$studio_test" == "200" ]] || [[ "$studio_test" == "302" ]]; then
        echo "      ✓ AI Studio 可访问 (HTTP $studio_test)"
        available=true
    else
        echo "      ✗ AI Studio: HTTP $studio_test"
    fi

    # 综合判断
    echo ""
    if $available; then
        echo "✅ Gemini: 可用"
        echo "   └─ 多个端点测试通过"
        return 0
    else
        echo "❌ Gemini: 可能不可用"
        echo "   └─ 建议使用浏览器手动确认"
        return 1
    fi
}

# 运行检测
check_gemini_lightweight
