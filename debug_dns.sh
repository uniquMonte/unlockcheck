#!/bin/bash

# DNS 检测调试脚本
# 用于诊断 DNS 解锁检测的准确性

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== DNS 解锁检测调试工具 ===${NC}\n"

# 检查命令可用性
echo -e "${GREEN}1. 检查必要命令:${NC}"
echo -n "  - nslookup: "
if command -v nslookup &> /dev/null; then
    echo -e "${GREEN}✓ 可用${NC}"
    HAS_NSLOOKUP=1
else
    echo -e "${RED}✗ 不可用${NC}"
    HAS_NSLOOKUP=0
fi

echo -n "  - dig: "
if command -v dig &> /dev/null; then
    echo -e "${GREEN}✓ 可用${NC}"
    HAS_DIG=1
else
    echo -e "${RED}✗ 不可用${NC}"
    HAS_DIG=0
fi

# 测试域名列表
DOMAINS=("gemini.google.com" "reddit.com" "imgur.com")

echo -e "\n${GREEN}2. 测试 DNS 解析:${NC}\n"

for domain in "${DOMAINS[@]}"; do
    echo -e "${YELLOW}━━━ 测试: $domain ━━━${NC}"

    # 测试 nslookup
    if [ $HAS_NSLOOKUP -eq 1 ]; then
        echo -e "${GREEN}nslookup $domain:${NC}"
        nslookup_output=$(nslookup "$domain" 2>&1)
        echo "$nslookup_output"

        # 提取IP地址
        ip_line=$(echo "$nslookup_output" | grep -A 10 "Name:" | grep -E "Address:|address:" | tail -1 | awk '{print $2}')
        if [ -n "$ip_line" ]; then
            echo -e "  → 解析到的IP: ${GREEN}$ip_line${NC}"

            # 检查IP类型
            if [[ $ip_line =~ ^10\. ]]; then
                echo -e "  → IP类型: ${RED}私有IP (10.x.x.x) - DNS解锁特征${NC}"
            elif [[ $ip_line =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
                echo -e "  → IP类型: ${RED}私有IP (172.16-31.x.x) - DNS解锁特征${NC}"
            elif [[ $ip_line =~ ^192\.168\. ]]; then
                echo -e "  → IP类型: ${RED}私有IP (192.168.x.x) - DNS解锁特征${NC}"
            elif [[ $ip_line =~ ^169\.254\. ]]; then
                echo -e "  → IP类型: ${RED}链路本地地址 - DNS解锁特征${NC}"
            else
                echo -e "  → IP类型: ${GREEN}公网IP - 原生解锁${NC}"
            fi
        fi
        echo ""
    fi

    # 测试 dig (随机子域名)
    if [ $HAS_DIG -eq 1 ]; then
        random_subdomain="test$RANDOM$RANDOM.$domain"
        echo -e "${GREEN}dig $random_subdomain (不存在的子域名):${NC}"
        dig_output=$(dig "$random_subdomain" 2>&1)
        echo "$dig_output" | head -20

        # 提取 ANSWER 计数
        answer_count=$(echo "$dig_output" | grep -oP 'ANSWER: \K[0-9]+' | head -1)
        if [ -n "$answer_count" ]; then
            echo -e "  → ANSWER 记录数: ${YELLOW}$answer_count${NC}"
            if [ "$answer_count" = "0" ]; then
                echo -e "  → 判定: ${GREEN}正常DNS - 原生解锁${NC}"
            else
                echo -e "  → 判定: ${RED}DNS劫持 - DNS解锁特征${NC}"
            fi
        fi
        echo ""
    fi

    echo ""
done

echo -e "${YELLOW}=== 检测完成 ===${NC}"
echo ""
echo "说明:"
echo "  - 如果域名解析到私有IP (10.x, 172.16-31.x, 192.168.x)，说明可能是DNS解锁"
echo "  - 如果不存在的子域名返回ANSWER > 0，说明DNS被劫持（SmartDNS特征）"
echo "  - 正常原生解锁应该解析到公网IP，且不存在的子域名ANSWER = 0"
