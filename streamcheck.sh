#!/bin/bash
#
# StreamCheck - 流媒体解锁检测工具 (Bash版本)
# 一键检测当前网络环境对各大流媒体平台的解锁情况
#

VERSION="1.2"
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
    echo -e "          StreamCheck - 流媒体解锁检测工具 v${VERSION}"
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

            # 打印 IP 信息
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

            # 打印 IP 信息
            print_enhanced_ip_info
            return 0
        fi
    fi

    # 备用方案2：使用 ipapi.com（无需API密钥）
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

            # 打印 IP 信息
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

    log_error "无法获取 IP 信息，将继续进行检测（区域信息可能不准确）"
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

        # 获取ASN信息（包含注册地信息）
        IP_ASN=$(echo "$ip_detail" | grep -oP '"as":"\K[^"]+' | head -1)

        # 使用地：IP的实际地理位置
        local country=$(echo "$ip_detail" | grep -oP '"country":"\K[^"]+' | head -1)
        local region=$(echo "$ip_detail" | grep -oP '"regionName":"\K[^"]+' | head -1)
        local city=$(echo "$ip_detail" | grep -oP '"city":"\K[^"]+' | head -1)
        IP_USAGE_LOCATION="$country $region $city"

        # 注册地：从ISP/组织信息推断
        local org=$(echo "$ip_detail" | grep -oP '"org":"\K[^"]+' | head -1)
        if [ -n "$org" ]; then
            # 对于数据中心IP，注册地通常是ISP的注册国家
            # 从ASN信息中提取国家代码或公司信息
            if [[ "$IP_ASN" =~ ([A-Z]{2})[[:space:]] ]]; then
                IP_REGISTRATION_LOCATION="${BASH_REMATCH[1]}"
            else
                # 从组织名称推断（这是近似值）
                IP_REGISTRATION_LOCATION="$org"
            fi
        fi

        if [ "$is_hosting" = "true" ] || [ "$is_proxy" = "true" ]; then
            IP_TYPE="广播IP/数据中心"
        elif [ "$is_mobile" = "true" ]; then
            IP_TYPE="移动网络"
        else
            IP_TYPE="原生住宅IP"
        fi
    else
        IP_TYPE="未知"
    fi
}

# 打印增强的IP信息
print_enhanced_ip_info() {
    echo -e "\n${YELLOW}🌍 当前 IP 信息${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo -e "IP 地址: ${GREEN}${CURRENT_IP}${NC}"

    # IP类型显示（带颜色）
    local type_color
    case "$IP_TYPE" in
        "原生住宅IP")
            type_color="${GREEN}"
            ;;
        "广播IP/数据中心")
            type_color="${YELLOW}"
            ;;
        "移动网络")
            type_color="${CYAN}"
            ;;
        *)
            type_color="${NC}"
            ;;
    esac
    echo -e "IP 类型: ${type_color}${IP_TYPE}${NC}"

    # 显示使用地（IP的地理位置）
    if [ -n "$IP_USAGE_LOCATION" ] && [ "$IP_USAGE_LOCATION" != "  " ]; then
        echo -e "使用地: ${IP_USAGE_LOCATION}"
    else
        echo -e "使用地: ${IP_INFO}"
    fi

    # 显示注册地（ISP/ASN注册信息）
    if [ -n "$IP_REGISTRATION_LOCATION" ]; then
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
format_result() {
    local service_name="$1"
    local status="$2"
    local region="$3"
    local detail="$4"

    # 格式化服务名称（固定宽度）
    local service_formatted=$(printf "%-15s" "$service_name")

    # 选择图标和颜色
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

    # 构建详细信息
    local info="$detail"
    if [ "$region" != "N/A" ] && [ "$region" != "Unknown" ] && [ -n "$region" ]; then
        info="$info ${CYAN}(区域: $region)${NC}"
    fi

    echo -e "$icon $service_formatted: ${color}${info}${NC}"
}

# 检测 Netflix
check_netflix() {
    # 先检测Netflix原创内容（用于判断完整解锁）
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -w "\n%{http_code}" \
        "https://www.netflix.com/title/80018499" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local region="${COUNTRY_CODE:-Unknown}"

    if [ "$status_code" = "200" ]; then
        # 尝试从响应中提取区域信息
        if [ -z "$COUNTRY_CODE" ] || [ "$COUNTRY_CODE" = "Unknown" ]; then
            # 如果没有区域码，尝试从cookie或重定向中获取
            region=$(echo "$response" | grep -oP 'country-code=\K[A-Z]{2}' | head -1)
            [ -z "$region" ] && region="Unknown"
        fi
        format_result "Netflix" "success" "$region" "完整解锁"
    elif [ "$status_code" = "403" ]; then
        format_result "Netflix" "failed" "N/A" "不支持"
    elif [ "$status_code" = "404" ]; then
        # 404表示内容不可用，可能是仅自制剧
        format_result "Netflix" "partial" "$region" "仅自制剧"
    else
        # 尝试访问主页
        response=$(curl -s --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            -w "\n%{http_code}" \
            "https://www.netflix.com/" 2>/dev/null)

        status_code=$(echo "$response" | tail -n 1)

        if [ "$status_code" = "200" ]; then
            format_result "Netflix" "success" "$region" "可访问"
        else
            format_result "Netflix" "error" "N/A" "检测失败"
        fi
    fi
}

# 检测 Disney+
check_disney() {
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
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://chat.openai.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "ChatGPT" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ]; then
        format_result "ChatGPT" "failed" "N/A" "区域受限"
    else
        format_result "ChatGPT" "error" "N/A" "检测失败"
    fi
}

# 检测 Claude
check_claude() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://claude.ai/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Claude" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ]; then
        format_result "Claude" "failed" "N/A" "区域受限"
    else
        format_result "Claude" "error" "N/A" "检测失败"
    fi
}

# 检测 TikTok
check_tiktok() {
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
    # 检测Imgur，使用更宽容的超时和重试
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://imgur.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local region="${COUNTRY_CODE:-Unknown}"

    # 检查curl是否成功执行
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
        # 重定向通常表示可以访问
        format_result "Imgur" "success" "$region" "可访问"
    elif [ -z "$status_code" ] || [ "$status_code" = "000" ]; then
        format_result "Imgur" "error" "N/A" "连接超时"
    else
        format_result "Imgur" "error" "N/A" "检测失败(${status_code})"
    fi
}

# 检测 Reddit
check_reddit() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.reddit.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Reddit" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "Reddit" "failed" "N/A" "区域受限"
    else
        format_result "Reddit" "error" "N/A" "检测失败"
    fi
}

# 检测 Google Gemini
check_gemini() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://gemini.google.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Gemini" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ]; then
        format_result "Gemini" "failed" "N/A" "区域受限"
    else
        format_result "Gemini" "error" "N/A" "检测失败"
    fi
}

# 检测 Spotify
check_spotify() {
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
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://scholar.google.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Google Scholar" "success" "$COUNTRY_CODE" "可访问"
    elif [ "$status_code" = "403" ]; then
        format_result "Google Scholar" "failed" "N/A" "区域受限"
    elif [ "$status_code" = "429" ]; then
        format_result "Google Scholar" "failed" "N/A" "需要验证/IP被限制"
    else
        format_result "Google Scholar" "error" "N/A" "检测失败"
    fi
}

# 运行所有检测
run_all_checks() {
    echo -e "${YELLOW}📺 流媒体检测结果${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"

    check_netflix
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_disney
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_youtube
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_chatgpt
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_claude
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_gemini
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_scholar
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_tiktok
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_imgur
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_reddit
    [ -z "$FAST_MODE" ] && sleep 0.5

    check_spotify

    echo -e "\n${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo -e "检测完成!\n"
}

# 显示帮助
show_help() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --fast          快速检测模式（不延迟）"
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

    # 获取 IP 信息
    get_ip_info

    # 运行检测
    run_all_checks
}

# 捕获 Ctrl+C
trap 'echo -e "\n\n${YELLOW}检测已取消${NC}"; exit 0' INT

# 运行主函数
main "$@"
