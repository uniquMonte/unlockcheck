#!/bin/bash

echo "========== Detailed AI Service Detection Debug =========="
echo ""

# Claude
echo "========== Claude AI =========="
echo "URL: https://claude.ai/"
echo ""
response=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
  -H "Accept-Language: en-US,en;q=0.9" \
  -H "Cache-Control: no-cache" \
  --max-time 10 \
  "https://claude.ai/" 2>&1)

status_code=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_STATUS:")

echo "HTTP Status: $status_code"
echo ""
echo "Response size: $(echo "$content" | wc -c) bytes"
echo ""
echo "Title tag:"
echo "$content" | grep -o '<title>[^<]*</title>' | head -1
echo ""
echo "Cloudflare check:"
if echo "$content" | grep -qi "just a moment"; then
    echo "  ✓ Found Cloudflare challenge"
else
    echo "  ✗ No Cloudflare challenge"
fi
echo ""
echo "First 500 chars:"
echo "$content" | head -c 500
echo ""
echo ""

# Gemini
echo "========== Gemini AI =========="
echo "URL: https://gemini.google.com/"
echo ""
response=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
  -H "Accept-Language: en-US,en;q=0.9" \
  -H "Cache-Control: no-cache" \
  --max-time 10 \
  "https://gemini.google.com/" 2>&1)

status_code=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_STATUS:")

echo "HTTP Status: $status_code"
echo ""
echo "Response size: $(echo "$content" | wc -c) bytes"
echo ""
echo "Title tag:"
echo "$content" | grep -o '<title>[^<]*</title>' | head -1
echo ""
echo "Region restriction check:"
if echo "$content" | grep -qi "not available in your"; then
    echo "  ✓ Found region restriction message"
    echo "$content" | grep -i "not available" | head -3
else
    echo "  ✗ No obvious region restriction"
fi
echo ""
echo "First 500 chars:"
echo "$content" | head -c 500
echo ""
echo ""

# ChatGPT
echo "========== ChatGPT =========="
echo "URL: https://chatgpt.com/"
echo ""
response=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
  -H "Accept-Language: en-US,en;q=0.9" \
  -H "Cache-Control: no-cache" \
  --max-time 10 \
  "https://chatgpt.com/" 2>&1)

status_code=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_STATUS:")

echo "HTTP Status: $status_code"
echo ""
echo "Response size: $(echo "$content" | wc -c) bytes"
echo ""
echo "Title tag:"
echo "$content" | grep -o '<title>[^<]*</title>' | head -1
echo ""
echo "Cloudflare check:"
if echo "$content" | grep -qi "just a moment"; then
    echo "  ✓ Found Cloudflare challenge"
else
    echo "  ✗ No Cloudflare challenge"
fi
echo ""
echo "First 500 chars:"
echo "$content" | head -c 500
echo ""
