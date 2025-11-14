#!/bin/bash
#
# UnlockCheck - 服务解锁检测工具 (Bash 版本)
# 一键检测当前网络环境的流媒体和AI服务解锁情况
#

VERSION="1.3"
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ========================================================================
# 表格布局常量 - 请勿修改！这些值是精心调整过的，确保所有行完美对齐
# ========================================================================
readonly COLUMN_WIDTH_SERVICE=16      # 服务名称列宽度（显示字符数）
readonly COLUMN_WIDTH_STATUS=20       # 解锁状态列宽度（显示字符数）
readonly COLUMN_WIDTH_UNLOCK_TYPE=8   # 解锁类型列宽度（显示字符数）
readonly COLUMN_WIDTH_REGION=3        # 区域列宽度（显示字符数）
readonly SEPARATOR_WIDTH=59           # 分隔线长度（字符数）
# ========================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 生成分隔线的辅助函数
print_separator() {
    local separator=""
    for ((i=0; i<SEPARATOR_WIDTH; i++)); do
        separator="${separator}─"
    done
    echo -e "${CYAN}${separator}${NC}"
}

# 生成标题分隔线的辅助函数（使用 = 字符）
print_header_separator() {
    local separator=""
    for ((i=0; i<SEPARATOR_WIDTH; i++)); do
        separator="${separator}="
    done
    echo -e "${CYAN}${separator}${NC}"
}

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
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\n"
    print_header_separator
    echo -e "${CYAN}                UnlockCheck - 服务解锁检测工具"
    echo -e "          https://github.com/uniquMonte/unlockcheck"
    echo -e "                检测时间: ${current_time}${NC}"
    print_header_separator
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

# ========================================================================
# DNS解锁检测函数（参考 IPQuality 实现）
# ========================================================================

# 检查IP地址有效性
check_ip_valide() {
    local IPPattern='^(\<([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\>\.){3}\<([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\>$'
    local IP="$1"
    if [[ $IP =~ $IPPattern ]]; then
        return 0
    else
        return 1
    fi
}

# 计算IP网段
calc_ip_net() {
    local sip="$1"
    local snetmask="$2"
    check_ip_valide "$sip"
    if [ $? -ne 0 ]; then
        echo ""
        return 1
    fi
    local ipFIELD1=$(echo "$sip"|cut -d. -f1)
    local ipFIELD2=$(echo "$sip"|cut -d. -f2)
    local ipFIELD3=$(echo "$sip"|cut -d. -f3)
    local ipFIELD4=$(echo "$sip"|cut -d. -f4)
    local netmaskFIELD1=$(echo "$snetmask"|cut -d. -f1)
    local netmaskFIELD2=$(echo "$snetmask"|cut -d. -f2)
    local netmaskFIELD3=$(echo "$snetmask"|cut -d. -f3)
    local netmaskFIELD4=$(echo "$snetmask"|cut -d. -f4)
    local tmpret1=$((ipFIELD1&netmaskFIELD1))
    local tmpret2=$((ipFIELD2&netmaskFIELD2))
    local tmpret3=$((ipFIELD3&netmaskFIELD3))
    local tmpret4=$((ipFIELD4&netmaskFIELD4))
    echo "$tmpret1.$tmpret2.$tmpret3.$tmpret4"
}

# 检查DNS返回的IP是否为私有IP或本地IP
Check_DNS_IP() {
    # 检查IPv4
    if [ "$1" != "${1#*[0-9].[0-9]}" ]; then
        if [ "$(calc_ip_net "$1" 255.0.0.0)" == "10.0.0.0" ]; then
            echo 0  # 私有IP段 10.x.x.x
        elif [ "$(calc_ip_net "$1" 255.240.0.0)" == "172.16.0.0" ]; then
            echo 0  # 私有IP段 172.16-31.x.x
        elif [ "$(calc_ip_net "$1" 255.255.0.0)" == "169.254.0.0" ]; then
            echo 0  # 链路本地地址
        elif [ "$(calc_ip_net "$1" 255.255.0.0)" == "192.168.0.0" ]; then
            echo 0  # 私有IP段 192.168.x.x
        elif [ "$(calc_ip_net "$1" 255.255.255.0)" == "$(calc_ip_net "$2" 255.255.255.0)" ]; then
            echo 0  # 同一子网
        else
            echo 1  # 公网IP
        fi
    # 检查IPv6
    elif [ "$1" != "${1#*[0-9a-fA-F]:*}" ]; then
        if [ "${1:0:3}" == "fe8" ] || [ "${1:0:3}" == "FE8" ]; then
            echo 0  # IPv6链路本地地址
        elif [ "${1:0:2}" == "fc" ] || [ "${1:0:2}" == "FC" ]; then
            echo 0  # IPv6唯一本地地址
        elif [ "${1:0:2}" == "fd" ] || [ "${1:0:2}" == "FD" ]; then
            echo 0  # IPv6唯一本地地址
        elif [ "${1:0:2}" == "ff" ] || [ "${1:0:2}" == "FF" ]; then
            echo 0  # IPv6组播地址
        else
            echo 1  # 公网IPv6
        fi
    else
        echo 0  # 无法识别，保守处理
    fi
}

# DNS检测方法1：使用nslookup检查DNS解析结果
Check_DNS_1() {
    local domain="$1"

    # 检查是否有nslookup命令
    if ! command -v nslookup &> /dev/null; then
        echo 1  # 无nslookup，假定为原生
        return
    fi

    local resultdns=$(nslookup "$domain" 2>/dev/null)
    if [ -z "$resultdns" ]; then
        echo 1
        return
    fi

    # 解析nslookup输出
    local resultinlines=(${resultdns//$'\n'/ })
    local resultindex=0
    local resultdnsindex=0

    for i in "${resultinlines[@]}"; do
        if [[ $i == "Name:" ]]; then
            resultdnsindex=$((resultindex+3))
            break
        fi
        resultindex=$((resultindex+1))
    done

    # 获取DNS服务器IP（用于对比）
    local dns_server=$(echo "$resultdns" | grep "Server:" | awk '{print $2}' | head -1)

    # 检查解析到的IP
    if [ $resultdnsindex -lt ${#resultinlines[@]} ]; then
        local resolved_ip="${resultinlines[$resultdnsindex]}"
        echo $(Check_DNS_IP "$resolved_ip" "$dns_server")
    else
        echo 1
    fi
}

# DNS检测方法3：查询不存在的随机子域名，检测DNS劫持
Check_DNS_3() {
    local domain="$1"

    # 检查是否有dig命令
    if ! command -v dig &> /dev/null; then
        echo 1  # 无dig，假定为原生
        return
    fi

    # 生成随机子域名
    local random_subdomain="test$RANDOM$RANDOM.$domain"
    local resultdnstext=$(dig "$random_subdomain" 2>/dev/null | grep "ANSWER:")

    if [ -z "$resultdnstext" ]; then
        echo 1
        return
    fi

    # 提取ANSWER部分的记录数
    resultdnstext=${resultdnstext#*"ANSWER: "}
    resultdnstext=${resultdnstext%", AUTHORITY:"*}

    # 如果不存在的域名返回0条记录，说明DNS正常
    if [ "$resultdnstext" == "0" ]; then
        echo 1  # 正常DNS
    else
        echo 0  # DNS被劫持（SmartDNS特征）
    fi
}

# 根据DNS检测结果判断解锁类型
Get_Unlock_Type() {
    # 遍历所有检测结果
    while [ $# -ne 0 ]; do
        if [ "$1" = "0" ]; then
            echo "DNS"  # DNS解锁
            return
        fi
        shift
    done
    echo "原生"  # 原生解锁
}

# 获取 IP 信息（增强版）
get_ip_info() {
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
        print_separator
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
        "ES") echo "西班牙" ;;
        "IT") echo "意大利" ;;
        "SE") echo "瑞典" ;;
        "NO") echo "挪威" ;;
        "DK") echo "丹麦" ;;
        "FI") echo "芬兰" ;;
        "PL") echo "波兰" ;;
        "CH") echo "瑞士" ;;
        "AT") echo "奥地利" ;;
        "BE") echo "比利时" ;;
        "IE") echo "爱尔兰" ;;
        "PT") echo "葡萄牙" ;;
        "GR") echo "希腊" ;;
        "CZ") echo "捷克" ;;
        "RO") echo "罗马尼亚" ;;
        "HU") echo "匈牙利" ;;
        "BG") echo "保加利亚" ;;
        "TR") echo "土耳其" ;;
        "IL") echo "以色列" ;;
        "AE") echo "阿联酋" ;;
        "SA") echo "沙特阿拉伯" ;;
        "EG") echo "埃及" ;;
        "ZA") echo "南非" ;;
        "MX") echo "墨西哥" ;;
        "AR") echo "阿根廷" ;;
        "CL") echo "智利" ;;
        "CO") echo "哥伦比亚" ;;
        "PE") echo "秘鲁" ;;
        "VN") echo "越南" ;;
        "TH") echo "泰国" ;;
        "ID") echo "印度尼西亚" ;;
        "MY") echo "马来西亚" ;;
        "PH") echo "菲律宾" ;;
        "NZ") echo "新西兰" ;;
        "UA") echo "乌克兰" ;;
        "LT") echo "立陶宛" ;;
        "LV") echo "拉脱维亚" ;;
        "EE") echo "爱沙尼亚" ;;
        "SK") echo "斯洛伐克" ;;
        "SI") echo "斯洛文尼亚" ;;
        "HR") echo "克罗地亚" ;;
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
    print_separator
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
    echo -e "IP 类型: ${type_color}\033[1m${IP_TYPE}\033[0m${NC}"

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
    # Remove both actual ANSI escape sequences and literal \033 strings
    # This handles both $'\033[...' and '\033[...' style color codes
    printf "%s" "$text" | sed -e $'s/\033\[[0-9;]*m//g' -e 's/\\033\[[0-9;]*m//g'
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
        printf "%s" "$text"
    fi
}

format_result() {
    local service_name="$1"
    local status="$2"
    local region="$3"
    local detail="$4"
    local unlock_type="${5:-}"  # 第5个参数：解锁类型（原生/DNS）

    # ====================================================================
    # 警告：此函数使用固定的列宽常量来确保表格对齐
    # 请勿修改 pad_to_width 的参数，否则会破坏对齐！
    # ====================================================================

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

    # Column 2: Service name (使用固定列宽常量)
    local service_padded=$(pad_to_width "$service_name" $COLUMN_WIDTH_SERVICE)
    local service_formatted="${service_padded}:"

    # Column 3: Status detail (使用固定列宽常量)
    local detail_formatted=$(pad_to_width "$detail" $COLUMN_WIDTH_STATUS)

    # Column 4: Unlock type label (使用固定列宽常量)
    local unlock_type_text=""
    local unlock_type_color=""
    if [ "$status" = "success" ] || [ "$status" = "partial" ]; then
        # 如果提供了解锁类型，使用它；否则不显示
        if [ -n "$unlock_type" ]; then
            unlock_type_text="$unlock_type"
            # DNS解锁用黄色，原生解锁用绿色
            if [ "$unlock_type" = "DNS" ]; then
                unlock_type_color="${YELLOW}"
            else
                unlock_type_color="${GREEN}"
            fi
        fi
    fi

    # Pad unlock type to fixed width, then add color
    local unlock_type_padded=$(pad_to_width "$unlock_type_text" $COLUMN_WIDTH_UNLOCK_TYPE)
    if [ -n "$unlock_type_color" ]; then
        unlock_type_padded="${unlock_type_color}${unlock_type_padded}${NC}"
    fi

    # Column 5: Region info (使用固定列宽常量)
    local region_colored
    if [ "$region" != "N/A" ] && [ "$region" != "Unknown" ] && [ "$region" != "null" ] && [ -n "$region" ]; then
        local region_padded=$(pad_to_width "$region" $COLUMN_WIDTH_REGION)
        region_colored="${CYAN}${region_padded}${NC}"
    else
        # Use empty spaces to maintain column alignment
        region_colored=$(pad_to_width "" $COLUMN_WIDTH_REGION)
    fi

    # Print aligned columns (always include region column separator for consistent alignment)
    echo -e "$icon $service_formatted ${color}${detail_formatted}${NC} : ${unlock_type_padded}: ${region_colored}"
}

# 检测 Netflix
# 参考实现: https://github.com/xykt/IPQuality
check_netflix() {
    # DNS解锁检测
    local checkunlockurl="netflix.com"
    local result1=$(Check_DNS_1 $checkunlockurl)
    local result3=$(Check_DNS_3 $checkunlockurl)
    local resultunlocktype=$(Get_Unlock_Type $result1 $result3)

    # 使用特定的Netflix标题页面进行检测（自制剧，全球可用）
    # 81280792 - The Queen's Gambit (自制剧)
    # 70143836 - Friends (授权内容，部分地区可用)

    # 使用 -w 获取HTTP状态码
    local response1=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -w "\n%{http_code}" \
        "https://www.netflix.com/title/81280792" 2>/dev/null)

    local response2=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -w "\n%{http_code}" \
        "https://www.netflix.com/title/70143836" 2>/dev/null)

    # 提取HTTP状态码和内容
    local status1=$(echo "$response1" | tail -n 1)
    local result1_content=$(echo "$response1" | head -n -1)
    local status2=$(echo "$response2" | tail -n 1)
    local result2_content=$(echo "$response2" | head -n -1)

    # 检查是否完全无法连接
    if [ -z "$status1" ] && [ -z "$status2" ]; then
        format_result "Netflix" "error" "N/A" "网络错误"
        return
    fi

    # 检查是否被地区屏蔽（403/451）
    if [ "$status1" = "403" ] || [ "$status1" = "451" ] || [ "$status2" = "403" ] || [ "$status2" = "451" ]; then
        format_result "Netflix" "failed" "N/A" "屏蔽"
        return
    fi

    # 从响应中提取地区代码（从JSON中提取currentCountry字段）
    local region1=$(echo "$result1_content" | grep -oP '"currentCountry"\s*:\s*"\K[^"]+' | head -n1)
    local region2=$(echo "$result2_content" | grep -oP '"currentCountry"\s*:\s*"?\K[^",}]+' | head -n1)

    # 过滤掉 "null" 值
    [ "$region1" = "null" ] && region1=""
    [ "$region2" = "null" ] && region2=""

    # 优先使用检测到的地区，如果没有则使用IP地区
    local region="${region1:-${region2:-${COUNTRY_CODE}}}"

    # 检查是否有"不可用"的提示
    # Netflix在IP被封禁或地区不可用时会显示错误页面
    local error1=$(echo "$result1_content" | grep -i "not available\|страница отсутствует\|page manquante")
    local error2=$(echo "$result2_content" | grep -i "not available\|страница отсутствует\|page manquante")

    # 判断逻辑：
    # 1. 如果自制剧和授权内容都能访问 -> 完全解锁
    # 2. 如果只有自制剧能访问 -> 仅自制剧
    # 3. 如果都无法访问 -> IP被封禁或屏蔽

    if [ -z "$error1" ] && [ -z "$error2" ]; then
        # 都可以访问，完全解锁
        format_result "Netflix" "success" "$region" "完全解锁" "$resultunlocktype"
    elif [ -z "$error1" ] && [ -n "$error2" ]; then
        # 只有自制剧可以访问
        format_result "Netflix" "partial" "$region" "仅自制剧" "$resultunlocktype"
    else
        # 都无法访问或出错
        format_result "Netflix" "failed" "N/A" "屏蔽"
    fi
}

# 检测 Disney+
check_disney() {
    # DNS解锁检测
    local checkunlockurl="disneyplus.com"
    local result1=$(Check_DNS_1 $checkunlockurl)
    local result3=$(Check_DNS_3 $checkunlockurl)
    local resultunlocktype=$(Get_Unlock_Type $result1 $result3)

    # API 检测（完全参考 IPQuality 实现）
    local PreAssertion=$(curl -s --max-time $TIMEOUT \
        -X POST \
        -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" \
        -H "content-type: application/json; charset=UTF-8" \
        -A "$USER_AGENT" \
        --data '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' \
        "https://disney.api.edge.bamgrid.com/devices" 2>/dev/null)

    # 提取 assertion
    local assertion=$(echo "$PreAssertion" | grep -oP '"assertion"\s*:\s*"\K[^"]+' | head -n1)

    if [ -z "$assertion" ]; then
        format_result "Disney+" "error" "N/A" "网络错误"
        return
    fi

    # Token Exchange - 使用 URL encoded 格式（关键修复！）
    local TokenContent=$(curl -s --max-time $TIMEOUT \
        -X POST \
        -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" \
        --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
        --data-urlencode "latitude=0" \
        --data-urlencode "longitude=0" \
        --data-urlencode "platform=browser" \
        --data-urlencode "subject_token=$assertion" \
        --data-urlencode "subject_token_type=urn:bamtech:params:oauth:token-type:device" \
        -A "$USER_AGENT" \
        "https://disney.api.edge.bamgrid.com/token" 2>/dev/null)

    # 检查是否被地理位置屏蔽
    local isBanned=$(echo "$TokenContent" | grep -oP '"error_description"\s*:\s*"forbidden-location"')
    local is403=$(echo "$TokenContent" | grep '403 ERROR')

    if [ -n "$isBanned" ] || [ -n "$is403" ]; then
        format_result "Disney+" "failed" "N/A" "屏蔽"
        return
    fi

    # 提取 refresh_token
    local refreshToken=$(echo "$TokenContent" | grep -oP '"refresh_token"\s*:\s*"\K[^"]+' | head -n1)

    if [ -z "$refreshToken" ]; then
        format_result "Disney+" "error" "N/A" "检测失败"
        return
    fi

    # GraphQL 查询地区信息
    local tmpresult=$(curl -s --max-time $TIMEOUT \
        -X POST \
        -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" \
        -H "content-type: application/json" \
        -A "$USER_AGENT" \
        --data '{"query":"mutation refreshToken($input: RefreshTokenInput!) {\n            refreshToken(refreshToken: $input) {\n                activeSession {\n                    sessionId\n                }\n            }\n        }","variables":{"input":{"refreshToken":"'"$refreshToken"'"}}}' \
        "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" 2>/dev/null)

    # 检查是否 unavailable
    local previewcheck=$(curl -s -o /dev/null -L --max-time $TIMEOUT -w '%{url_effective}\n' "https://disneyplus.com" 2>/dev/null)
    local isUnavailable=$(echo "$previewcheck" | grep 'unavailable')

    # 提取地区和支持状态（从 extensions.sdk.session 中）
    local region=$(echo "$tmpresult" | grep -oP '"location"[^}]*"countryCode"\s*:\s*"\K[^"]+' | head -n1)
    local inSupportedLocation=$(echo "$tmpresult" | grep -oP '"inSupportedLocation"\s*:\s*(true|false)' | grep -oP '(true|false)' | head -n1)

    # 判断逻辑（完全按照 IPQuality）
    if [ "$region" = "JP" ]; then
        format_result "Disney+" "success" "JP" "完全解锁" "$resultunlocktype"
        return
    elif [ -n "$region" ] && [ "$inSupportedLocation" = "false" ] && [ -z "$isUnavailable" ]; then
        format_result "Disney+" "failed" "$region" "即将上线" "$resultunlocktype"
        return
    elif [ -n "$region" ] && [ -n "$isUnavailable" ]; then
        format_result "Disney+" "failed" "N/A" "屏蔽"
        return
    elif [ -n "$region" ] && [ "$inSupportedLocation" = "true" ]; then
        format_result "Disney+" "success" "$region" "完全解锁" "$resultunlocktype"
        return
    elif [ -z "$region" ]; then
        format_result "Disney+" "failed" "N/A" "屏蔽"
        return
    else
        format_result "Disney+" "error" "N/A" "检测失败"
        return
    fi
}

# 检测 YouTube Premium
check_youtube() {
    local response=$(curl -s --max-time $TIMEOUT \
        -w "\n%{http_code}" \
        -A "$USER_AGENT" \
        -L \
        "https://www.youtube.com/premium" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local content=$(echo "$response" | head -n -1)

    if [ -z "$status_code" ]; then
        format_result "YouTube Premium" "error" "N/A" "网络错误"
        return
    fi

    # 检查是否被屏蔽
    if [ "$status_code" = "403" ]; then
        format_result "YouTube Premium" "failed" "N/A" "屏蔽"
        return
    fi

    # 转换为小写
    local content_lower=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    # 检查地区限制（明确的不可用信息）
    if echo "$content_lower" | grep -q "not available in your country\|not available in your region\|unavailable in your"; then
        format_result "YouTube Premium" "failed" "N/A" "屏蔽"
        return
    fi

    # 检查是否成功访问
    if [ "$status_code" = "200" ] || [ "$status_code" = "302" ] || [ "$status_code" = "301" ]; then
        # 如果状态码正常且没有明确的错误信息，则认为可用
        # 检查是否包含 YouTube 相关内容（更宽松的检查）
        if echo "$content_lower" | grep -q "youtube\|premium\|subscribe" || [ ${#content} -gt 1000 ]; then
            format_result "YouTube Premium" "success" "$COUNTRY_CODE" "完全解锁"
        else
            format_result "YouTube Premium" "error" "N/A" "检测失败"
        fi
    else
        format_result "YouTube Premium" "error" "N/A" "检测失败"
    fi
}

# 检测 ChatGPT - Smart dual detection
check_chatgpt() {
    local unlock_type=$(check_dns_unlock "api.openai.com")

    # ChatGPT/OpenAI unsupported regions (based on official documentation)
    # https://platform.openai.com/docs/supported-countries
    local unsupported_regions="CN HK RU IR KP SY CU BY VE"

    # Step 0: Check geolocation first (most reliable)
    if echo "$unsupported_regions" | grep -qw "$COUNTRY_CODE"; then
        format_result "ChatGPT" "failed" "N/A" "该地区屏蔽"
        return
    fi

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

    # Step 2: Check web if needed (only if no clear result from API)
    if [ "$has_cloudflare" = "false" ] && [ "$api_result" != "region_restricted" ]; then
        local web_response=$(curl -s --max-time $TIMEOUT \
            -A "$USER_AGENT" -L -w "\n%{http_code}" \
            "https://chatgpt.com/" 2>/dev/null)

        local web_status=$(echo "$web_response" | tail -n 1)
        local web_content=$(echo "$web_response" | head -n -1)

        if [ "$web_status" = "403" ] || [ "$web_status" = "503" ]; then
            if echo "$web_content" | grep -qi "just a moment\|checking your browser\|attention required"; then
                has_cloudflare=true
            fi
        fi
    fi

    # Step 3: Intelligent decision (Priority: region restriction > API success > Cloudflare)
    if [ "$api_result" = "region_restricted" ]; then
        format_result "ChatGPT" "failed" "N/A" "该地区屏蔽"
    elif [ "$api_result" = "success" ]; then
        # API成功表示服务可用
        # 脚本检测到的CF验证不代表浏览器也会遇到（CF能区分脚本和真实浏览器）
        format_result "ChatGPT" "success" "$COUNTRY_CODE" "完全解锁"
    elif [ "$has_cloudflare" = "true" ]; then
        # 只有当API无法确认时,Cloudflare才可能是问题
        # 提示用户:脚本遇到Cloudflare,但浏览器可能可以访问
        format_result "ChatGPT" "partial" "$COUNTRY_CODE" "推测可用(人工验证)"
    elif [ "$api_result" = "access_denied" ]; then
        format_result "ChatGPT" "failed" "N/A" "访问被拒"
    else
        format_result "ChatGPT" "error" "N/A" "检测失败"
    fi
}

# 检测 Claude - Smart dual detection
check_claude() {
    local unlock_type=$(check_dns_unlock "api.anthropic.com")

    # Claude unsupported regions (based on official documentation)
    # https://www.anthropic.com/supported-countries
    local unsupported_regions="CN HK RU IR KP SY CU BY"

    # Step 0: Check geolocation first (most reliable)
    if echo "$unsupported_regions" | grep -qw "$COUNTRY_CODE"; then
        format_result "Claude" "failed" "N/A" "该地区屏蔽"
        return
    fi

    local api_result=""
    local web_result=""
    local has_cloudflare=false

    # Step 1: Check API endpoint (must use POST method)
    local api_response=$(curl -s --max-time $TIMEOUT \
        -X POST \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "x-api-key: invalid" \
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
        -A "$USER_AGENT" -L -w "\n%{http_code}" \
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

    # Step 3: Intelligent decision (Priority: region restriction > API success > Cloudflare)
    if [ "$api_result" = "region_restricted" ] || [ "$web_result" = "region_restricted" ]; then
        format_result "Claude" "failed" "N/A" "该地区屏蔽"
    elif [ "$api_result" = "success" ]; then
        # API成功表示服务可用
        # 脚本检测到的CF验证不代表浏览器也会遇到（CF能区分脚本和真实浏览器）
        format_result "Claude" "success" "$COUNTRY_CODE" "完全解锁"
    elif [ "$has_cloudflare" = "true" ]; then
        # 只有当API无法确认时,Cloudflare才可能是问题
        # 提示用户:脚本遇到Cloudflare,但浏览器可能可以访问
        format_result "Claude" "partial" "$COUNTRY_CODE" "推测可用(人工验证)"
    elif [ "$api_result" = "access_denied" ]; then
        format_result "Claude" "failed" "N/A" "访问被拒"
    else
        format_result "Claude" "error" "N/A" "检测失败"
    fi
}

# 检测 TikTok
check_tiktok() {
    # 参考 IPQuality 项目的实现
    # 第一次请求：尝试获取内容
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.tiktok.com/" 2>/dev/null)

    # 检查响应是否为空
    if [ -z "$response" ]; then
        format_result "TikTok" "error" "N/A" "网络错误"
        return
    fi

    # 尝试从响应中提取 region 字段
    local region=$(echo "$response" | grep -oP '"region"\s*:\s*"\K[^"]+' | head -n1)

    # 如果第一次没有提取到，尝试使用 gzip 压缩请求
    if [ -z "$region" ]; then
        response=$(curl -s --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            -H "Accept-Encoding: gzip" \
            --compressed \
            -L \
            "https://www.tiktok.com/" 2>/dev/null)

        region=$(echo "$response" | grep -oP '"region"\s*:\s*"\K[^"]+' | head -n1)
    fi

    # 转换为小写用于检查错误信息
    local content_lower=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    # 检查是否是反爬虫机制（Access Denied）
    if echo "$content_lower" | grep -q "access denied"; then
        # 检查 IP 所在国家/地区是否支持 TikTok
        # TikTok 在大部分国家可用，主要禁止地区：中国大陆、印度
        if [ "$COUNTRY_CODE" = "CN" ] || [ "$COUNTRY_CODE" = "IN" ]; then
            format_result "TikTok" "failed" "N/A" "区域受限"
        else
            # 其他地区遇到 Access Denied，是脚本限制而非地区限制
            format_result "TikTok" "partial" "$COUNTRY_CODE" "推测可用(人工验证)"
        fi
        return
    fi

    # 检查明确的地区限制信息
    if echo "$content_lower" | grep -q "not available in your region\|not available in your country\|region unavailable"; then
        format_result "TikTok" "failed" "N/A" "区域受限"
        return
    fi

    # 如果成功提取到 region，说明可以访问
    if [ -n "$region" ] && [ "$region" != "null" ]; then
        format_result "TikTok" "success" "$region" "完全解锁"
        return
    fi

    # 检查是否包含 TikTok 内容作为备选判断
    if echo "$content_lower" | grep -q "tiktok" || [ ${#response} -gt 1000 ]; then
        format_result "TikTok" "success" "$COUNTRY_CODE" "完全解锁"
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
        format_result "Imgur" "success" "$region" "完全解锁"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "Imgur" "failed" "N/A" "区域受限"
    elif [ "$status_code" = "301" ] || [ "$status_code" = "302" ]; then
        # 重定向通常表示可访问
        format_result "Imgur" "success" "$region" "完全解锁"
    elif [ "$status_code" = "429" ]; then
        # 速率限制，通常表示服务可访问
        format_result "Imgur" "success" "$region" "完全解锁 (速率限制)"
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
        format_result "Reddit" "partial" "$COUNTRY_CODE" "受限访问 (需登录)"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        # 403/451 也可能是安全拦截
        format_result "Reddit" "partial" "$COUNTRY_CODE" "受限访问 (需登录)"
    elif [ "$status_code" = "200" ]; then
        # 200 且内容没有拦截关键词，才是真正可访问
        format_result "Reddit" "success" "$COUNTRY_CODE" "完全解锁"
    else
        format_result "Reddit" "error" "N/A" "检测失败(${status_code})"
    fi
}

# 检测 Google Gemini - Smart dual detection
check_gemini() {
    local unlock_type=$(check_dns_unlock "generativelanguage.googleapis.com")

    # Gemini unsupported regions (based on official documentation)
    # https://ai.google.dev/gemini-api/docs/available-regions
    local unsupported_regions="CN HK MO CU IR KP RU BY SY VE"

    # Step 0: Check geolocation first (most reliable for Gemini)
    if echo "$unsupported_regions" | grep -qw "$COUNTRY_CODE"; then
        format_result "Gemini" "failed" "N/A" "该地区屏蔽"
        return
    fi

    local api_result=""
    local web_result=""
    local static_result=""
    local studio_result=""

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
            # 403 but not JSON response = likely region restriction
            api_result="region_restricted"
        fi
    elif [ "$api_status" = "451" ]; then
        api_result="region_restricted"
    fi

    # Step 2: Check web endpoint
    local web_response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" -L \
        -w "\n%{http_code}" \
        "https://gemini.google.com/" 2>/dev/null)

    local web_status=$(echo "$web_response" | tail -n 1)
    local web_content=$(echo "$web_response" | head -n -1)

    # Check for 403 - region restriction
    if [ "$web_status" = "403" ]; then
        if echo "$web_content" | grep -qi "access denied"; then
            web_result="region_restricted"
        else
            web_result="access_denied"
        fi
    elif echo "$web_content" | grep -qi "supported in your country\|not available in your country"; then
        web_result="region_restricted"
    elif [ "$web_status" = "200" ]; then
        if echo "$web_content" | grep -qi "sign in\|get started\|continue with google\|chat with gemini"; then
            web_result="success"
        fi
    fi

    # Step 3: Check static resources (if previous checks are inconclusive)
    if [ "$api_result" != "region_restricted" ] && [ "$web_result" != "region_restricted" ]; then
        local static_status=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time $TIMEOUT \
            "https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg" 2>/dev/null)

        if [ "$static_status" = "403" ]; then
            static_result="region_restricted"
        elif [ "$static_status" = "200" ]; then
            static_result="success"
        fi
    fi

    # Step 4: Check AI Studio (alternative endpoint)
    if [ "$api_result" != "region_restricted" ] && [ "$web_result" != "region_restricted" ] && [ "$static_result" != "region_restricted" ]; then
        local studio_status=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            "https://aistudio.google.com/app/prompts/new_chat" 2>/dev/null)

        if [ "$studio_status" = "403" ]; then
            studio_result="region_restricted"
        elif [ "$studio_status" = "200" ] || [ "$studio_status" = "302" ]; then
            studio_result="success"
        fi
    fi

    # Step 5: Intelligent decision (Priority: region restriction > success > access denied)
    if [ "$api_result" = "region_restricted" ] || [ "$web_result" = "region_restricted" ] || [ "$static_result" = "region_restricted" ] || [ "$studio_result" = "region_restricted" ]; then
        format_result "Gemini" "failed" "N/A" "该地区屏蔽"
    elif [ "$api_result" = "success" ] || [ "$web_result" = "success" ] || [ "$static_result" = "success" ] || [ "$studio_result" = "success" ]; then
        format_result "Gemini" "success" "$COUNTRY_CODE" "完全解锁"
    elif [ "$api_result" = "access_denied" ]; then
        format_result "Gemini" "failed" "N/A" "访问被拒"
    else
        format_result "Gemini" "error" "N/A" "检测失败"
    fi
}

# 检测 Spotify
check_spotify() {
    # 参考 IPQuality 项目的实现，使用 Spotify 注册 API
    local response=$(curl -s --max-time $TIMEOUT \
        -X POST \
        -A "$USER_AGENT" \
        -H "Accept-Language: en" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Origin: https://www.spotify.com" \
        -H "Referer: https://www.spotify.com/" \
        --data "birth_day=11&birth_month=11&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https%3A%2F%2Fwww.spotify.com%2F&displayname=Test%20User&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&platform=www&referrer=&send-email=0&thirdpartyemail=0&identifier_token=AgE6YTvEzkReHNfJpO114514" \
        "https://spclient.wg.spotify.com/signup/public/v1/account" 2>/dev/null)

    # 检查响应是否为空
    if [ -z "$response" ]; then
        format_result "Spotify" "error" "N/A" "网络错误"
        return
    fi

    # 检查是否遇到 Access denied（反爬虫）
    if echo "$response" | grep -qi "access denied"; then
        # Spotify 主要不可用地区列表（中国）
        # 由于遇到反爬虫，无法准确检测，对所有地区都显示推测可用
        local detected_country="${COUNTRY_CODE:-Unknown}"
        format_result "Spotify" "partial" "$detected_country" "推测可用(人工验证)"
        return
    fi

    # 检查是否为有效的 JSON
    if ! echo "$response" | grep -q "{"; then
        format_result "Spotify" "error" "N/A" "检测失败"
        return
    fi

    # 提取关键字段
    local region=$(echo "$response" | grep -oP '"country"\s*:\s*"\K[^"]+' | head -n1)
    local is_launched=$(echo "$response" | grep -oP '"is_country_launched"\s*:\s*(true|false)' | grep -oP '(true|false)' | head -n1)
    local status_code=$(echo "$response" | grep -oP '"status"\s*:\s*\K[0-9]+' | head -n1)

    # 判断解锁状态
    if [ "$status_code" = "311" ] && [ "$is_launched" = "true" ]; then
        # 完全解锁
        if [ -n "$region" ] && [ "$region" != "null" ]; then
            format_result "Spotify" "success" "$region" "完全解锁"
        else
            format_result "Spotify" "success" "$COUNTRY_CODE" "完全解锁"
        fi
    elif [ "$status_code" = "320" ] || [ "$status_code" = "120" ]; then
        # IP 被屏蔽（参考 IPQuality 项目）
        format_result "Spotify" "failed" "N/A" "屏蔽"
    else
        # 其他情况
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
        format_result "Google Scholar" "partial" "$COUNTRY_CODE" "受限访问 (机器人)"
    elif [ "$status_code" = "200" ]; then
        format_result "Google Scholar" "success" "$COUNTRY_CODE" "完全解锁"
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
    echo -e "${YELLOW}📺 服务解锁检测结果${NC}"
    print_separator
    # Generate table header with fixed display widths (使用固定列宽常量)
    # 警告：请勿修改列宽参数，这些值与 format_result 函数保持一致
    local header_service=$(pad_to_width "服务名称" $COLUMN_WIDTH_SERVICE)
    local header_status=$(pad_to_width "解锁状态" $COLUMN_WIDTH_STATUS)
    local header_type=$(pad_to_width "解锁类型" $COLUMN_WIDTH_UNLOCK_TYPE)
    local header_region=$(pad_to_width "区域" $COLUMN_WIDTH_REGION)
    echo -e "    ${header_service}: ${header_status} : ${header_type}: ${header_region}"
    print_separator

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

    echo ""
    print_separator
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
                echo "UnlockCheck v${VERSION}"
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
