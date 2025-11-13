#!/bin/bash
# Improved AI service detection with smart dual detection
# Priority: Region restriction > Cloudflare > API availability

# ChatGPT detection with dual check
check_chatgpt_improved() {
    local api_result=""
    local has_cloudflare=false

    # Step 1: Check API endpoint
    local api_response=$(curl -s --max-time $TIMEOUT \
        -H "Content-Type: application/json" \
        -w "\n%{http_code}" \
        "https://api.openai.com/v1/models" 2>/dev/null)

    local api_status=$(echo "$api_response" | tail -n 1)
    local api_content=$(echo "$api_response" | head -n -1)

    if [ "$api_status" = "401" ] || [ "$api_status" = "400" ]; then
        api_result="success"
    elif [ "$api_status" = "403" ]; then
        if echo "$api_content" | grep -qi "unsupported_country_region_territory"; then
            api_result="region_restricted"
        elif echo "$api_content" | grep -qi "country\|region\|territory"; then
            api_result="region_restricted"
        elif echo "$api_content" | grep -qi "cloudflare\|attention required"; then
            has_cloudflare=true
        else
            api_result="access_denied"
        fi
    elif [ "$api_status" = "451" ]; then
        api_result="region_restricted"
    fi

    # Step 2: Check web if needed
    if [ "$has_cloudflare" = "false" ] && [ "$api_result" != "region_restricted" ]; then
        local web_response=$(curl -s --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            -L \
            -w "\n%{http_code}" \
            "https://chatgpt.com/" 2>/dev/null)

        local web_status=$(echo "$web_response" | tail -n 1)
        local web_content=$(echo "$web_response" | head -n -1)

        if [ "$web_status" = "403" ] || [ "$web_status" = "503" ]; then
            if echo "$web_content" | grep -qi "just a moment\|checking your browser\|attention required"; then
                has_cloudflare=true
            fi
        fi
    fi

    # Step 3: Intelligent decision
    if [ "$api_result" = "region_restricted" ]; then
        format_result "ChatGPT" "failed" "N/A" "该地区不支持"
    elif [ "$has_cloudflare" = "true" ]; then
        format_result "ChatGPT" "error" "N/A" "无法检测 (Cloudflare)"
    elif [ "$api_result" = "success" ]; then
        format_result "ChatGPT" "success" "$COUNTRY_CODE" "正常访问"
    elif [ "$api_result" = "access_denied" ]; then
        format_result "ChatGPT" "failed" "N/A" "访问被拒"
    else
        format_result "ChatGPT" "error" "N/A" "检测失败"
    fi
}

# Claude detection with dual check
check_claude_improved() {
    local api_result=""
    local web_result=""
    local has_cloudflare=false

    # Step 1: Check API endpoint
    local api_response=$(curl -s --max-time $TIMEOUT \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -w "\n%{http_code}" \
        "https://api.anthropic.com/v1/messages" 2>/dev/null)

    local api_status=$(echo "$api_response" | tail -n 1)
    local api_content=$(echo "$api_response" | head -n -1)

    if [ "$api_status" = "401" ] || [ "$api_status" = "400" ]; then
        api_result="success"
    elif [ "$api_status" = "403" ]; then
        if echo "$api_content" | grep -qi "request not allowed\|forbidden"; then
            api_result="region_restricted"
        elif echo "$api_content" | grep -qi "region\|country\|territory"; then
            api_result="region_restricted"
        else
            api_result="access_denied"
        fi
    elif [ "$api_status" = "451" ]; then
        api_result="region_restricted"
    fi

    # Step 2: Check web endpoint
    local web_response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://claude.ai/" 2>/dev/null)

    local web_status=$(echo "$web_response" | tail -n 1)
    local web_content=$(echo "$web_response" | head -n -1)

    if [ "$web_status" = "403" ] || [ "$web_status" = "503" ]; then
        if echo "$web_content" | grep -qi "just a moment\|checking your browser"; then
            has_cloudflare=true
        fi
    fi

    if echo "$web_content" | grep -qi "<title>claude - unavailable</title>"; then
        web_result="region_restricted"
    elif echo "$web_content" | grep -q "應用程式不可用\|僅在特定地區提供服務"; then
        web_result="region_restricted"
    fi

    # Step 3: Intelligent decision
    if [ "$api_result" = "region_restricted" ] || [ "$web_result" = "region_restricted" ]; then
        format_result "Claude" "failed" "N/A" "该地区不支持"
    elif [ "$has_cloudflare" = "true" ]; then
        format_result "Claude" "error" "N/A" "无法检测 (Cloudflare)"
    elif [ "$api_result" = "success" ]; then
        format_result "Claude" "success" "$COUNTRY_CODE" "正常访问"
    elif [ "$api_result" = "access_denied" ]; then
        format_result "Claude" "failed" "N/A" "访问被拒"
    else
        format_result "Claude" "error" "N/A" "检测失败"
    fi
}

# Gemini detection with dual check
check_gemini_improved() {
    local api_result=""
    local web_result=""

    # Step 1: Check API endpoint
    local api_response=$(curl -s --max-time $TIMEOUT \
        -H "Content-Type: application/json" \
        -w "\n%{http_code}" \
        "https://generativelanguage.googleapis.com/v1beta/models" 2>/dev/null)

    local api_status=$(echo "$api_response" | tail -n 1)
    local api_content=$(echo "$api_response" | head -n -1)

    if [ "$api_status" = "401" ] || [ "$api_status" = "400" ]; then
        api_result="success"
    elif [ "$api_status" = "403" ]; then
        if echo "$api_content" | grep -qi "PERMISSION_DENIED"; then
            if echo "$api_content" | grep -qi "api key\|unregistered callers\|established identity"; then
                api_result="success"
            else
                api_result="access_denied"
            fi
        elif echo "$api_content" | grep -qi "country\|region\|territory\|not available\|not supported"; then
            api_result="region_restricted"
        else
            api_result="access_denied"
        fi
    elif [ "$api_status" = "451" ]; then
        api_result="region_restricted"
    fi

    # Step 2: Check web endpoint
    local web_response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://gemini.google.com/" 2>/dev/null)

    if echo "$web_response" | grep -qi "supported in your country\|not available in your country"; then
        web_result="region_restricted"
    elif echo "$web_response" | grep -qi "sign in\|get started\|continue with google\|chat with gemini"; then
        web_result="success"
    fi

    # Step 3: Intelligent decision
    if [ "$api_result" = "region_restricted" ] || [ "$web_result" = "region_restricted" ]; then
        format_result "Gemini" "failed" "N/A" "该地区不支持"
    elif [ "$api_result" = "success" ] || [ "$web_result" = "success" ]; then
        format_result "Gemini" "success" "$COUNTRY_CODE" "正常访问"
    elif [ "$api_result" = "access_denied" ]; then
        format_result "Gemini" "failed" "N/A" "访问被拒"
    else
        format_result "Gemini" "error" "N/A" "检测失败"
    fi
}

echo "Improved AI detection functions created"
echo "These functions implement smart dual detection:"
echo "  1. Region restriction (highest priority)"
echo "  2. Cloudflare challenge"
echo "  3. API availability"
echo ""
echo "To integrate into unlockcheck.sh:"
echo "  - Replace check_chatgpt() with check_chatgpt_improved()"
echo "  - Replace check_claude() with check_claude_improved()"
echo "  - Replace check_gemini() with check_gemini_improved()"
