#!/bin/bash

echo "=========================================="
echo "Gemini 隐藏指标深度搜索"
echo "=========================================="
echo ""

# Fetch fresh response
echo "【步骤 1】获取新的 Gemini 响应..."
response=$(curl -sS -L \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    --max-time 10 \
    "https://gemini.google.com/" 2>&1)

echo "$response" > /tmp/gemini_search.html
echo "✓ 响应已保存到: /tmp/gemini_search.html"
echo "  大小: $(echo "$response" | wc -c) 字节"
echo ""

# Search 1: Look for country/region data attributes
echo "【搜索 1】数据属性 (data-*, aria-*)"
echo "---"
if grep -oP 'data-[a-z-]*="[^"]*"' /tmp/gemini_search.html | grep -iE "country|region|locale|location|geo|available|support" | head -10; then
    echo ""
else
    echo "✗ 未找到相关数据属性"
fi
echo ""

# Search 2: Look for JSON config
echo "【搜索 2】JavaScript 配置对象"
echo "---"
if grep -oP '\{[^}]{0,200}(country|region|available|supported|locale)[^}]{0,200}\}' /tmp/gemini_search.html | head -5; then
    echo ""
else
    echo "✗ 未找到相关 JSON 配置"
fi
echo ""

# Search 3: Look for specific keywords
echo "【搜索 3】关键词搜索"
echo "---"
keywords=("HK" "Hong Kong" "香港" "supported" "available" "restricted" "blocked" "region" "country" "territory")
for keyword in "${keywords[@]}"; do
    count=$(grep -i "$keyword" /tmp/gemini_search.html | wc -l)
    if [ $count -gt 0 ]; then
        echo "  ✓ '$keyword': 找到 $count 次"
        if [ $count -lt 5 ]; then
            echo "    上下文:"
            grep -i "$keyword" /tmp/gemini_search.html | head -2 | sed 's/^/      /'
        fi
    fi
done
echo ""

# Search 4: Look for URLs that might indicate region
echo "【搜索 4】URL 模式"
echo "---"
if grep -oP 'https?://[^"'\'' ]+' /tmp/gemini_search.html | grep -iE "country|region|geo|location|locale" | head -10; then
    echo ""
else
    echo "✗ 未找到相关 URL"
fi
echo ""

# Search 5: Look for meta tags
echo "【搜索 5】Meta 标签"
echo "---"
if grep -i '<meta' /tmp/gemini_search.html | grep -iE "country|region|geo|available" | head -10; then
    echo ""
else
    echo "✗ 未找到相关 meta 标签"
fi
echo ""

# Search 6: Look for script sources
echo "【搜索 6】脚本文件 URL"
echo "---"
echo "检查是否加载了特定的 JavaScript 文件..."
grep -oP '<script[^>]+src="[^"]+"' /tmp/gemini_search.html | head -10
echo ""

# Search 7: Look for window/global variables
echo "【搜索 7】全局变量和配置"
echo "---"
if grep -oP 'window\.[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*[^;]{0,100}' /tmp/gemini_search.html | grep -iE "country|region|config|init" | head -10; then
    echo ""
else
    echo "✗ 未找到相关全局变量"
fi
echo ""

# Search 8: Check response headers
echo "【搜索 8】响应头信息"
echo "---"
echo "获取带 headers 的响应..."
headers=$(curl -sS -I -L \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    --max-time 10 \
    "https://gemini.google.com/" 2>&1)

echo "$headers" | grep -iE "country|region|location|geo|x-" | while read line; do
    echo "  $line"
done
echo ""

# Search 9: Look for noscript content
echo "【搜索 9】<noscript> 内容"
echo "---"
if grep -oP '<noscript>.*?</noscript>' /tmp/gemini_search.html | head -5; then
    echo ""
else
    echo "✗ 未找到 noscript 内容"
fi
echo ""

# Search 10: Alternative API endpoints
echo "【搜索 10】尝试其他 API 端点"
echo "---"
echo "测试: https://gemini.google.com/app"
app_response=$(curl -sS -w "\nHTTP:%{http_code}" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    --max-time 10 \
    "https://gemini.google.com/app" 2>&1)

app_code=$(echo "$app_response" | grep "HTTP:" | cut -d: -f2)
echo "  HTTP 状态码: $app_code"

if echo "$app_response" | grep -qi "not.*available\|not.*supported\|restricted"; then
    echo "  ✓ 在 /app 路径找到限制信息："
    echo "$app_response" | grep -i "not.*available\|not.*supported\|restricted" | head -3
fi
echo ""

# Final analysis
echo "=========================================="
echo "【分析总结】"
echo "=========================================="
echo ""

# Check if we found any indicators
found_indicator=false

if grep -qi "supported in your country\|not available in your country\|isn't currently supported" /tmp/gemini_search.html; then
    echo "✓ 在 HTML 中找到明确的地区限制消息"
    found_indicator=true
fi

if grep -i "HK\|Hong Kong\|香港" /tmp/gemini_search.html | grep -qi "not.*support\|restrict\|unavailable"; then
    echo "✓ 找到与香港相关的限制信息"
    found_indicator=true
fi

if [ "$found_indicator" = false ]; then
    echo "✗ 未在初始 HTML 响应中找到任何地区限制指标"
    echo ""
    echo "【结论】"
    echo "  该限制是纯客户端 JavaScript 实现："
    echo "  1. 页面加载后，JavaScript 检测用户位置"
    echo "  2. 然后动态显示限制消息"
    echo "  3. curl/requests 无法执行 JavaScript，因此看不到这个消息"
    echo ""
    echo "【可能的解决方案】"
    echo "  Option A: 基于 API 可用性判断 (当前: API 可用 = 显示正常访问)"
    echo "  Option B: 维护地区黑名单 (硬编码受限国家列表)"
    echo "  Option C: 详细状态显示 (API: 可用，网页: 可能受限)"
    echo "  Option D: 使用 IP 地理位置判断 (检查当前 IP 的国家码)"
    echo ""
fi

echo "=========================================="
echo "详细 HTML 已保存到: /tmp/gemini_search.html"
echo "可以手动查看: less /tmp/gemini_search.html"
echo "=========================================="
