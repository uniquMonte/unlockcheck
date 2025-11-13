#!/bin/bash
#
# StreamCheck - 流媒体解锁检测工具 (Bash 版本)
# 一键检测当前网络环境的流媒体解锁情况
#

VERSION="1.3"
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 全局变量
IP_INFO=""
COUNTRY_CODE=""
CURRENT_IP=""
IP_TYPE="未知"
IP_ISP=""
IP_ASN=""
IP_USAGE_LOCATION=""
IP_REGISTRATION_LOCATION=""

# 打印头部
print_header() {
    echo -e "\n${CYAN}============================================================"
    echo -e "       StreamCheck - 流媒体解锁检测工具 v${VERSION}"
    echo -e "============================================================${NC}\n"
}

# 日志函数
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# 检查依赖
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装 curl"
        exit 1
    fi
}

# DNS解锁检测函数
check_dns_unlock() {
    local domain="$1"

    # 注意：很多服务使用CDN（如Cloudflare），不同DNS返回不同IP是正常的负载均衡
    # 真正的DNS解锁需要更复杂的检测逻辑（检查IP归属、AS号等）
    # 目前暂时禁用DNS解锁检测，避免误报

    echo "native"
    return

    # 以下代码保留，但暂不使用
    # 检查是否有dig命令，如果没有则跳过DNS检测
    if ! command -v dig &> /dev/null; then
        echo "native"
        return
    fi

    # 使用系统默认DNS解析
    local system_dns=$(dig +short +time=2 +tries=1 "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

    # 使用Google公共DNS解析
    local public_dns=$(dig @8.8.8.8 +short +time=2 +tries=1 "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

    # 如果任一解析失败，返回未知
    if [ -z "$system_dns" ] || [ -z "$public_dns" ]; then
        echo "native"
        return
    fi

    # 对比两个DNS解析结果
    if [ "$system_dns" != "$public_dns" ]; then
        echo "dns"  # DNS解锁
    else
        echo "native"  # 原生解锁
    fi
}

# 获取 IP 信息（增强版）
get_ip_info() {
    log_info "正在获取 IP 信息..."

    # 尝试使用 ipapi.co
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://ipapi.co/json/" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
        CURRENT_IP=$(echo "$response" | grep -oP '"ip":"\K[^"]+' | head -1)
        COUNTRY_CODE=$(echo "$response" | grep -oP '"country_code":"\K[^"]+' | head -1)
        local country=$(echo "$response" | grep -oP '"country_name":"\K[^"]+' | head -1)
        local region=$(echo "$response" | grep -oP '"region":"\K[^"]+' | head -1)
        local city=$(echo "$response" | grep -oP '"city":"\K[^"]+' | head -1)
        local isp=$(echo "$response" | grep -oP '"org":"\K[^"]+' | head -1)

        if [ -n "$CURRENT_IP" ] && [ -n "$COUNTRY_CODE" ]; then
            IP_INFO="$country $region $city"
            IP_ISP="$isp"

            # 检测IP类型
            detect_ip_type

            # 打印IP信息
            print_enhanced_ip_info
            return 0
        fi
    fi

    # 备用方案1：使用 ipinfo.io
    response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://ipinfo.io/json" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
        CURRENT_IP=$(echo "$response" | grep -oP '"ip":"\K[^"]+' | head -1)
        COUNTRY_CODE=$(echo "$response" | grep -oP '"country":"\K[^"]+' | head -1)
        local city=$(echo "$response" | grep -oP '"city":"\K[^"]+' | head -1)
        local region=$(echo "$response" | grep -oP '"region":"\K[^"]+' | head -1)
        local isp=$(echo "$response" | grep -oP '"org":"\K[^"]+' | head -1)

        if [ -n "$CURRENT_IP" ] && [ -n "$COUNTRY_CODE" ]; then
            IP_INFO="$region $city"
            IP_ISP="$isp"

            # 检测IP类型
            detect_ip_type

            # 打印IP信息
            print_enhanced_ip_info
            return 0
        fi
    fi

    # 备用方案2：使用 ip-api.com（无需API密钥）
    response=$(curl -s --max-time $TIMEOUT \
        "http://ip-api.com/json/?fields=status,message,country,countryCode,region,city,isp,org,as,query" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
        CURRENT_IP=$(echo "$response" | grep -oP '"query":"\K[^"]+' | head -1)
        COUNTRY_CODE=$(echo "$response" | grep -oP '"countryCode":"\K[^"]+' | head -1)
        local country=$(echo "$response" | grep -oP '"country":"\K[^"]+' | head -1)
        local region=$(echo "$response" | grep -oP '"region":"\K[^"]+' | head -1)
        local city=$(echo "$response" | grep -oP '"city":"\K[^"]+' | head -1)
        local isp=$(echo "$response" | grep -oP '"isp":"\K[^"]+' | head -1)

        if [ -n "$CURRENT_IP" ] && [ -n "$COUNTRY_CODE" ]; then
            IP_INFO="$country $region $city"
            IP_ISP="$isp"

            # 检测IP类型
            detect_ip_type

            # 打印IP信息
            print_enhanced_ip_info
            return 0
        fi
    fi

    # 最后的fallback：只获取IP地址
    CURRENT_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    if [ -z "$CURRENT_IP" ]; then
        CURRENT_IP=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null | tr -d '\n')
    fi

    if [ -n "$CURRENT_IP" ]; then
        log_warning "仅获取到IP地址: ${CURRENT_IP}，无法获取详细位置信息"
        # 即使没有完整信息，也尝试检测IP类型
        detect_ip_type
        echo -e "\n${YELLOW}🌍 当前 IP 信息${NC}"
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo -e "IP 地址: ${GREEN}${CURRENT_IP}${NC}"
        echo -e "IP 类型: ${YELLOW}${IP_TYPE}${NC}"
        echo ""
        return 0
    fi

    log_error "无法获取 IP 信息，将继续检测（区域信息可能不准确）"
    return 1
}

# 检测IP类型（原生IP或广播IP）
detect_ip_type() {
    # 通过 ip-api.com 获取更详细的IP信息
    local ip_detail=$(curl -s --max-time $TIMEOUT \
        "http://ip-api.com/json/${CURRENT_IP}?fields=hosting,proxy,mobile,country,countryCode,regionName,city,isp,org,as" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$ip_detail" ]; then
        local is_hosting=$(echo "$ip_detail" | grep -oP '"hosting":\K(true|false)' | head -1)
        local is_proxy=$(echo "$ip_detail" | grep -oP '"proxy":\K(true|false)' | head -1)
        local is_mobile=$(echo "$ip_detail" | grep -oP '"mobile":\K(true|false)' | head -1)

        # 获取ASN信息（包含注册地）
        IP_ASN=$(echo "$ip_detail" | grep -oP '"as":"\K[^"]+' | head -1)

        # 使用地：IP的实际地理位置（只显示国家）
        local country_code=$(echo "$ip_detail" | grep -oP '"countryCode":"\K[^"]+' | head -1)
        IP_USAGE_LOCATION=$(convert_country_code "$country_code")

        # 注册地：尝试获取IP段注册的国家
        local reg_country=""
        local asn_num=$(echo "$IP_ASN" | grep -oP 'AS\K[0-9]+' | head -1)
        local org=$(echo "$ip_detail" | grep -oP '"org":"\K[^"]+' | head -1)

        # 方法1：根据ASN号码直接判断常见的云服务商
        if [ -n "$asn_num" ]; then
            local asn_country=$(guess_asn_country "$asn_num")
            if [ -n "$asn_country" ] && [ "$asn_country" != "未知" ]; then
                reg_country="$asn_country"
                IP_REGISTRATION_LOCATION=$(convert_country_code "$reg_country")
            fi
        fi

        # 方法2：尝试从 BGPView API 获取（可能被限流）
        if [ -z "$IP_REGISTRATION_LOCATION" ] && [ -n "$asn_num" ]; then
            local asn_info=$(curl -s --max-time 3 "https://api.bgpview.io/asn/${asn_num}" 2>/dev/null)
            reg_country=$(echo "$asn_info" | grep -oP '"country_code":"\K[^"]+' | head -1)

            if [ -n "$reg_country" ]; then
                IP_REGISTRATION_LOCATION=$(convert_country_code "$reg_country")
            fi
        fi

        # 方法3：根据ISP/组织名称判断
        if [ -z "$IP_REGISTRATION_LOCATION" ]; then
            IP_REGISTRATION_LOCATION=$(guess_isp_country "$org")
        fi

        # 判断IP类型：只区分原生IP和广播IP
        # 原生IP的核心特征：注册地和使用地一致
        if [ -n "$reg_country" ] && [ "$country_code" = "$reg_country" ]; then
            # 注册地和使用地一致，是原生IP
            IP_TYPE="原生IP"
        else
            # 其他所有情况都是广播IP（包括hosting、proxy、移动网络、注册地不一致等）
            IP_TYPE="广播IP"
        fi
    else
        IP_TYPE="未知"
    fi

    # 如果IP_USAGE_LOCATION为空，使用COUNTRY_CODE作为备用
    if [ -z "$IP_USAGE_LOCATION" ] && [ -n "$COUNTRY_CODE" ]; then
        IP_USAGE_LOCATION=$(convert_country_code "$COUNTRY_CODE")
    fi
}

# 转换国家代码为国家名
convert_country_code() {
    local code="$1"
    case "$code" in
        "US") echo "美国" ;;
        "CA") echo "加拿大" ;;
        "GB") echo "英国" ;;
        "DE") echo "德国" ;;
        "FR") echo "法国" ;;
        "JP") echo "日本" ;;
        "CN") echo "中国" ;;
        "HK") echo "香港" ;;
        "SG") echo "新加坡" ;;
        "AU") echo "澳大利亚" ;;
        "NL") echo "荷兰" ;;
        "KR") echo "韩国" ;;
        "TW") echo "台湾" ;;
        "IN") echo "印度" ;;
        "BR") echo "巴西" ;;
        "RU") echo "俄罗斯" ;;
        *) echo "$code" ;;
    esac
}

# 根据ASN号码判断常见云服务商的注册国家
guess_asn_country() {
    local asn="$1"
    case "$asn" in
        # Amazon AWS
        16509|14618|8987) echo "US" ;;
        # Google Cloud
        15169|19527|396982) echo "US" ;;
        # Microsoft Azure
        8075|8068) echo "US" ;;
        # Cloudflare
        13335) echo "US" ;;
        # DigitalOcean
        14061) echo "US" ;;
        # Linode
        63949) echo "US" ;;
        # Vultr
        20473) echo "US" ;;
        # OVH
        16276) echo "FR" ;;
        # Hetzner
        24940) echo "DE" ;;
        # Alibaba Cloud
        45102|37963) echo "CN" ;;
        # Tencent Cloud
        45090|132203) echo "CN" ;;
        # 其他未知
        *) echo "未知" ;;
    esac
}

# 根据ISP名称推断国家（常见ISP）
guess_isp_country() {
    local org="$1"
    local org_lower=$(echo "$org" | tr '[:upper:]' '[:lower:]')

    if [[ "$org_lower" == *"hostpapa"* ]]; then echo "加拿大"
    elif [[ "$org_lower" == *"cloudflare"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"google"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"amazon"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"microsoft"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"digitalocean"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"linode"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"vultr"* ]]; then echo "美国"
    elif [[ "$org_lower" == *"alibaba"* ]]; then echo "中国"
    elif [[ "$org_lower" == *"tencent"* ]]; then echo "中国"
    elif [[ "$org_lower" == *"ovh"* ]]; then echo "法国"
    elif [[ "$org_lower" == *"hetzner"* ]]; then echo "德国"
    elif [[ "$org_lower" == *"netlab"* ]]; then echo "美国"
    else echo "未知"
    fi
}

# 打印增强的IP信息
print_enhanced_ip_info() {
    echo -e "\n${YELLOW}🌍 当前 IP 信息${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo -e "IP 地址: ${GREEN}${CURRENT_IP}${NC}"

    # 显示IP类型（带颜色和加粗）
    local type_color
    case "$IP_TYPE" in
        "原生IP")
            type_color="${GREEN}"
            ;;
        "广播IP")
            type_color="${RED}"
            ;;
        *)
            type_color="${NC}"
            ;;
    esac
    echo -e "IP 类型: \033[1m${type_color}${IP_TYPE}${NC}\033[0m"

    # 显示使用地（IP的地理位置）
    if [ -n "$IP_USAGE_LOCATION" ] && [ "$IP_USAGE_LOCATION" != "  " ]; then
        echo -e "使用地: ${IP_USAGE_LOCATION}"
    else
        echo -e "使用地: ${IP_INFO}"
    fi

    # 显示注册地（ISP/ASN注册信息）
    if [ -n "$IP_REGISTRATION_LOCATION" ] && [ "$IP_REGISTRATION_LOCATION" != "未知" ]; then
        echo -e "注册地: ${IP_REGISTRATION_LOCATION}"
    fi

    echo -e "ISP: ${IP_ISP}"

    # 显示ASN信息
    if [ -n "$IP_ASN" ]; then
        echo -e "ASN: ${IP_ASN}"
    fi

    echo ""
}

# 格式化输出结果
# Remove ANSI color codes from text
strip_ansi_codes() {
    local text="$1"
    # Remove ANSI escape sequences
    echo "$text" | sed 's/\x1b\[[0-9;]*m//g'
}

# Calculate display width of text (CJK chars count as 2, ASCII as 1), excluding ANSI codes
get_display_width() {
    local text="$1"
    # Remove ANSI color codes first
    local clean_text=$(strip_ansi_codes "$text")
    local width=0
    local char
    local len=${#clean_text}

    for ((i=0; i<len; i++)); do
        char="${clean_text:i:1}"
        # Get ASCII value of character
        printf -v ascii '%d' "'$char" 2>/dev/null || ascii=0

        # CJK and other wide characters (> 127)
        if [ "$ascii" -gt 127 ]; then
            width=$((width + 2))
        else
            width=$((width + 1))
        fi
    done

    echo "$width"
}

# Pad text to target display width
pad_to_width() {
    local text="$1"
    local target_width="$2"
    local current_width=$(get_display_width "$text")
    local padding=$((target_width - current_width))

    if [ "$padding" -gt 0 ]; then
        printf "%s%*s" "$text" "$padding" ""
    else
        echo "$text"
    fi
}

format_result() {
    local service_name="$1"
    local status="$2"
    local region="$3"
    local detail="$4"

    # Column 1: Status icon
    local icon color
    case "$status" in
        "success")
            icon="${GREEN}[✓]${NC}"
            color="$GREEN"
            ;;
        "failed")
            icon="${RED}[✗]${NC}"
            color="$RED"
            ;;
        "partial")
            icon="${YELLOW}[◐]${NC}"
            color="$YELLOW"
            ;;
        *)
            icon="${MAGENTA}[?]${NC}"
            color="$MAGENTA"
            ;;
    esac

    # Column 2: Service name (fixed width: 18 chars + colon)
    local service_formatted=$(printf "%-18s:" "$service_name")

    # Column 3: Status detail (pad to fixed display width: 22 display chars)
    local detail_formatted=$(pad_to_width "$detail" 22)

    # Column 4: IP type label (fixed display width: 8 display chars)
    local ip_type_label=""
    if [ "$status" = "success" ]; then
        case "$IP_TYPE" in
            "原生IP")
                ip_type_label="${GREEN}[原生]${NC}"
                ;;
            "广播IP")
                ip_type_label="${YELLOW}[广播]${NC}"
                ;;
            *)
                ip_type_label="${CYAN}[未知]${NC}"
                ;;
        esac
    fi

    # Pad IP type to fixed width (8 display chars)
    local ip_type_padded=$(pad_to_width "$ip_type_label" 8)

    # Column 5: Region info
    local region_info=""
    if [ "$region" != "N/A" ] && [ "$region" != "Unknown" ] && [ -n "$region" ]; then
        region_info=": ${CYAN}(区域: $region)${NC}"
    fi

    # Print aligned columns with colon separators
    echo -e "$icon $service_formatted ${color}${detail_formatted}${NC} : ${ip_type_padded}${region_info}"
}

# 检测 Netflix
check_netflix() {
    local unlock_type=$(check_dns_unlock "netflix.com")
    local region="${COUNTRY_CODE:-Unknown}"

    # 检测Netflix首页（更可靠的检测方法）
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://www.netflix.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    # 检查响应是否为空
    if [ -z "$status_code" ] || [ -z "$content" ]; then
        format_result "Netflix" "error" "N/A" "检测失败"
        return
    fi

    # 检查是否被区域限制或IP封禁
    if echo "$content" | grep -qi "not available\|not streaming in your country\|access denied\|blocked"; then
        format_result "Netflix" "failed" "N/A" "IP被封禁"
    elif [ "$status_code" = "200" ] || [ "$status_code" = "301" ] || [ "$status_code" = "302" ]; then
        # 200/301/302都表示可以访问
        format_result "Netflix" "success" "$region" "可访问"
    elif [ "$status_code" = "403" ]; then
        # 403通常是IP被封禁
        format_result "Netflix" "failed" "N/A" "IP被封禁"
    else
        format_result "Netflix" "error" "N/A" "检测失败(${status_code})"
    fi
}

# 检测 Disney+
check_disney() {
    local unlock_type=$(check_dns_unlock "disneyplus.com")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.disneyplus.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Disney+" "success" "$COUNTRY_CODE" "完整解锁"
    elif [ "$status_code" = "403" ]; then
        format_result "Disney+" "failed" "N/A" "不支持"
    else
        format_result "Disney+" "error" "N/A" "检测失败"
    fi
}

# 检测 YouTube Premium
check_youtube() {
    local unlock_type=$(check_dns_unlock "youtube.com")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://www.youtube.com/premium" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "YouTube Premium" "success" "$COUNTRY_CODE" "支持"
    else
        format_result "YouTube Premium" "error" "N/A" "检测失败"
    fi
}

# 检测 ChatGPT
check_chatgpt() {
    local unlock_type=$(check_dns_unlock "chat.openai.com")
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://chat.openai.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    # 检查 OpenAI/ChatGPT 实际返回的区域限制消息
    if echo "$content" | grep -qi "not available in your country\|unavailable in your country"; then
        format_result "ChatGPT" "failed" "N/A" "该地区不支持"
    elif echo "$content" | grep -qi "unsupported\|not supported"; then
        format_result "ChatGPT" "failed" "N/A" "该地区不支持"
    elif echo "$content" | grep -qi "not available"; then
        format_result "ChatGPT" "failed" "N/A" "该地区不支持"
    elif [ "$status_code" = "403" ]; then
        # 403 通常是IP被拦截
        format_result "ChatGPT" "failed" "N/A" "该地区不支持"
    elif [ "$status_code" = "200" ]; then
        # 验证是否真的是 ChatGPT 应用
        if echo "$content" | grep -qi "openai" && echo "$content" | grep -qi "chat\|gpt"; then
            format_result "ChatGPT" "success" "$COUNTRY_CODE" "可访问"
        else
            format_result "ChatGPT" "failed" "N/A" "服务不可用"
        fi
    else
        format_result "ChatGPT" "error" "N/A" "检测失败"
    fi
}

# 检测 Claude
check_claude() {
    local unlock_type=$(check_dns_unlock "claude.ai")
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://claude.ai/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    # 检查 Claude 实际返回的区域限制消息
    # "only available in certain regions" 是 Claude 的实际错误消息
    if echo "$content" | grep -qi "only available in certain regions"; then
        format_result "Claude" "failed" "N/A" "该地区不支持"
    # 检查中文错误消息（應用程式不可用/僅在特定地區提供服務）
    elif echo "$content" | grep -q "應用程式不可用\|僅在特定地區提供服務"; then
        format_result "Claude" "failed" "N/A" "该地区不支持"
    # 检查其他区域限制关键词
    elif echo "$content" | grep -qi "not available\|unavailable in your region"; then
        format_result "Claude" "failed" "N/A" "该地区不支持"
    elif [ "$status_code" = "403" ]; then
        # 403 通常是IP被拦截
        format_result "Claude" "failed" "N/A" "该地区不支持"
    elif [ "$status_code" = "200" ]; then
        # 验证是否真的是 Claude 应用（检查页面是否包含关键元素）
        if echo "$content" | grep -qi "claude" && echo "$content" | grep -qi "anthropic\|chat"; then
            format_result "Claude" "success" "$COUNTRY_CODE" "可访问"
        else
            # 200 但不像 Claude 应用 - 可能是错误页面
            format_result "Claude" "failed" "N/A" "服务不可用"
        fi
    else
        format_result "Claude" "error" "N/A" "检测失败"
    fi
}

# 检测 TikTok
check_tiktok() {
    local unlock_type=$(check_dns_unlock "tiktok.com")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.tiktok.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "TikTok" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "TikTok" "failed" "N/A" "区域受限"
    else
        format_result "TikTok" "error" "N/A" "检测失败"
    fi
}

# 检测 Imgur
check_imgur() {
    local unlock_type=$(check_dns_unlock "imgur.com")
    # 检测 Imgur，增加更宽松的超时和重试
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://imgur.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local region="${COUNTRY_CODE:-Unknown}"

    # 检查curl是否执行成功
    if [ -z "$status_code" ]; then
        # 尝试备用URL
        status_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            "https://i.imgur.com/" 2>/dev/null)
    fi

    if [ "$status_code" = "200" ]; then
        format_result "Imgur" "success" "$region" "可访问"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "Imgur" "failed" "N/A" "区域受限"
    elif [ "$status_code" = "301" ] || [ "$status_code" = "302" ]; then
        # 重定向通常表示可访问
        format_result "Imgur" "success" "$region" "可访问"
    elif [ "$status_code" = "429" ]; then
        # 速率限制，通常表示服务可访问
        format_result "Imgur" "success" "$region" "可访问(速率限制)"
    elif [ -z "$status_code" ] || [ "$status_code" = "000" ]; then
        format_result "Imgur" "error" "N/A" "连接超时"
    else
        format_result "Imgur" "error" "N/A" "检测失败(${status_code})"
    fi
}

# 检测 Reddit
check_reddit() {
    local unlock_type=$(check_dns_unlock "reddit.com")
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://www.reddit.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    # 检查是否被安全系统拦截（优先检查内容）
    if echo "$content" | grep -qi "blocked by network security\|blocked by mistake\|access denied"; then
        format_result "Reddit" "partial" "$COUNTRY_CODE" "IP被限制，需登录访问"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        # 403/451 也可能是安全拦截
        format_result "Reddit" "partial" "$COUNTRY_CODE" "IP被限制，需登录访问"
    elif [ "$status_code" = "200" ]; then
        # 200 且内容没有拦截关键词，才是真正可访问
        format_result "Reddit" "success" "$COUNTRY_CODE" "可访问"
    else
        format_result "Reddit" "error" "N/A" "检测失败(${status_code})"
    fi
}

# 检测 Google Gemini
check_gemini() {
    local unlock_type=$(check_dns_unlock "gemini.google.com")
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://gemini.google.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    # 检查 Gemini 实际返回的区域限制消息
    # "Gemini is currently not supported in your country" 是实际错误消息
    if echo "$content" | grep -qi "not supported in your country\|isn't supported in your country"; then
        format_result "Gemini" "failed" "N/A" "该地区不支持"
    # 检查其他 Gemini 相关的不可用消息
    elif echo "$content" | grep -qi "gemini" && echo "$content" | grep -qi "not available\|unavailable"; then
        format_result "Gemini" "failed" "N/A" "该地区不支持"
    elif [ "$status_code" = "403" ]; then
        format_result "Gemini" "failed" "N/A" "区域受限"
    elif [ "$status_code" = "200" ]; then
        # 验证是否真的是 Gemini 应用（检查页面是否包含关键元素）
        if echo "$content" | grep -qi "gemini" && echo "$content" | grep -qi "google\|conversation"; then
            format_result "Gemini" "success" "$COUNTRY_CODE" "可访问"
        else
            # 200 但不像 Gemini 应用 - 可能是错误页面
            format_result "Gemini" "failed" "N/A" "服务不可用"
        fi
    else
        format_result "Gemini" "error" "N/A" "检测失败"
    fi
}

# 检测 Spotify
check_spotify() {
    local unlock_type=$(check_dns_unlock "open.spotify.com")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://open.spotify.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Spotify" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ]; then
        format_result "Spotify" "failed" "N/A" "区域受限"
    else
        format_result "Spotify" "error" "N/A" "检测失败"
    fi
}

# 检测 Google Scholar
check_scholar() {
    local unlock_type=$(check_dns_unlock "scholar.google.com")
    # 实际执行搜索请求来测试是否被限制
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://scholar.google.com/scholar?q=test" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    # 检查是否包含机器人流量警告（使用更宽松的匹配）
    if echo "$content" | grep -qi "automated\|unusual traffic\|can't process your request\|We're sorry"; then
        format_result "Google Scholar" "partial" "$COUNTRY_CODE" "可访问官网，但无法搜索"
    elif [ "$status_code" = "200" ]; then
        format_result "Google Scholar" "success" "$COUNTRY_CODE" "完全可用"
    elif [ "$status_code" = "403" ]; then
        format_result "Google Scholar" "failed" "N/A" "区域受限"
    elif [ "$status_code" = "429" ]; then
        format_result "Google Scholar" "failed" "N/A" "速率限制"
    else
        format_result "Google Scholar" "error" "N/A" "检测失败"
    fi
}

# 运行所有检测
run_all_checks() {
    echo -e "${YELLOW}📺 流媒体解锁检测结果${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"

    # 视频流媒体
    echo -e "\n${BLUE}🎬 视频流媒体${NC}"
    check_netflix
    [ -z "$FAST_MODE" ] && sleep 0.5
    check_disney
    [ -z "$FAST_MODE" ] && sleep 0.5
    check_youtube
    [ -z "$FAST_MODE" ] && sleep 0.5
    check_tiktok
    [ -z "$FAST_MODE" ] && sleep 0.5

    # 音乐流媒体
    echo -e "\n${BLUE}🎵 音乐流媒体${NC}"
    check_spotify
    [ -z "$FAST_MODE" ] && sleep 0.5

    # AI 服务
    echo -e "\n${BLUE}🤖 AI 服务${NC}"
    check_chatgpt
    [ -z "$FAST_MODE" ] && sleep 0.5
    check_claude
    [ -z "$FAST_MODE" ] && sleep 0.5
    check_gemini
    [ -z "$FAST_MODE" ] && sleep 0.5

    # 社区论坛
    echo -e "\n${BLUE}💬 社区论坛${NC}"
    check_reddit
    [ -z "$FAST_MODE" ] && sleep 0.5

    # 其他服务
    echo -e "\n${BLUE}📚 其他服务${NC}"
    check_scholar
    [ -z "$FAST_MODE" ] && sleep 0.5
    check_imgur

    echo -e "\n${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo -e "检测完成!\n"
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --fast          快速检测模式（无延迟）"
    echo "  --help, -h      显示帮助信息"
    echo "  --version, -v   显示版本信息"
    echo ""
    echo "示例:"
    echo "  $0              运行完整检测"
    echo "  $0 --fast       快速检测"
}

# 主函数
main() {
    # 检查依赖
    check_dependencies

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fast)
                FAST_MODE=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "StreamCheck v${VERSION}"
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 打印头部
    print_header

    # 获取IP信息
    get_ip_info

    # 运行检测
    run_all_checks
}

# 捕获 Ctrl+C
trap 'echo -e "\n\n${YELLOW}检测已取消${NC}"; exit 0' INT

# 运行主函数
main "$@"
