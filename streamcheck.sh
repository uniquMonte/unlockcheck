#!/bin/bash
#
# StreamCheck - 流媒体解锁检测工具 (Bash版本)
# 一键检测当前网络环境对各大流媒体平台的解锁情况
#

VERSION="1.0"
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

# 获取 IP 信息
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

        IP_INFO="$country $region $city"

        # 打印 IP 信息
        echo -e "\n${YELLOW}🌍 当前 IP 信息${NC}"
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo -e "IP 地址: ${GREEN}${CURRENT_IP}${NC}"
        echo -e "位置: ${IP_INFO}"
        echo -e "ISP: ${isp}\n"
        return 0
    fi

    # 备用方案：使用 ipinfo.io
    response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://ipinfo.io/json" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
        CURRENT_IP=$(echo "$response" | grep -oP '"ip":"\K[^"]+' | head -1)
        COUNTRY_CODE=$(echo "$response" | grep -oP '"country":"\K[^"]+' | head -1)
        local city=$(echo "$response" | grep -oP '"city":"\K[^"]+' | head -1)
        local region=$(echo "$response" | grep -oP '"region":"\K[^"]+' | head -1)
        local isp=$(echo "$response" | grep -oP '"org":"\K[^"]+' | head -1)

        IP_INFO="$region $city"

        echo -e "\n${YELLOW}🌍 当前 IP 信息${NC}"
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo -e "IP 地址: ${GREEN}${CURRENT_IP}${NC}"
        echo -e "位置: ${IP_INFO}"
        echo -e "ISP: ${isp}\n"
        return 0
    fi

    log_error "无法获取 IP 信息"
    return 1
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
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://www.netflix.com/title/80018499" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Netflix" "success" "$COUNTRY_CODE" "完整解锁"
    elif [ "$status_code" = "403" ]; then
        format_result "Netflix" "failed" "N/A" "不支持"
    elif [ "$status_code" = "404" ]; then
        format_result "Netflix" "partial" "$COUNTRY_CODE" "仅自制剧"
    else
        # 尝试主页
        status_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            "https://www.netflix.com/" 2>/dev/null)

        if [ "$status_code" = "200" ]; then
            format_result "Netflix" "success" "$COUNTRY_CODE" "支持"
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

# 运行所有检测
run_all_checks() {
    echo -e "${YELLOW}📺 流媒体检测结果${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"

    check_netflix
    sleep 0.5

    check_disney
    sleep 0.5

    check_youtube
    sleep 0.5

    check_chatgpt
    sleep 0.5

    check_claude
    sleep 0.5

    check_tiktok

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
