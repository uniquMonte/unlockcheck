#!/bin/bash

echo "=========================================="
echo "Gemini 地区限制消息搜索"
echo "=========================================="
echo ""

web_response=$(curl -sS -L \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    --max-time 10 \
    "https://gemini.google.com/" 2>&1)

echo "响应大小: $(echo "$web_response" | wc -c) 字节"
echo ""

echo "【搜索 1】完整的错误消息"
echo "---"
if echo "$web_response" | grep -qi "isn't currently supported in your country"; then
    echo "✓ 找到完整消息！"
    echo "$web_response" | grep -i "isn't currently supported in your country" -C 3
else
    echo "✗ 未找到"
fi

echo ""
echo "【搜索 2】分段搜索 - 'isn't currently supported'"
if echo "$web_response" | grep -qi "isn't currently supported"; then
    echo "✓ 找到 'isn't currently supported'"
    echo "$web_response" | grep -i "isn't currently supported" -C 2 | head -20
else
    echo "✗ 未找到"
fi

echo ""
echo "【搜索 3】分段搜索 - 'supported in your country'"
if echo "$web_response" | grep -qi "supported in your country"; then
    echo "✓ 找到 'supported in your country'"
    echo "$web_response" | grep -i "supported in your country" -C 2 | head -20
else
    echo "✗ 未找到"
fi

echo ""
echo "【搜索 4】搜索 'Gemini' 和 'supported'"
if echo "$web_response" | grep -i "gemini" | grep -qi "supported"; then
    echo "✓ 找到包含 'Gemini' 和 'supported' 的行"
    echo "$web_response" | grep -i "gemini" | grep -i "supported" | head -10
else
    echo "✗ 未找到"
fi

echo ""
echo "【搜索 5】搜索 'currently supported'"
if echo "$web_response" | grep -qi "currently supported"; then
    echo "✓ 找到 'currently supported'"
    echo "$web_response" | grep -i "currently supported" -C 2 | head -20
else
    echo "✗ 未找到"
fi

echo ""
echo "【搜索 6】保存完整响应并手动查找"
echo "$web_response" > /tmp/gemini_full_response.html
echo "完整响应已保存到: /tmp/gemini_full_response.html"
echo ""
echo "手动搜索命令："
echo "  grep -i 'supported' /tmp/gemini_full_response.html | grep -i 'country'"
echo "  grep -i 'gemini' /tmp/gemini_full_response.html | grep -i 'country'"
echo "  grep -i 'isn.*t' /tmp/gemini_full_response.html | grep -i 'supported'"
echo ""

echo "【搜索 7】使用更宽泛的模式"
if grep -iE "(isn't|is not|not).{0,30}(available|supported)" /tmp/gemini_full_response.html | grep -qi "country\|region"; then
    echo "✓ 找到相关消息（宽泛搜索）："
    grep -iE "(isn't|is not|not).{0,30}(available|supported)" /tmp/gemini_full_response.html | grep -i "country\|region" | head -5
else
    echo "✗ 未找到"
fi

echo ""
echo "=========================================="
