#!/bin/bash

echo "========== AI Services Region Restriction Debug =========="
echo "This script will help identify the exact error messages"
echo ""

# Function to analyze a service
analyze_service() {
    local name="$1"
    local url="$2"

    echo "=========================================="
    echo "Service: $name"
    echo "URL: $url"
    echo "=========================================="

    response=$(curl -sS -w "\nHTTP_CODE:%{http_code}\n" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Cache-Control: no-cache, no-store, must-revalidate" \
        -H "Pragma: no-cache" \
        --max-time 10 \
        "$url" 2>&1)

    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    content=$(echo "$response" | grep -v "HTTP_CODE:")

    echo ""
    echo "1. HTTP Status Code: $http_code"
    echo ""

    echo "2. Page Title:"
    title=$(echo "$content" | grep -oP '<title[^>]*>\K[^<]+' | head -1)
    if [ -n "$title" ]; then
        echo "   $title"
    else
        echo "   (No title found)"
    fi
    echo ""

    echo "3. Content Size: $(echo "$content" | wc -c) bytes"
    echo ""

    echo "4. Cloudflare Detection:"
    if echo "$content" | grep -qi "just a moment\|checking your browser"; then
        echo "   ✓ FOUND Cloudflare challenge page"
    else
        echo "   ✗ No Cloudflare challenge"
    fi
    echo ""

    echo "5. Region Restriction Patterns:"
    echo "   Searching for common restriction messages..."

    # English patterns
    if echo "$content" | grep -qi "not available in your region"; then
        echo "   ✓ FOUND: 'not available in your region'"
        echo "      Context:"
        echo "$content" | grep -i "not available in your region" -C 2 | head -10
    fi

    if echo "$content" | grep -qi "not available in your country"; then
        echo "   ✓ FOUND: 'not available in your country'"
        echo "      Context:"
        echo "$content" | grep -i "not available in your country" -C 2 | head -10
    fi

    if echo "$content" | grep -qi "unavailable in your"; then
        echo "   ✓ FOUND: 'unavailable in your'"
        echo "      Context:"
        echo "$content" | grep -i "unavailable in your" -C 2 | head -10
    fi

    if echo "$content" | grep -qi "isn't available"; then
        echo "   ✓ FOUND: 'isn't available'"
        echo "      Context:"
        echo "$content" | grep -i "isn't available" -C 2 | head -10
    fi

    if echo "$content" | grep -qi "is not available"; then
        echo "   ✓ FOUND: 'is not available'"
        echo "      Context:"
        echo "$content" | grep -i "is not available" -C 2 | head -10
    fi

    # Chinese patterns
    if echo "$content" | grep -q "不可用\|不支持\|無法使用"; then
        echo "   ✓ FOUND: Chinese restriction message"
        echo "      Context:"
        echo "$content" | grep "不可用\|不支持\|無法使用" -C 2 | head -10
    fi

    echo ""
    echo "6. First 1000 characters of HTML:"
    echo "---"
    echo "$content" | head -c 1000
    echo ""
    echo "---"
    echo ""

    echo "7. Save full response to file for inspection:"
    filename="/tmp/${name// /_}_response.html"
    echo "$content" > "$filename"
    echo "   Saved to: $filename"
    echo "   You can open this file in a browser to see exactly what curl receives"
    echo ""
    echo ""
}

# Analyze each service
analyze_service "Claude AI" "https://claude.ai/"
analyze_service "Gemini" "https://gemini.google.com/"
analyze_service "ChatGPT" "https://chatgpt.com/"

echo "=========================================="
echo "Debug Complete!"
echo ""
echo "INSTRUCTIONS:"
echo "1. Review the patterns found above"
echo "2. Check the saved HTML files in /tmp/ with a browser"
echo "3. Compare with what you see in your actual browser"
echo "4. Share the output with me so I can fix the detection logic"
echo "=========================================="
