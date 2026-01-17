#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Alertmanager Silence Manager - Installer
# ============================================

GITHUB_REPO="jfpucheu/alertmanager-silence-manager"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
TEMP_DIR=$(mktemp -d)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🔕 Alertmanager Silence Manager                   ║
║        Installation Script                            ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}" >&2; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing=0
    
    for cmd in curl jq kubectl; do
        if command -v "$cmd" &> /dev/null; then
            print_success "$cmd installed"
        else
            print_error "$cmd missing"
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        echo
        print_error "Some dependencies are missing."
        echo
        echo "Installing dependencies:"
        echo
        echo "  Ubuntu/Debian:"
        echo "    sudo apt update && sudo apt install -y jq kubectl curl"
        echo
        echo "  macOS:"
        echo "    brew install jq kubectl"
        echo
        exit 1
    fi
}

download_latest_release() {
    print_info "Downloading latest version..."
    
    # Try to download from GitHub
    if curl -sL "https://github.com/${GITHUB_REPO}/archive/refs/heads/main.zip" \
        -o "${TEMP_DIR}/alertmanager-silence-manager.zip"; then
        print_success "Download successful"
    else
        print_error "Download failed"
        print_info "Check your internet connection or the repository URL"
        exit 1
    fi
}

extract_files() {
    print_info "Extracting files..."
    
    cd "$TEMP_DIR"
    
    if command -v unzip &> /dev/null; then
        unzip -q alertmanager-silence-manager.zip
    else
        print_error "unzip is not installed"
        exit 1
    fi
    
    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find . -maxdepth 1 -type d -name "*alertmanager-silence-manager*" | head -n1)
    
    if [[ -z "$extracted_dir" ]]; then
        print_error "Cannot find extracted files"
        exit 1
    fi
    
    print_success "Files extracted"
}

install_scripts() {
    print_info "Installing to $INSTALL_DIR..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy scripts
    local extracted_dir
    extracted_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "*alertmanager-silence-manager*" | head -n1)
    
    cp "$extracted_dir"/*.sh "$INSTALL_DIR/"
    cp "$extracted_dir"/am "$INSTALL_DIR/"
    
    # Make executable
    chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/am
    
    print_success "Scripts installed"
}

update_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_warning "$INSTALL_DIR is not in your PATH"
        echo
        print_info "Add this line to your ~/.bashrc or ~/.zshrc:"
        echo
        echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        echo
        print_info "Then reload your shell with:"
        echo
        echo "  source ~/.bashrc  # or ~/.zshrc for zsh"
        echo
    fi
}

cleanup() {
    print_info "Cleaning up..."
    rm -rf "$TEMP_DIR"
    print_success "Cleanup completed"
}

main() {
    print_banner
    
    check_dependencies
    echo
    
    download_latest_release
    echo
    
    extract_files
    echo
    
    install_scripts
    echo
    
    update_path
    
    cleanup
    echo
    
    print_success "Installation completed!"
    echo
    print_info "Usage:"
    echo "  am                    # Launch interactive menu"
    echo "  am create 60          # Create 1h silence"
    echo "  am list               # List silences"
    echo "  am help               # Show help"
    echo
    print_info "Complete documentation: https://github.com/${GITHUB_REPO}"
}

# Error handling
trap cleanup EXIT

main "$@"
