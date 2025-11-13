#!/bin/bash
#
# StreamCheck 一键安装运行脚本
# 使用方法: bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/streamcheck/main/install.sh)
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本URL
SCRIPT_URL="https://raw.githubusercontent.com/uniquMonte/streamcheck/main/streamcheck.sh"
SCRIPT_NAME="streamcheck.sh"
TEMP_DIR="/tmp/streamcheck_$$"

# 打印消息
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
    print_info "正在下载 StreamCheck 脚本..."

    # 创建临时目录
    mkdir -p "$TEMP_DIR"

    # 下载脚本
    if curl -sL "$SCRIPT_URL" -o "$TEMP_DIR/$SCRIPT_NAME"; then
        print_success "脚本下载成功"
    else
        print_error "脚本下载失败"
        echo "请检查网络连接或手动访问: $SCRIPT_URL"
        exit 1
    fi

    # 添加执行权限
    chmod +x "$TEMP_DIR/$SCRIPT_NAME"
}

# 运行检测
run_check() {
    print_info "启动流媒体解锁检测...\n"

    # 执行脚本
    cd "$TEMP_DIR"
    ./"$SCRIPT_NAME" "$@"
}

# 提示安装选项
show_install_option() {
    echo ""
    print_info "是否要将脚本安装到系统? (y/N)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_to_system
    else
        print_info "跳过安装，临时文件将在退出时自动清理"
    fi
}

# 安装到系统
install_to_system() {
    local install_dir="$HOME/.local/bin"
    local install_path="$install_dir/streamcheck"

    # 创建目录
    mkdir -p "$install_dir"

    # 复制脚本
    cp "$TEMP_DIR/$SCRIPT_NAME" "$install_path"
    chmod +x "$install_path"

    print_success "已安装到: $install_path"

    # 检查 PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warning "请将以下行添加到 ~/.bashrc 或 ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "然后运行: source ~/.bashrc (或 source ~/.zshrc)"
    fi

    print_success "安装完成! 下次可以直接运行: streamcheck"
}

# 主函数
main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         StreamCheck - 流媒体解锁检测工具                  ║"
    echo "║                   一键安装运行脚本                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 检查依赖
    check_dependencies

    # 下载脚本
    download_script

    # 运行检测
    run_check "$@"

    # 提示安装选项
    show_install_option
}

# 运行主函数
main "$@"
