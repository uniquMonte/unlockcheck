#!/bin/bash

echo "========== Debugging Claude Detection =========="
echo ""

echo "1. Testing Claude.ai homepage..."
echo "--------------------------------"

response=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -H "Cache-Control: no-cache, no-store, must-revalidate" \
  -H "Pragma: no-cache" \
  --max-time 10 \
  "https://claude.ai/" 2>&1)

status_code=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_STATUS:")

echo "HTTP Status Code: $status_code"
echo ""
echo "First 800 characters of response:"
echo "$content" | head -c 800
echo ""
echo ""

echo "2. Checking for Cloudflare patterns..."
echo "---------------------------------------"
if echo "$content" | grep -qi "just a moment"; then
    echo "✓ Found: 'Just a moment'"
fi

if echo "$content" | grep -qi "checking your browser"; then
    echo "✓ Found: 'Checking your browser'"
fi

if echo "$content" | grep -qi "cloudflare"; then
    echo "✓ Found: 'cloudflare' (keyword)"
    echo "   Context:"
    echo "$content" | grep -i "cloudflare" | head -3
fi

if ! echo "$content" | grep -qi "just a moment\|checking your browser\|cloudflare"; then
    echo "✗ No Cloudflare patterns found"
fi

echo ""
echo "3. Checking for region restriction patterns..."
echo "-----------------------------------------------"
if echo "$content" | grep -qi "only available in certain regions"; then
    echo "✓ Found: 'only available in certain regions'"
fi

if echo "$content" | grep -qi "not available in your region\|not available in your country"; then
    echo "✓ Found: region restriction message"
fi

if ! echo "$content" | grep -qi "only available in certain regions\|not available in your region"; then
    echo "✗ No region restriction patterns found"
fi

echo ""
echo "4. Detection logic result..."
echo "----------------------------"

if [ "$status_code" = "403" ] || [ "$status_code" = "503" ]; then
    if echo "$content" | grep -qi "just a moment\|checking your browser"; then
        echo "Result: Cloudflare verification page (anti-bot)"
    else
        echo "Result: Possible region restriction (HTTP $status_code)"
    fi
elif [ "$status_code" = "200" ]; then
    if echo "$content" | grep -qi "only available in certain regions\|not available in your region"; then
        echo "Result: Region restricted"
    else
        echo "Result: Normal access (HTTP 200, no restriction messages)"
    fi
else
    echo "Result: Unexpected status code: $status_code"
fi
