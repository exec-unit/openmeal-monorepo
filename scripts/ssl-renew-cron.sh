#!/usr/bin/env bash
# SSL Certificate Auto-Renewal Script for OpenMeal
# This script handles automatic SSL certificate renewal using certbot
# Supports both systemd timers and cron jobs
# Cross-platform compatible: Linux, macOS, Windows (WSL only)

set -e

# OS Detection and compatibility check
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# Check OS compatibility for SSL operations
check_os_compatibility() {
    case "$OS_TYPE" in
        "linux"|"macos")
            return 0
            ;;
        "windows")
            # Check if running in WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                warn "Running in WSL - SSL renewal supported"
                return 0
            else
                error "SSL certificate renewal is not supported on native Windows"
                error "Please use WSL (Windows Subsystem for Linux) or run this on a Linux server"
                error ""
                error "To install WSL:"
                error "  1. Open PowerShell as Administrator"
                error "  2. Run: wsl --install"
                error "  3. Restart your computer"
                error "  4. Run this script from within WSL"
                exit 1
            fi
            ;;
        *)
            error "Unknown operating system: $(uname -s)"
            error "This script supports: Linux, macOS, Windows (WSL only)"
            exit 1
            ;;
    esac
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_NAME="openmeal-ssl-renew"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to renew certificates
renew_certificates() {
    check_os_compatibility
    
    log "Starting SSL certificate renewal check..."
    
    cd "$PROJECT_DIR"
    
    # Check if docker is available
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if make is available
    if ! command -v make >/dev/null 2>&1; then
        error "Make is not installed or not in PATH"
        error "Please install make: sudo apt-get install make (Linux) or brew install make (macOS)"
        exit 1
    fi
    
    # Run certbot renewal
    log "Running certbot renew..."
    make ssl-cert-renew >> /var/log/openmeal-ssl-renew.log 2>&1
    
    if [ $? -eq 0 ]; then
        log "Certificate renewal completed successfully"
    else
        error "Certificate renewal failed. Check /var/log/openmeal-ssl-renew.log for details"
        exit 1
    fi
}

# Install systemd timer
install_systemd() {
    check_os_compatibility
    
    # Check if systemd is available
    if ! command -v systemctl >/dev/null 2>&1; then
        error "systemd is not available on this system"
        error "Please use 'install-cron' instead or manually schedule renewals"
        exit 1
    fi
    
    # Check if running with sufficient privileges
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        error "This operation requires sudo privileges"
        error "Please run with sudo or ensure your user can use sudo without password"
        exit 1
    fi
    
    log "Installing systemd timer for SSL renewal..."
    
    # Create systemd service file
    cat > /tmp/${SCRIPT_NAME}.service <<EOF
[Unit]
Description=OpenMeal SSL Certificate Renewal
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
User=root
WorkingDirectory=${PROJECT_DIR}
ExecStart=${PROJECT_DIR}/scripts/ssl-renew-cron.sh renew
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd timer file (runs twice daily at 3:00 AM and 3:00 PM)
    cat > /tmp/${SCRIPT_NAME}.timer <<EOF
[Unit]
Description=OpenMeal SSL Certificate Renewal Timer
Requires=${SCRIPT_NAME}.service

[Timer]
# Run twice daily
OnCalendar=*-*-* 03:00:00
OnCalendar=*-*-* 15:00:00
# Run 5 minutes after boot if we missed a scheduled run
OnBootSec=5min
# Randomize start time by up to 1 hour to avoid load spikes
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Install files
    sudo mv /tmp/${SCRIPT_NAME}.service /etc/systemd/system/
    sudo mv /tmp/${SCRIPT_NAME}.timer /etc/systemd/system/
    
    # Set permissions
    sudo chmod 644 /etc/systemd/system/${SCRIPT_NAME}.service
    sudo chmod 644 /etc/systemd/system/${SCRIPT_NAME}.timer
    
    # Reload systemd and enable timer
    sudo systemctl daemon-reload
    sudo systemctl enable ${SCRIPT_NAME}.timer
    sudo systemctl start ${SCRIPT_NAME}.timer
    
    log "Systemd timer installed and started"
    log "Check status with: sudo systemctl status ${SCRIPT_NAME}.timer"
    log "View logs with: sudo journalctl -u ${SCRIPT_NAME}.service"
}

# Install cron job
install_cron() {
    check_os_compatibility
    
    # Check if cron is available
    if ! command -v crontab >/dev/null 2>&1; then
        error "cron is not available on this system"
        if [ "$OS_TYPE" = "macos" ]; then
            error "On macOS, you may need to use launchd instead"
            error "Or install cron: brew install cron"
        else
            error "Please install cron: sudo apt-get install cron (Linux)"
        fi
        exit 1
    fi
    
    log "Installing cron job for SSL renewal..."
    
    # Create cron job (runs twice daily at 3:00 AM and 3:00 PM)
    CRON_CMD="${PROJECT_DIR}/scripts/ssl-renew-cron.sh renew >> /var/log/openmeal-ssl-renew.log 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "ssl-renew-cron.sh"; then
        warn "Cron job already exists, removing old entry..."
        crontab -l 2>/dev/null | grep -v "ssl-renew-cron.sh" | crontab -
    fi
    
    # Add new cron jobs
    (crontab -l 2>/dev/null; echo "# OpenMeal SSL Certificate Renewal - runs twice daily") | crontab -
    (crontab -l 2>/dev/null; echo "0 3 * * * $CRON_CMD") | crontab -
    (crontab -l 2>/dev/null; echo "0 15 * * * $CRON_CMD") | crontab -
    
    log "Cron job installed successfully"
    log "Certificates will be checked twice daily at 3:00 AM and 3:00 PM"
    log "View logs at: /var/log/openmeal-ssl-renew.log"
}

# Uninstall systemd timer
uninstall_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        error "systemd is not available on this system"
        exit 1
    fi
    
    log "Uninstalling systemd timer..."
    
    sudo systemctl stop ${SCRIPT_NAME}.timer 2>/dev/null || true
    sudo systemctl disable ${SCRIPT_NAME}.timer 2>/dev/null || true
    sudo rm -f /etc/systemd/system/${SCRIPT_NAME}.service
    sudo rm -f /etc/systemd/system/${SCRIPT_NAME}.timer
    sudo systemctl daemon-reload
    
    log "Systemd timer uninstalled"
}

# Uninstall cron job
uninstall_cron() {
    if ! command -v crontab >/dev/null 2>&1; then
        error "cron is not available on this system"
        exit 1
    fi
    
    log "Uninstalling cron job..."
    
    crontab -l 2>/dev/null | grep -v "ssl-renew-cron.sh" | grep -v "OpenMeal SSL Certificate Renewal" | crontab -
    
    log "Cron job uninstalled"
}

# Main script logic
case "${1:-}" in
    renew)
        renew_certificates
        ;;
    install-systemd)
        install_systemd
        ;;
    install-cron)
        install_cron
        ;;
    uninstall-systemd)
        uninstall_systemd
        ;;
    uninstall-cron)
        uninstall_cron
        ;;
    *)
        echo "Usage: $0 {renew|install-systemd|install-cron|uninstall-systemd|uninstall-cron}"
        echo ""
        echo "Commands:"
        echo "  renew              - Renew SSL certificates now"
        echo "  install-systemd    - Install systemd timer for automatic renewal (Linux)"
        echo "  install-cron       - Install cron job for automatic renewal (Linux/macOS/WSL)"
        echo "  uninstall-systemd  - Remove systemd timer"
        echo "  uninstall-cron     - Remove cron job"
        echo ""
        echo "Platform Support:"
        echo "  Linux:   ✓ systemd, ✓ cron"
        echo "  macOS:   ✓ cron"
        echo "  Windows: ✓ WSL only (systemd or cron)"
        exit 1
        ;;
esac
