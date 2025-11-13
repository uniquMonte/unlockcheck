#!/bin/bash

echo "========== Following Redirects Debug =========="
echo ""

# Claude with full redirect following
echo "==========================================
"
echo "Service: Claude AI (Following all redirects)"
echo "URL: https://claude.ai/"
echo "=========================================="

response=$(curl -sS -L -w "\nFINAL_URL:%{url_effective}\nHTTP_CODE:%{http_code}\n" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Cache-Control: no-cache" \
    --max-time 10 \
    "https://claude.ai/" 2>&1)

final_url=$(echo "$response" | grep "FINAL_URL:" | cut -d: -f2-)
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
content=$(echo "$response" | grep -v "FINAL_URL:" | grep -v "HTTP_CODE:")

echo ""
echo "Final URL after redirects: $final_url"
echo "HTTP Status Code: $http_code"
echo ""

echo "Page Title:"
title=$(echo "$content" | grep -oP '<title[^>]*>\K[^<]+' | head -1)
echo "   $title"
echo ""

echo "Checking for region restriction in visible content:"
if echo "$content" | grep -qi "not available"; then
    echo "   ✓ FOUND 'not available'"
    echo "$content" | grep -i "not available" | head -5
fi

if echo "$content" | grep -qi "unavailable"; then
    echo "   ✓ FOUND 'unavailable'"
    echo "$content" | grep -i "unavailable" | head -5
fi

if echo "$content" | grep -q "不可用\|不支持"; then
    echo "   ✓ FOUND Chinese restriction"
    echo "$content" | grep "不可用\|不支持" | head -5
fi

echo ""
echo "First 1500 characters:"
echo "---"
echo "$content" | head -c 1500
echo ""
echo "---"
echo ""

echo "Saved to: /tmp/claude_full_redirect.html"
echo "$content" > /tmp/claude_full_redirect.html
echo ""

# Gemini - search in full content
echo "==========================================
"
echo "Service: Gemini (Searching full content)"
echo "=========================================="

response=$(curl -sS -L \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -H "Accept: text/html" \
    --max-time 10 \
    "https://gemini.google.com/" 2>&1)

echo ""
echo "Content size: $(echo "$response" | wc -c) bytes"
echo ""

echo "Searching for region restrictions in JavaScript/HTML:"

# Search for common restriction patterns
if echo "$response" | grep -qi "isn.*t available in your country"; then
    echo "   ✓ FOUND: isn't available in your country"
    echo "$response" | grep -i "isn.*t available in your country" -o | head -3
fi

if echo "$response" | grep -qi "not.*available.*region\|region.*not.*available"; then
    echo "   ✓ FOUND: region not available pattern"
    echo "$response" | grep -iE "not.*available.{0,20}region|region.{0,20}not.*available" -o | head -3
fi

if echo "$response" | grep -qi "Gemini isn"; then
    echo "   ✓ FOUND: 'Gemini isn' pattern"
    echo "$response" | grep -i "Gemini isn" -A 1 | head -5
fi

if echo "$response" | grep -qi "country is not supported"; then
    echo "   ✓ FOUND: country not supported"
    echo "$response" | grep -i "country is not supported" -C 1 | head -3
fi

# Check for data attributes or JSON
if echo "$response" | grep -q '"availableInCountry"'; then
    echo "   ✓ FOUND: availableInCountry in JSON"
    echo "$response" | grep -o '"availableInCountry"[^}]*' | head -3
fi

echo ""
echo "Saved to: /tmp/gemini_full.html"
echo "$response" > /tmp/gemini_full.html
echo ""

# ChatGPT - better Cloudflare detection
echo "==========================================
"
echo "Service: ChatGPT (Cloudflare patterns)"
echo "=========================================="

response=$(curl -sS -L \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    --max-time 10 \
    "https://chatgpt.com/" 2>&1)

echo ""
title=$(echo "$response" | grep -oP '<title[^>]*>\K[^<]+' | head -1)
echo "Page Title: $title"
echo ""

echo "Cloudflare detection patterns:"
if echo "$title" | grep -qi "cloudflare"; then
    echo "   ✓ Title contains 'Cloudflare'"
fi

if echo "$response" | grep -qi "attention required"; then
    echo "   ✓ Contains 'Attention Required'"
fi

if echo "$response" | grep -qi "just a moment"; then
    echo "   ✓ Contains 'Just a moment'"
fi

if echo "$response" | grep -qi "checking your browser"; then
    echo "   ✓ Contains 'Checking your browser'"
fi

echo ""
echo "Saved to: /tmp/chatgpt_full.html"
echo "$response" > /tmp/chatgpt_full.html
echo ""

echo "==========================================
"
echo "Debug complete!"
echo ""
echo "Next steps:"
echo "1. Check if Claude's final URL is a restriction page"
echo "2. Search Gemini HTML for the actual error message"
echo "3. Verify ChatGPT Cloudflare detection"
echo ""
echo "You can also run:"
echo "  grep -i 'available' /tmp/gemini_full.html | head -20"
echo "  grep -i 'region' /tmp/gemini_full.html | head -20"
echo "==========================================
"
