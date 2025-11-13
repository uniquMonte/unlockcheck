#!/bin/bash
#
# StreamCheck - Streaming Media Unlock Detection Tool (Bash Version)
# One-click detection of streaming media unlock status for current network
#

VERSION="1.2"
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
IP_INFO=""
COUNTRY_CODE=""
CURRENT_IP=""
IP_TYPE="Unknown"
IP_ISP=""
IP_ASN=""
IP_USAGE_LOCATION=""
IP_REGISTRATION_LOCATION=""

# Print header
print_header() {
    echo -e "\n${CYAN}============================================================"
    echo -e "       StreamCheck - Media Unlock Detection Tool v${VERSION}"
    echo -e "============================================================${NC}\n"
}

# Logging functions
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

# Check dependencies
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed, please install curl first"
        exit 1
    fi
}

# Get IP information (enhanced)
get_ip_info() {
    log_info "Fetching IP information..."

    # Try using ipapi.co
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

            # Detect IP type
            detect_ip_type

            # Print IP info
            print_enhanced_ip_info
            return 0
        fi
    fi

    # Fallback 1: use ipinfo.io
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

            # Detect IP type
            detect_ip_type

            # Print IP info
            print_enhanced_ip_info
            return 0
        fi
    fi

    # Fallback 2: use ip-api.com (no API key needed)
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

            # Detect IP type
            detect_ip_type

            # Print IP info
            print_enhanced_ip_info
            return 0
        fi
    fi

    # Last fallback: only get IP address
    CURRENT_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    if [ -z "$CURRENT_IP" ]; then
        CURRENT_IP=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null | tr -d '\n')
    fi

    if [ -n "$CURRENT_IP" ]; then
        log_warning "Only obtained IP address: ${CURRENT_IP}, unable to get detailed location info"
        # Even without complete info, try to detect IP type
        detect_ip_type
        echo -e "\n${YELLOW}🌍 Current IP Information${NC}"
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo -e "IP Address: ${GREEN}${CURRENT_IP}${NC}"
        echo -e "IP Type: ${YELLOW}${IP_TYPE}${NC}"
        echo ""
        return 0
    fi

    log_error "Unable to obtain IP information, continuing detection (region info may be inaccurate)"
    return 1
}

# Detect IP type (residential vs datacenter)
detect_ip_type() {
    # Get more detailed IP info via ip-api.com
    local ip_detail=$(curl -s --max-time $TIMEOUT \
        "http://ip-api.com/json/${CURRENT_IP}?fields=hosting,proxy,mobile,country,countryCode,regionName,city,isp,org,as" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$ip_detail" ]; then
        local is_hosting=$(echo "$ip_detail" | grep -oP '"hosting":\K(true|false)' | head -1)
        local is_proxy=$(echo "$ip_detail" | grep -oP '"proxy":\K(true|false)' | head -1)
        local is_mobile=$(echo "$ip_detail" | grep -oP '"mobile":\K(true|false)' | head -1)

        # Get ASN info (contains registration location)
        IP_ASN=$(echo "$ip_detail" | grep -oP '"as":"\K[^"]+' | head -1)

        # Usage location: actual geographic location of IP (country only)
        local country=$(echo "$ip_detail" | grep -oP '"country":"\K[^"]+' | head -1)
        IP_USAGE_LOCATION="$country"

        # Registration location: try to get country where IP block is registered
        # Method 1: try to query ASN registration country
        local asn_num=$(echo "$IP_ASN" | grep -oP 'AS\K[0-9]+' | head -1)
        if [ -n "$asn_num" ]; then
            # Query ASN registration country
            local asn_info=$(curl -s --max-time 3 "https://api.bgpview.io/asn/${asn_num}" 2>/dev/null)
            local reg_country=$(echo "$asn_info" | grep -oP '"country_code":"\K[^"]+' | head -1)

            if [ -n "$reg_country" ]; then
                # Convert country code to country name
                IP_REGISTRATION_LOCATION=$(convert_country_code "$reg_country")
            fi
        fi

        # If unable to get from ASN, use fallback
        if [ -z "$IP_REGISTRATION_LOCATION" ]; then
            local org=$(echo "$ip_detail" | grep -oP '"org":"\K[^"]+' | head -1)
            # Check common ISP countries
            IP_REGISTRATION_LOCATION=$(guess_isp_country "$org")
        fi

        if [ "$is_hosting" = "true" ] || [ "$is_proxy" = "true" ]; then
            IP_TYPE="Datacenter/Hosting"
        elif [ "$is_mobile" = "true" ]; then
            IP_TYPE="Mobile Network"
        else
            IP_TYPE="Residential"
        fi
    else
        IP_TYPE="Unknown"
    fi
}

# Convert country code to country name
convert_country_code() {
    local code="$1"
    case "$code" in
        "US") echo "United States" ;;
        "CA") echo "Canada" ;;
        "GB") echo "United Kingdom" ;;
        "DE") echo "Germany" ;;
        "FR") echo "France" ;;
        "JP") echo "Japan" ;;
        "CN") echo "China" ;;
        "HK") echo "Hong Kong" ;;
        "SG") echo "Singapore" ;;
        "AU") echo "Australia" ;;
        "NL") echo "Netherlands" ;;
        "KR") echo "South Korea" ;;
        "TW") echo "Taiwan" ;;
        "IN") echo "India" ;;
        "BR") echo "Brazil" ;;
        "RU") echo "Russia" ;;
        *) echo "$code" ;;
    esac
}

# Guess ISP country from organization name (common ISPs)
guess_isp_country() {
    local org="$1"
    local org_lower=$(echo "$org" | tr '[:upper:]' '[:lower:]')

    if [[ "$org_lower" == *"hostpapa"* ]]; then echo "Canada"
    elif [[ "$org_lower" == *"cloudflare"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"google"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"amazon"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"microsoft"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"digitalocean"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"linode"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"vultr"* ]]; then echo "United States"
    elif [[ "$org_lower" == *"alibaba"* ]]; then echo "China"
    elif [[ "$org_lower" == *"tencent"* ]]; then echo "China"
    elif [[ "$org_lower" == *"ovh"* ]]; then echo "France"
    elif [[ "$org_lower" == *"hetzner"* ]]; then echo "Germany"
    else echo "Datacenter"
    fi
}

# Print enhanced IP information
print_enhanced_ip_info() {
    echo -e "\n${YELLOW}🌍 Current IP Information${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo -e "IP Address: ${GREEN}${CURRENT_IP}${NC}"

    # Display IP type (with colors)
    local type_color
    case "$IP_TYPE" in
        "Residential")
            type_color="${GREEN}"
            ;;
        "Datacenter/Hosting")
            type_color="${YELLOW}"
            ;;
        "Mobile Network")
            type_color="${CYAN}"
            ;;
        *)
            type_color="${NC}"
            ;;
    esac
    echo -e "IP Type: ${type_color}${IP_TYPE}${NC}"

    # Display usage location (IP's geographic location)
    if [ -n "$IP_USAGE_LOCATION" ] && [ "$IP_USAGE_LOCATION" != "  " ]; then
        echo -e "Usage Location: ${IP_USAGE_LOCATION}"
    else
        echo -e "Usage Location: ${IP_INFO}"
    fi

    # Display registration location (ISP/ASN registration info)
    if [ -n "$IP_REGISTRATION_LOCATION" ]; then
        echo -e "Registered In: ${IP_REGISTRATION_LOCATION}"
    fi

    echo -e "ISP: ${IP_ISP}"

    # Display ASN info
    if [ -n "$IP_ASN" ]; then
        echo -e "ASN: ${IP_ASN}"
    fi

    echo ""
}

# Format output results
format_result() {
    local service_name="$1"
    local status="$2"
    local region="$3"
    local detail="$4"

    # Format service name (fixed width)
    local service_formatted=$(printf "%-15s" "$service_name")

    # Select icon and color
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

    # Build detailed info
    local info="$detail"
    if [ "$region" != "N/A" ] && [ "$region" != "Unknown" ] && [ -n "$region" ]; then
        info="$info ${CYAN}(Region: $region)${NC}"
    fi

    echo -e "$icon $service_formatted: ${color}${info}${NC}"
}

# Check Netflix
check_netflix() {
    # First check Netflix original content (to determine full unlock)
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -w "\n%{http_code}" \
        "https://www.netflix.com/title/80018499" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local region="${COUNTRY_CODE:-Unknown}"

    if [ "$status_code" = "200" ]; then
        # Try to extract region info from response
        if [ -z "$COUNTRY_CODE" ] || [ "$COUNTRY_CODE" = "Unknown" ]; then
            # If no region code, try to get from cookie or redirect
            region=$(echo "$response" | grep -oP 'country-code=\K[A-Z]{2}' | head -1)
            [ -z "$region" ] && region="Unknown"
        fi
        format_result "Netflix" "success" "$region" "Full Access"
    elif [ "$status_code" = "403" ]; then
        format_result "Netflix" "failed" "N/A" "Blocked"
    elif [ "$status_code" = "404" ]; then
        # 404 means content unavailable, possibly only originals
        format_result "Netflix" "partial" "$region" "Originals Only"
    else
        # Try accessing homepage
        response=$(curl -s --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            -w "\n%{http_code}" \
            "https://www.netflix.com/" 2>/dev/null)

        status_code=$(echo "$response" | tail -n 1)

        if [ "$status_code" = "200" ]; then
            format_result "Netflix" "success" "$region" "Accessible"
        else
            format_result "Netflix" "error" "N/A" "Detection Failed"
        fi
    fi
}

# Check Disney+
check_disney() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.disneyplus.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Disney+" "success" "$COUNTRY_CODE" "Full Access"
    elif [ "$status_code" = "403" ]; then
        format_result "Disney+" "failed" "N/A" "Blocked"
    else
        format_result "Disney+" "error" "N/A" "Detection Failed"
    fi
}

# Check YouTube Premium
check_youtube() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://www.youtube.com/premium" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "YouTube Premium" "success" "$COUNTRY_CODE" "Supported"
    else
        format_result "YouTube Premium" "error" "N/A" "Detection Failed"
    fi
}

# Check ChatGPT
check_chatgpt() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://chat.openai.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "ChatGPT" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ]; then
        format_result "ChatGPT" "failed" "N/A" "Region Restricted"
    else
        format_result "ChatGPT" "error" "N/A" "Detection Failed"
    fi
}

# Check Claude
check_claude() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://claude.ai/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Claude" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ]; then
        format_result "Claude" "failed" "N/A" "Region Restricted"
    else
        format_result "Claude" "error" "N/A" "Detection Failed"
    fi
}

# Check TikTok
check_tiktok() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.tiktok.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "TikTok" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "TikTok" "failed" "N/A" "Region Restricted"
    else
        format_result "TikTok" "error" "N/A" "Detection Failed"
    fi
}

# Check Imgur
check_imgur() {
    # Check Imgur with more lenient timeout and retry
    local response=$(curl -s --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        -w "\n%{http_code}" \
        "https://imgur.com/" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)
    local region="${COUNTRY_CODE:-Unknown}"

    # Check if curl executed successfully
    if [ -z "$status_code" ]; then
        # Try fallback URL
        status_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time $TIMEOUT \
            -A "$USER_AGENT" \
            "https://i.imgur.com/" 2>/dev/null)
    fi

    if [ "$status_code" = "200" ]; then
        format_result "Imgur" "success" "$region" "Accessible"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "Imgur" "failed" "N/A" "Region Restricted"
    elif [ "$status_code" = "301" ] || [ "$status_code" = "302" ]; then
        # Redirect usually means accessible
        format_result "Imgur" "success" "$region" "Accessible"
    elif [ "$status_code" = "429" ]; then
        # Rate limit, usually means service is accessible
        format_result "Imgur" "success" "$region" "Accessible (Rate Limited)"
    elif [ -z "$status_code" ] || [ "$status_code" = "000" ]; then
        format_result "Imgur" "error" "N/A" "Connection Timeout"
    else
        format_result "Imgur" "error" "N/A" "Detection Failed (${status_code})"
    fi
}

# Check Reddit
check_reddit() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://www.reddit.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Reddit" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ] || [ "$status_code" = "451" ]; then
        format_result "Reddit" "failed" "N/A" "Region Restricted"
    else
        format_result "Reddit" "error" "N/A" "Detection Failed"
    fi
}

# Check Google Gemini
check_gemini() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://gemini.google.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Gemini" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ]; then
        format_result "Gemini" "failed" "N/A" "Region Restricted"
    else
        format_result "Gemini" "error" "N/A" "Detection Failed"
    fi
}

# Check Spotify
check_spotify() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://open.spotify.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Spotify" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ]; then
        format_result "Spotify" "failed" "N/A" "Region Restricted"
    else
        format_result "Spotify" "error" "N/A" "Detection Failed"
    fi
}

# Check Google Scholar
check_scholar() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        -L \
        "https://scholar.google.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "Google Scholar" "success" "$COUNTRY_CODE" "Accessible"
    elif [ "$status_code" = "403" ]; then
        format_result "Google Scholar" "failed" "N/A" "Region Restricted"
    elif [ "$status_code" = "429" ]; then
        format_result "Google Scholar" "failed" "N/A" "Verification Required/IP Restricted"
    else
        format_result "Google Scholar" "error" "N/A" "Detection Failed"
    fi
}

# Run all checks
run_all_checks() {
    echo -e "${YELLOW}📺 Streaming Media Detection Results${NC}"
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
    echo -e "Detection Complete!\n"
}

# Show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --fast          Fast detection mode (no delay)"
    echo "  --help, -h      Show help information"
    echo "  --version, -v   Show version information"
    echo ""
    echo "Examples:"
    echo "  $0              Run full detection"
    echo "  $0 --fast       Fast detection"
}

# Main function
main() {
    # Check dependencies
    check_dependencies

    # Parse arguments
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
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Print header
    print_header

    # Get IP info
    get_ip_info

    # Run detections
    run_all_checks
}

# Capture Ctrl+C
trap 'echo -e "\n\n${YELLOW}Detection Cancelled${NC}"; exit 0' INT

# Run main function
main "$@"
