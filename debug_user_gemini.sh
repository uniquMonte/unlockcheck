#!/bin/bash

echo "========================================"
echo "Gemini 用户环境完整调试"
echo "========================================"
echo "时间: $(date)"
echo "脚本版本: $(git log -1 --oneline 2>/dev/null || echo '无法获取')"
echo ""

# 配置
TIMEOUT=8
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# 初始化结果
api_result=""
web_result=""
static_result=""
studio_result=""

echo "========================================"
echo "【步骤 1/4】API 端点检测"
echo "========================================"
echo "URL: https://generativelanguage.googleapis.com/v1beta/models"
echo ""

api_response=$(curl -sS --max-time $TIMEOUT \
    -H "Content-Type: application/json" \
    -w "\n===HTTP_CODE:%{http_code}===\n===SIZE:%{size_download}===" \
    "https://generativelanguage.googleapis.com/v1beta/models" 2>&1)

api_code=$(echo "$api_response" | grep "===HTTP_CODE:" | cut -d: -f2 | cut -d= -f1)
api_size=$(echo "$api_response" | grep "===SIZE:" | cut -d: -f2 | cut -d= -f1)
api_content=$(echo "$api_response" | sed '/===HTTP_CODE:/d' | sed '/===SIZE:/d')

echo "HTTP 状态码: $api_code"
echo "响应大小: $api_size 字节"
echo ""
echo "完整响应内容:"
echo "---开始---"
echo "$api_content"
echo "---结束---"
echo ""

echo "内容检测:"
echo "  - 包含 'PERMISSION_DENIED': $(echo "$api_content" | grep -qi "PERMISSION_DENIED" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'api key': $(echo "$api_content" | grep -qi "api key" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'unregistered callers': $(echo "$api_content" | grep -qi "unregistered callers" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'established identity': $(echo "$api_content" | grep -qi "established identity" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'country': $(echo "$api_content" | grep -qi "country" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'region': $(echo "$api_content" | grep -qi "region" && echo "✓ 是" || echo "✗ 否")"
echo "  - 是否为 JSON: $(echo "$api_content" | python3 -m json.tool >/dev/null 2>&1 && echo "✓ 是" || echo "✗ 否")"
echo ""

# 判断逻辑
echo "判断逻辑:"
if [ "$api_code" = "401" ] || [ "$api_code" = "400" ]; then
    api_result="success"
    echo "  → HTTP 401/400 = success (需要认证)"
elif [ "$api_code" = "403" ]; then
    echo "  → HTTP 403，检查内容..."

    if echo "$api_content" | grep -qi "PERMISSION_DENIED"; then
        echo "     包含 PERMISSION_DENIED"
        if echo "$api_content" | grep -qi "api key\|unregistered callers\|established identity"; then
            api_result="success"
            echo "     并且包含 api key 相关 → success"
        else
            api_result="access_denied"
            echo "     但不包含 api key 相关 → access_denied"
        fi
    elif echo "$api_content" | grep -qi "country\|region\|territory\|not available\|not supported"; then
        api_result="region_restricted"
        echo "     包含地区关键词 → region_restricted"
    else
        api_result="region_restricted"
        echo "     403 但非 JSON 响应 → region_restricted"
    fi
elif [ "$api_code" = "451" ]; then
    api_result="region_restricted"
    echo "  → HTTP 451 = region_restricted"
else
    echo "  → HTTP $api_code = unknown"
fi

echo ""
echo "✱ API 端点判断结果: $api_result"
echo ""
echo ""

echo "========================================"
echo "【步骤 2/4】主域名检测"
echo "========================================"
echo "URL: https://gemini.google.com/"
echo ""

web_response=$(curl -sS --max-time $TIMEOUT \
    -A "$USER_AGENT" \
    -L \
    -w "\n===HTTP_CODE:%{http_code}===\n===SIZE:%{size_download}===" \
    "https://gemini.google.com/" 2>&1)

web_code=$(echo "$web_response" | grep "===HTTP_CODE:" | cut -d: -f2 | cut -d= -f1)
web_size=$(echo "$web_response" | grep "===SIZE:" | cut -d: -f2 | cut -d= -f1)
web_content=$(echo "$web_response" | sed '/===HTTP_CODE:/d' | sed '/===SIZE:/d')

echo "HTTP 状态码: $web_code"
echo "响应大小: $web_size 字节"
echo ""
echo "响应内容 (前 500 字符):"
echo "---开始---"
echo "$web_content" | head -c 500
echo ""
echo "---结束---"
echo ""

echo "内容检测:"
echo "  - 包含 'access denied': $(echo "$web_content" | grep -qi "access denied" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'supported in your country': $(echo "$web_content" | grep -qi "supported in your country" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'not available in your country': $(echo "$web_content" | grep -qi "not available in your country" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'sign in': $(echo "$web_content" | grep -qi "sign in" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'get started': $(echo "$web_content" | grep -qi "get started" && echo "✓ 是" || echo "✗ 否")"
echo "  - 包含 'continue with google': $(echo "$web_content" | grep -qi "continue with google" && echo "✓ 是" || echo "✗ 否")"
echo ""

# 判断逻辑
echo "判断逻辑:"
if [ "$web_code" = "403" ]; then
    echo "  → HTTP 403，检查内容..."
    if echo "$web_content" | grep -qi "access denied"; then
        web_result="region_restricted"
        echo "     包含 'access denied' → region_restricted"
    else
        web_result="access_denied"
        echo "     不包含 'access denied' → access_denied"
    fi
elif echo "$web_content" | grep -qi "supported in your country\|not available in your country"; then
    web_result="region_restricted"
    echo "  → 包含地区限制消息 → region_restricted"
elif [ "$web_code" = "200" ]; then
    echo "  → HTTP 200，检查内容..."
    if echo "$web_content" | grep -qi "sign in\|get started\|continue with google\|chat with gemini"; then
        web_result="success"
        echo "     包含登录界面关键词 → success"
    else
        echo "     不包含登录界面关键词 → unknown"
    fi
else
    echo "  → HTTP $web_code = unknown"
fi

echo ""
echo "✱ 主域名判断结果: $web_result"
echo ""
echo ""

echo "========================================"
echo "【步骤 3/4】静态资源检测"
echo "========================================"
echo "URL: https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg"
echo ""

# 检查是否需要跳过
region_confirmed_1=false
if [ "$api_result" = "region_restricted" ]; then
    region_confirmed_1=true
    echo "✱ API 已确认地区限制: 是"
else
    echo "✱ API 已确认地区限制: 否"
fi

if [ "$web_result" = "region_restricted" ]; then
    region_confirmed_1=true
    echo "✱ 主域名已确认地区限制: 是"
else
    echo "✱ 主域名已确认地区限制: 否"
fi

echo ""

if [ "$region_confirmed_1" = true ]; then
    echo "跳过静态资源检测（已确认地区限制）"
    static_result=""
else
    static_code=$(curl -sS -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        "https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg" 2>&1)

    echo "HTTP 状态码: $static_code"
    echo ""

    echo "判断逻辑:"
    if [ "$static_code" = "403" ]; then
        static_result="region_restricted"
        echo "  → HTTP 403 = region_restricted"
    elif [ "$static_code" = "200" ]; then
        static_result="success"
        echo "  → HTTP 200 = success"
    else
        echo "  → HTTP $static_code = unknown"
    fi

    echo ""
    echo "✱ 静态资源判断结果: $static_result"
fi

echo ""
echo ""

echo "========================================"
echo "【步骤 4/4】AI Studio 检测"
echo "========================================"
echo "URL: https://aistudio.google.com/app/prompts/new_chat"
echo ""

# 检查是否需要跳过
region_confirmed_2=false
if [ "$api_result" = "region_restricted" ] || [ "$web_result" = "region_restricted" ] || [ "$static_result" = "region_restricted" ]; then
    region_confirmed_2=true
fi

echo "✱ 已确认地区限制: $([ "$region_confirmed_2" = true ] && echo "是" || echo "否")"
echo ""

if [ "$region_confirmed_2" = true ]; then
    echo "跳过 AI Studio 检测（已确认地区限制）"
    studio_result=""
else
    studio_code=$(curl -sS -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://aistudio.google.com/app/prompts/new_chat" 2>&1)

    echo "HTTP 状态码: $studio_code"
    echo ""

    echo "判断逻辑:"
    if [ "$studio_code" = "403" ]; then
        studio_result="region_restricted"
        echo "  → HTTP 403 = region_restricted"
    elif [ "$studio_code" = "200" ] || [ "$studio_code" = "302" ]; then
        studio_result="success"
        echo "  → HTTP $studio_code = success"
    else
        echo "  → HTTP $studio_code = unknown"
    fi

    echo ""
    echo "✱ AI Studio 判断结果: $studio_result"
fi

echo ""
echo ""

echo "========================================"
echo "【最终决策】"
echo "========================================"
echo ""
echo "各端点结果汇总:"
echo "  - API 端点:    $api_result"
echo "  - 主域名:      $web_result"
echo "  - 静态资源:    $static_result"
echo "  - AI Studio:   $studio_result"
echo ""

echo "决策逻辑:"
echo ""

# Priority 1: Region restriction
echo "优先级 1: 检查地区限制"
if [ "$api_result" = "region_restricted" ]; then
    echo "  ✓ API 端点 = region_restricted"
    final_result="failed"
    final_detail="该地区不支持 (from API)"
elif [ "$web_result" = "region_restricted" ]; then
    echo "  ✓ 主域名 = region_restricted"
    final_result="failed"
    final_detail="该地区不支持 (from Web)"
elif [ "$static_result" = "region_restricted" ]; then
    echo "  ✓ 静态资源 = region_restricted"
    final_result="failed"
    final_detail="该地区不支持 (from Static)"
elif [ "$studio_result" = "region_restricted" ]; then
    echo "  ✓ AI Studio = region_restricted"
    final_result="failed"
    final_detail="该地区不支持 (from Studio)"
else
    echo "  ✗ 无地区限制"

    # Priority 2: Success
    echo ""
    echo "优先级 2: 检查成功访问"
    if [ "$api_result" = "success" ]; then
        echo "  ✓ API 端点 = success"
        final_result="success"
        final_detail="正常访问 (from API)"
    elif [ "$web_result" = "success" ]; then
        echo "  ✓ 主域名 = success"
        final_result="success"
        final_detail="正常访问 (from Web)"
    elif [ "$static_result" = "success" ]; then
        echo "  ✓ 静态资源 = success"
        final_result="success"
        final_detail="正常访问 (from Static)"
    elif [ "$studio_result" = "success" ]; then
        echo "  ✓ AI Studio = success"
        final_result="success"
        final_detail="正常访问 (from Studio)"
    else
        echo "  ✗ 无成功访问"

        # Priority 3: Other failures
        echo ""
        echo "优先级 3: 其他状态"
        if [ "$api_result" = "access_denied" ]; then
            echo "  ✓ API 端点 = access_denied"
            final_result="failed"
            final_detail="访问被拒"
        else
            echo "  ✗ 无明确状态"
            final_result="error"
            final_detail="检测失败"
        fi
    fi
fi

echo ""
echo "========================================"
echo "🎯 最终结果"
echo "========================================"
echo ""
if [ "$final_result" = "failed" ]; then
    echo "🔴 状态: 失败"
elif [ "$final_result" = "success" ]; then
    echo "🟢 状态: 成功"
else
    echo "⚪ 状态: 错误"
fi
echo "📝 详情: $final_detail"
echo ""
echo "========================================"
echo "请将以上完整输出发送给开发者"
echo "========================================"
