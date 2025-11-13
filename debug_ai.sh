#!/bin/bash
#
# Debug script for AI service detection
# 用于调试AI服务检测问题
#

USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
TIMEOUT=10

echo "================================================================"
echo "AI Service Detection Debug Tool"
echo "================================================================"
echo ""

# 检测 ChatGPT
echo "=== Testing ChatGPT (https://chat.openai.com/) ==="
echo "Fetching..."
response=$(curl -s --max-time $TIMEOUT \
    -A "$USER_AGENT" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -L \
    -w "\n---HTTP_STATUS---\n%{http_code}" \
    "https://chat.openai.com/" 2>/dev/null)

status_code=$(echo "$response" | tail -n 1)
content=$(echo "$response" | sed -n '1,/---HTTP_STATUS---/p' | head -n -1)

echo "HTTP Status Code: $status_code"
echo ""
echo "Response length: $(echo "$content" | wc -c) bytes"
echo ""
echo "First 600 characters of response:"
echo "----------------------------------------"
echo "$content" | head -c 600
echo ""
echo "----------------------------------------"
echo ""
echo "Checking for error patterns:"
if echo "$content" | grep -qi "not available in your country"; then
    echo "  ✗ FOUND: 'not available in your country'"
else
    echo "  ✓ NOT FOUND: 'not available in your country'"
fi
if echo "$content" | grep -qi "unavailable in your country"; then
    echo "  ✗ FOUND: 'unavailable in your country'"
else
    echo "  ✓ NOT FOUND: 'unavailable in your country'"
fi
if echo "$content" | grep -qi "not supported.*country"; then
    echo "  ✗ FOUND: 'not supported...country'"
else
    echo "  ✓ NOT FOUND: 'not supported...country'"
fi
echo ""
echo "Detection logic result:"
if echo "$content" | grep -qi "not available in your country\|unavailable in your country"; then
    echo "  → 该地区不支持 (ERROR: found 'not available' pattern)"
elif echo "$content" | grep -qi "chatgpt.*not supported in.*country\|openai.*not supported"; then
    echo "  → 该地区不支持 (ERROR: found 'not supported' pattern)"
elif [ "$status_code" = "403" ]; then
    echo "  → 该地区不支持 (ERROR: HTTP 403)"
elif [ "$status_code" = "200" ]; then
    echo "  → 正常访问 (OK: HTTP 200 with no error patterns)"
else
    echo "  → 检测失败 (ERROR: HTTP $status_code)"
fi

echo ""
echo "================================================================"
echo ""

# 检测 Claude
echo "=== Testing Claude (https://claude.ai/) ==="
echo "Fetching..."
response=$(curl -s --max-time $TIMEOUT \
    -A "$USER_AGENT" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -L \
    -w "\n---HTTP_STATUS---\n%{http_code}" \
    "https://claude.ai/" 2>/dev/null)

status_code=$(echo "$response" | tail -n 1)
content=$(echo "$response" | sed -n '1,/---HTTP_STATUS---/p' | head -n -1)

echo "HTTP Status Code: $status_code"
echo ""
echo "Response length: $(echo "$content" | wc -c) bytes"
echo ""
echo "First 600 characters of response:"
echo "----------------------------------------"
echo "$content" | head -c 600
echo ""
echo "----------------------------------------"
echo ""
echo "Checking for error patterns:"
if echo "$content" | grep -qi "only available in certain regions"; then
    echo "  ✗ FOUND: 'only available in certain regions'"
else
    echo "  ✓ NOT FOUND: 'only available in certain regions'"
fi
if echo "$content" | grep -q "應用程式不可用\|僅在特定地區提供服務"; then
    echo "  ✗ FOUND: Chinese error message"
else
    echo "  ✓ NOT FOUND: Chinese error message"
fi
if echo "$content" | grep -qi "not available in your region\|not available in your country"; then
    echo "  ✗ FOUND: 'not available in your region/country'"
else
    echo "  ✓ NOT FOUND: 'not available in your region/country'"
fi
echo ""
echo "Detection logic result:"
if echo "$content" | grep -qi "only available in certain regions"; then
    echo "  → 该地区不支持 (ERROR: found 'only available in certain regions')"
elif echo "$content" | grep -q "應用程式不可用\|僅在特定地區提供服務"; then
    echo "  → 该地区不支持 (ERROR: found Chinese error)"
elif echo "$content" | grep -qi "not available in your region\|not available in your country\|unavailable in your region"; then
    echo "  → 该地区不支持 (ERROR: found 'not available' pattern)"
elif [ "$status_code" = "403" ]; then
    echo "  → 该地区不支持 (ERROR: HTTP 403)"
elif [ "$status_code" = "200" ]; then
    echo "  → 正常访问 (OK: HTTP 200 with no error patterns)"
else
    echo "  → 检测失败 (ERROR: HTTP $status_code)"
fi

echo ""
echo "================================================================"
echo "Debug completed. Please share the output above if you need help."
echo "================================================================"
