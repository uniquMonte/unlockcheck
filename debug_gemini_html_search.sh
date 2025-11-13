#!/bin/bash

echo "========================================"
echo "Gemini HTML 深度内容搜索"
echo "========================================"
echo ""

TIMEOUT=10
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

echo "【步骤 1】获取完整 HTML 内容..."
curl -sS --max-time $TIMEOUT \
    -A "$USER_AGENT" \
    -L \
    "https://gemini.google.com/" > /tmp/gemini_full.html

file_size=$(wc -c < /tmp/gemini_full.html)
echo "✓ HTML 已保存到: /tmp/gemini_full.html"
echo "  文件大小: $file_size 字节"
echo ""

echo "========================================"
echo "【步骤 2】搜索地区限制关键词"
echo "========================================"
echo ""

# 搜索模式列表
search_patterns=(
    "isn't currently supported"
    "not currently supported"
    "not available in your country"
    "supported in your country"
    "not available in your region"
    "available in your region"
    "region is not supported"
    "country is not supported"
    "geographic restriction"
    "geographical restriction"
    "location.*not.*support"
    "unavailable.*country"
    "unavailable.*region"
    "blocked.*country"
    "blocked.*region"
    "restricted.*country"
    "restricted.*region"
    "access.*denied"
    "Stay tuned"
)

echo "搜索以下关键词模式:"
found_any=false

for pattern in "${search_patterns[@]}"; do
    result=$(grep -i -o -E ".{0,80}${pattern}.{0,80}" /tmp/gemini_full.html | head -3)
    if [ -n "$result" ]; then
        echo ""
        echo "✓ 找到: '$pattern'"
        echo "  上下文:"
        echo "$result" | sed 's/^/    /'
        found_any=true
    fi
done

if [ "$found_any" = false ]; then
    echo ""
    echo "✗ 未找到任何明显的地区限制关键词"
fi

echo ""
echo ""

echo "========================================"
echo "【步骤 3】搜索 JavaScript 地理位置检测"
echo "========================================"
echo ""

echo "搜索地理位置相关的 JavaScript 代码..."
echo ""

# 搜索 JavaScript 中的地理位置代码
js_patterns=(
    "countryCode"
    "country_code"
    "geoLocation"
    "geolocation"
    "navigator\.language"
    "Intl\.DateTimeFormat"
    "availableCountries"
    "supportedCountries"
    "allowedCountries"
    "blockedCountries"
    "restrictedCountries"
    "HK\|CN\|TW\|MO"
)

for pattern in "${js_patterns[@]}"; do
    result=$(grep -i -o -E ".{0,100}${pattern}.{0,100}" /tmp/gemini_full.html | head -2)
    if [ -n "$result" ]; then
        echo "✓ 找到: '$pattern'"
        echo "  代码片段:"
        echo "$result" | sed 's/^/    /'
        echo ""
    fi
done

echo ""

echo "========================================"
echo "【步骤 4】提取所有包含 'country' 的行"
echo "========================================"
echo ""

country_lines=$(grep -i "country" /tmp/gemini_full.html | head -10)
if [ -n "$country_lines" ]; then
    echo "找到包含 'country' 的内容 (前 10 行):"
    echo "$country_lines" | sed 's/^/  /'
else
    echo "✗ 未找到包含 'country' 的内容"
fi

echo ""
echo ""

echo "========================================"
echo "【步骤 5】提取所有包含 'region' 的行"
echo "========================================"
echo ""

region_lines=$(grep -i "region" /tmp/gemini_full.html | head -10)
if [ -n "$region_lines" ]; then
    echo "找到包含 'region' 的内容 (前 10 行):"
    echo "$region_lines" | sed 's/^/  /'
else
    echo "✗ 未找到包含 'region' 的内容"
fi

echo ""
echo ""

echo "========================================"
echo "【步骤 6】搜索 data 属性"
echo "========================================"
echo ""

echo "搜索可能包含地区信息的 data 属性..."
data_attrs=$(grep -o -E 'data-[a-z-]*="[^"]*"' /tmp/gemini_full.html | grep -i -E "country|region|location|geo|available|support|allow|block|restrict" | head -20)

if [ -n "$data_attrs" ]; then
    echo "找到相关 data 属性:"
    echo "$data_attrs" | sed 's/^/  /'
else
    echo "✗ 未找到相关 data 属性"
fi

echo ""
echo ""

echo "========================================"
echo "【步骤 7】检查 meta 标签"
echo "========================================"
echo ""

meta_tags=$(grep -i '<meta' /tmp/gemini_full.html | grep -v 'charset\|viewport\|robots' | head -10)
if [ -n "$meta_tags" ]; then
    echo "Meta 标签 (前 10 个):"
    echo "$meta_tags" | sed 's/^/  /'
else
    echo "✗ 未找到特殊 meta 标签"
fi

echo ""
echo ""

echo "========================================"
echo "【步骤 8】搜索初始化配置"
echo "========================================"
echo ""

echo "搜索可能的初始化配置对象..."
config_patterns=(
    "window\.__INITIAL_DATA__"
    "window\.__INITIAL_STATE__"
    "window\.WIZ_global_data"
    "_CONFIG\s*="
    "INITIAL_CONFIG"
    "APP_CONFIG"
)

for pattern in "${config_patterns[@]}"; do
    result=$(grep -o -E ".{0,200}${pattern}.{0,200}" /tmp/gemini_full.html | head -1)
    if [ -n "$result" ]; then
        echo "✓ 找到配置: '$pattern'"
        echo "  内容:"
        echo "$result" | sed 's/^/    /'
        echo ""
    fi
done

echo ""

echo "========================================"
echo "【步骤 9】统计信息"
echo "========================================"
echo ""

echo "HTML 文件统计:"
echo "  - 总字符数: $(wc -c < /tmp/gemini_full.html)"
echo "  - 总行数: $(wc -l < /tmp/gemini_full.html)"
echo "  - 包含 'script' 标签: $(grep -c '<script' /tmp/gemini_full.html)"
echo "  - 包含 'Gemini' 文本: $(grep -c -i 'gemini' /tmp/gemini_full.html)"
echo "  - 包含 'Google' 文本: $(grep -c 'Google' /tmp/gemini_full.html)"
echo ""

echo "========================================"
echo "【步骤 10】保存供手动检查"
echo "========================================"
echo ""
echo "完整 HTML 文件已保存: /tmp/gemini_full.html"
echo ""
echo "手动搜索命令:"
echo "  grep -i 'isn.*support' /tmp/gemini_full.html"
echo "  grep -i 'country' /tmp/gemini_full.html | less"
echo "  cat /tmp/gemini_full.html | less"
echo ""
echo "========================================"
