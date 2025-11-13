#!/bin/bash

echo "========== Testing API Endpoints for Region Detection =========="
echo ""

# Test Claude API
echo "=========================================="
echo "1. Claude API Endpoint"
echo "URL: https://api.anthropic.com"
echo "=========================================="
echo ""

# Try to access API endpoint (should return error about missing API key, not region block)
response=$(curl -sS -w "\nHTTP_CODE:%{http_code}\n" \
    -H "Content-Type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    --max-time 10 \
    "https://api.anthropic.com/v1/messages" 2>&1)

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_CODE:")

echo "HTTP Status Code: $http_code"
echo ""
echo "Response:"
echo "$content" | head -c 500
echo ""
echo ""

if [ "$http_code" = "401" ] || [ "$http_code" = "400" ]; then
    echo "✓ API endpoint accessible (authentication error is expected)"
    echo "  This means Claude API is available in this region"
elif [ "$http_code" = "403" ]; then
    if echo "$content" | grep -qi "region\|country\|location\|available"; then
        echo "✗ Region blocked - API returned 403 with region restriction"
    else
        echo "? API returned 403 but reason unclear"
        echo "  Need to check response content"
    fi
elif [ "$http_code" = "451" ]; then
    echo "✗ Region blocked - HTTP 451 (Unavailable For Legal Reasons)"
else
    echo "? Unexpected status code: $http_code"
fi

echo ""
echo "---"
echo ""

# Test ChatGPT/OpenAI API
echo "=========================================="
echo "2. OpenAI API Endpoint"
echo "URL: https://api.openai.com"
echo "=========================================="
echo ""

response=$(curl -sS -w "\nHTTP_CODE:%{http_code}\n" \
    -H "Content-Type: application/json" \
    --max-time 10 \
    "https://api.openai.com/v1/models" 2>&1)

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_CODE:")

echo "HTTP Status Code: $http_code"
echo ""
echo "Response:"
echo "$content" | head -c 500
echo ""
echo ""

if [ "$http_code" = "401" ]; then
    echo "✓ API endpoint accessible (authentication error is expected)"
    echo "  This means OpenAI API is available in this region"
elif [ "$http_code" = "403" ]; then
    if echo "$content" | grep -qi "region\|country\|location"; then
        echo "✗ Region blocked"
    else
        echo "? API returned 403 - checking if it's Cloudflare..."
        if echo "$content" | grep -qi "cloudflare\|attention required"; then
            echo "  Cloudflare blocking API access"
        fi
    fi
elif [ "$http_code" = "451" ]; then
    echo "✗ Region blocked - HTTP 451"
else
    echo "? Unexpected status code: $http_code"
fi

echo ""
echo "---"
echo ""

# Test Google AI API (Gemini)
echo "=========================================="
echo "3. Google AI API Endpoint (Gemini)"
echo "URL: https://generativelanguage.googleapis.com"
echo "=========================================="
echo ""

response=$(curl -sS -w "\nHTTP_CODE:%{http_code}\n" \
    -H "Content-Type: application/json" \
    --max-time 10 \
    "https://generativelanguage.googleapis.com/v1beta/models" 2>&1)

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
content=$(echo "$response" | grep -v "HTTP_CODE:")

echo "HTTP Status Code: $http_code"
echo ""
echo "Response:"
echo "$content" | head -c 500
echo ""
echo ""

if [ "$http_code" = "401" ] || [ "$http_code" = "400" ] || [ "$http_code" = "403" ]; then
    # Check if it's an authentication error or region block
    if echo "$content" | grep -qi "API key\|authentication\|unauthorized"; then
        echo "✓ API endpoint accessible (authentication error is expected)"
        echo "  This means Google AI API is available in this region"
    elif echo "$content" | grep -qi "not available.*region\|not available.*country"; then
        echo "✗ Region blocked by API"
    else
        echo "? Status $http_code - checking content..."
        echo "$content"
    fi
elif [ "$http_code" = "200" ]; then
    echo "✓ API endpoint accessible"
else
    echo "? Unexpected status code: $http_code"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "The API endpoint method is more reliable because:"
echo "1. No Cloudflare JavaScript challenges"
echo "2. Clear JSON error responses"
echo "3. Direct indication of regional availability"
echo ""
echo "Expected behaviors:"
echo "- Available region: HTTP 401 (missing API key) or 400 (bad request)"
echo "- Blocked region: HTTP 403 with region message, or HTTP 451"
echo ""
