#!/bin/bash
#
# UnlockCheck 一键安装脚本
# 用法:
#   bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/unlockcheck/main/install.sh)
#
# 使用特定分支:
#   BRANCH=main bash <(curl -Ls https://raw.githubusercontent.com/.../install.sh)
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置：可通过环境变量覆盖
GITHUB_REPO="${GITHUB_REPO:-uniquMonte/unlockcheck}"
BRANCH="${BRANCH:-main}"
SCRIPT_NAME="unlockcheck.sh"
TEMP_DIR="/tmp/unlockcheck_$$"

# 构建脚本URL
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${BRANCH}/${SCRIPT_NAME}"

# 打印消息函数
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# 清理函数
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 检查依赖
check_dependencies() {
    print_info "检查系统依赖..."

    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装"
        echo "请先安装 curl:"
        echo "  Ubuntu/Debian: sudo apt-get install curl"
        echo "  CentOS/RHEL:   sudo yum install curl"
        echo "  macOS:         brew install curl"
        exit 1
    fi

    print_success "依赖检查完成"
}

# 下载脚本
download_script() {
    print_info "正在下载 UnlockCheck 脚本..."
    print_info "仓库: ${GITHUB_REPO}"
    print_info "分支: ${BRANCH}"

    # 创建临时目录
    mkdir -p "$TEMP_DIR"

    # 下载脚本
    print_info "下载地址: ${SCRIPT_URL}"
    if curl -fsSL "$SCRIPT_URL" -o "$TEMP_DIR/$SCRIPT_NAME" 2>/dev/null; then
        # 检查下载的文件是否有效
        if [ -s "$TEMP_DIR/$SCRIPT_NAME" ] && head -n 1 "$TEMP_DIR/$SCRIPT_NAME" | grep -q "^#!/bin/bash"; then
            print_success "脚本下载成功"
        else
            print_error "下载的文件无效（可能是404页面）"
            echo ""
            echo "可能的原因:"
            echo "  1. 分支 '${BRANCH}' 不存在"
            echo "  2. 文件路径不正确"
            echo ""
            echo "请尝试使用开发分支:"
            echo "  BRANCH=claude/ip-geolocation-check-011CV5N8uHpGcyDHU2hDWRYa bash <(curl -Ls ...)"
            rm -f "$TEMP_DIR/$SCRIPT_NAME"
            exit 1
        fi
    else
        print_error "脚本下载失败"
        echo ""
        echo "请检查:"
        echo "  1. 网络连接正常"
        echo "  2. URL 是否正确: $SCRIPT_URL"
        echo ""
        echo "或尝试手动下载:"
        echo "  curl -O $SCRIPT_URL"
        exit 1
    fi

    # 添加执行权限
    chmod +x "$TEMP_DIR/$SCRIPT_NAME"
}

# 运行检测
run_check() {
    print_info "开始服务解锁检测...\n"

    # 执行脚本
    cd "$TEMP_DIR"
    ./"$SCRIPT_NAME" "$@"
}

# 显示安装选项
show_install_option() {
    echo ""
    print_info "是否要将脚本安装到系统? (y/N)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_to_system
    else
        print_info "跳过安装，临时文件将在退出时清理"
    fi
}

# 安装到系统
install_to_system() {
    local install_dir="$HOME/.local/bin"
    local install_path="$install_dir/unlockcheck"

    # 创建目录
    mkdir -p "$install_dir"

    # 复制脚本
    cp "$TEMP_DIR/$SCRIPT_NAME" "$install_path"
    chmod +x "$install_path"

    print_success "已安装到: $install_path"

    # 检查 PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warning "请将以下内容添加到 ~/.bashrc 或 ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "然后运行: source ~/.bashrc (或 source ~/.zshrc)"
    fi

    print_success "安装完成！现在可以运行: unlockcheck"
}

# 主函数
main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         UnlockCheck - 服务解锁检测工具                     ║"
    echo "║              一键安装脚本                                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 检查依赖
    check_dependencies

    # 下载脚本
    download_script

    # 运行检测
    run_check "$@"

    # 显示安装选项
    show_install_option
}

# 运行主函数
main "$@"
