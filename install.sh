#!/bin/bash
#
# StreamCheck One-Click Installation Script
# Usage:
#   bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/streamcheck/main/install.sh)
#
# Use specific branch:
#   BRANCH=main bash <(curl -Ls https://raw.githubusercontent.com/.../install.sh)
#

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration: can be overridden by environment variables
GITHUB_REPO="${GITHUB_REPO:-uniquMonte/streamcheck}"
BRANCH="${BRANCH:-main}"
SCRIPT_NAME="streamcheck.sh"
TEMP_DIR="/tmp/streamcheck_$$"

# Build script URL
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${BRANCH}/${SCRIPT_NAME}"

# Print message functions
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

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies() {
    print_info "Checking system dependencies..."

    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        echo "Please install curl first:"
        echo "  Ubuntu/Debian: sudo apt-get install curl"
        echo "  CentOS/RHEL:   sudo yum install curl"
        echo "  macOS:         brew install curl"
        exit 1
    fi

    print_success "Dependency check completed"
}

# Download script
download_script() {
    print_info "Downloading StreamCheck script..."
    print_info "Repository: ${GITHUB_REPO}"
    print_info "Branch: ${BRANCH}"

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Download script
    print_info "Download URL: ${SCRIPT_URL}"
    if curl -fsSL "$SCRIPT_URL" -o "$TEMP_DIR/$SCRIPT_NAME" 2>/dev/null; then
        # Check if downloaded file is valid
        if [ -s "$TEMP_DIR/$SCRIPT_NAME" ] && head -n 1 "$TEMP_DIR/$SCRIPT_NAME" | grep -q "^#!/bin/bash"; then
            print_success "Script downloaded successfully"
        else
            print_error "Downloaded file is invalid (may be a 404 page)"
            echo ""
            echo "Possible causes:"
            echo "  1. Branch '${BRANCH}' does not exist"
            echo "  2. File path is incorrect"
            echo ""
            echo "Try using development branch:"
            echo "  BRANCH=claude/streaming-unlock-detector-011CV57GxrMmMPUDAAu5JKt6 bash <(curl -Ls ...)"
            rm -f "$TEMP_DIR/$SCRIPT_NAME"
            exit 1
        fi
    else
        print_error "Script download failed"
        echo ""
        echo "Please check:"
        echo "  1. Network connection is normal"
        echo "  2. URL is correct: $SCRIPT_URL"
        echo ""
        echo "Or try manual download:"
        echo "  curl -O $SCRIPT_URL"
        exit 1
    fi

    # Add execute permission
    chmod +x "$TEMP_DIR/$SCRIPT_NAME"
}

# Run detection
run_check() {
    print_info "Starting media unlock detection...\n"

    # Execute script
    cd "$TEMP_DIR"
    ./"$SCRIPT_NAME" "$@"
}

# Show installation option
show_install_option() {
    echo ""
    print_info "Do you want to install the script to your system? (y/N)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_to_system
    else
        print_info "Skipping installation, temporary files will be cleaned up on exit"
    fi
}

# Install to system
install_to_system() {
    local install_dir="$HOME/.local/bin"
    local install_path="$install_dir/streamcheck"

    # Create directory
    mkdir -p "$install_dir"

    # Copy script
    cp "$TEMP_DIR/$SCRIPT_NAME" "$install_path"
    chmod +x "$install_path"

    print_success "Installed to: $install_path"

    # Check PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warning "Please add the following line to ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "Then run: source ~/.bashrc (or source ~/.zshrc)"
    fi

    print_success "Installation complete! You can now run: streamcheck"
}

# Main function
main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         StreamCheck - Media Unlock Detection Tool         ║"
    echo "║              One-Click Installation Script                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Check dependencies
    check_dependencies

    # Download script
    download_script

    # Run detection
    run_check "$@"

    # Show installation option
    show_install_option
}

# Run main function
main "$@"
