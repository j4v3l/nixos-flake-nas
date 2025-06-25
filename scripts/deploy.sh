#!/usr/bin/env bash

# NixOS NAS Setup Script
# Target: jager@192.168.1.253

set -euo pipefail

# Configuration
TARGET_HOST="jager@192.168.1.253"
FLAKE_NAME="beelink-mini"
REMOTE_FLAKE_DIR="/tmp/nixos-flake-nas"
LOCAL_FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running interactively
INTERACTIVE=true
if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    INTERACTIVE=false
    log_warning "Running in non-interactive mode - some features may be limited"
fi

# Check if we can connect to the target
check_connection() {
    log_info "Checking connection to $TARGET_HOST..."
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_HOST" "echo 'Connection successful'" >/dev/null 2>&1; then
        log_success "Successfully connected to $TARGET_HOST"
    else
        log_error "Cannot connect to $TARGET_HOST"
        log_info "Make sure:"
        log_info "  1. The target machine is running and accessible"
        log_info "  2. SSH is enabled on the target"
        log_info "  3. You can SSH without password (SSH keys set up)"
        exit 1
    fi
}

# Check if target is running NixOS
check_nixos() {
    log_info "Checking if target is running NixOS..."
    if ssh "$TARGET_HOST" "test -f /etc/NIXOS"; then
        log_success "Target is running NixOS"
    else
        log_error "Target is not running NixOS"
        log_info "This script requires the target machine to already be running NixOS"
        exit 1
    fi
}

# Prepare hardware configuration on target
prepare_hardware_config() {
    log_info "Preparing hardware configuration on target..."

    # Check if hardware-configuration.nix exists, if not generate it
    if ssh "$TARGET_HOST" "test -f /etc/nixos/hardware-configuration.nix"; then
        log_info "Using existing hardware configuration from /etc/nixos/hardware-configuration.nix"
    else
        log_info "Generating new hardware configuration..."
        log_info "This will require sudo access on the target..."
        ssh -t "$TARGET_HOST" "sudo nixos-generate-config --root /"
        log_success "Hardware configuration generated"
    fi

    # Check if we can read the hardware config without sudo (it should be readable)
    if ssh "$TARGET_HOST" "test -r /etc/nixos/hardware-configuration.nix"; then
        log_info "Hardware configuration is accessible"
    else
        log_warning "Hardware configuration requires sudo access"
        log_info "Making hardware config accessible..."
        ssh -t "$TARGET_HOST" "sudo cp /etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix && sudo chown \$(whoami):\$(whoami) /tmp/hardware-configuration.nix"
    fi

    log_success "Hardware configuration prepared on target"
}

# Detect network interface
detect_network_interface() {
    log_info "Detecting network interface..."

    # Get the primary network interface from the remote machine
    INTERFACE=$(ssh "$TARGET_HOST" "ip route | grep default | head -n1 | awk '{print \$5}'")

    if [[ -n "$INTERFACE" ]]; then
        log_success "Detected network interface: $INTERFACE"
        log_info "Network interface information logged for reference"
        log_info "Firewall is configured to allow Samba on all local network ranges"
    else
        log_warning "Could not detect network interface"
        log_info "Using network-range-based firewall rules for Samba"
    fi
}

# Copy flake to remote machine
copy_flake() {
    log_info "Copying flake configuration to remote machine..."

    # Remove old flake directory on remote (use rm instead of sudo rm)
    ssh "$TARGET_HOST" "rm -rf $REMOTE_FLAKE_DIR"

    # Copy flake to remote machine (excluding scripts and hardware directories)
    rsync -av --exclude='hardware/' --exclude='scripts/' "$LOCAL_FLAKE_DIR/" "$TARGET_HOST:$REMOTE_FLAKE_DIR/"

    # Create hardware directory and copy the actual hardware config
    ssh "$TARGET_HOST" "mkdir -p $REMOTE_FLAKE_DIR/hardware"
    ssh "$TARGET_HOST" "cp /etc/nixos/hardware-configuration.nix $REMOTE_FLAKE_DIR/hardware/beelink-mini.nix"

    log_info "Using actual hardware configuration from target system"
    log_success "Flake copied to remote machine"
}

# Apply the configuration
apply_configuration() {
    log_info "Applying NixOS configuration..."
    log_warning "This will rebuild the system with the new configuration"

    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Configuration application cancelled"
        exit 0
    fi

    # Validate the configuration before applying
    log_info "Validating configuration..."
    if ssh "$TARGET_HOST" "cd $REMOTE_FLAKE_DIR && nix flake check"; then
        log_success "Configuration validation passed"
    else
        log_error "Configuration validation failed!"
        exit 1
    fi

    # Apply the configuration with proper sudo handling
    log_info "Applying configuration - this will require sudo access..."
    if ssh -t "$TARGET_HOST" "cd $REMOTE_FLAKE_DIR && sudo nixos-rebuild switch --flake .#$FLAKE_NAME"; then
        log_success "NixOS configuration applied successfully!"
    else
        log_error "Configuration application failed!"
        exit 1
    fi

    log_success "NixOS configuration applied successfully!"
}

# Setup Samba user
setup_samba_user() {
    log_info "Setting up Samba user..."
    log_info "You will be prompted to set a password for the Samba user 'jager'"

    ssh -t "$TARGET_HOST" "sudo smbpasswd -a jager"

    log_success "Samba user configured"
}

# Helper function to run sudo commands over SSH with proper terminal handling
ssh_sudo() {
    local host="$1"
    local command="$2"

    if [[ "$INTERACTIVE" == "true" ]]; then
        # Try with -t for interactive sessions
        if ssh -t "$host" "$command"; then
            return 0
        fi
    fi

    # Fallback: inform user about manual step needed
    log_warning "Cannot run sudo command automatically"
    log_info "Please run this command manually on the target system:"
    log_info "  $command"
    return 1
}

# Prepare data disk
prepare_data_disk() {
    log_info "Checking data disk setup..."

    # Check if data disk is already mounted
    if ssh "$TARGET_HOST" "mountpoint -q /mnt/data"; then
        log_success "Data disk is already mounted at /mnt/data"
        return 0
    fi

    # List available disks
    log_info "Available disks on target system:"

    # Try to list disks without sudo first
    if ssh "$TARGET_HOST" "lsblk -f 2>/dev/null || df -h" 2>/dev/null; then
        log_info "Basic disk information shown above"
    else
        # Try with sudo if basic commands fail
        if ! ssh_sudo "$TARGET_HOST" "sudo lsblk -f"; then
            log_warning "Could not list disks - continuing without disk check"
            log_info "You can manually check disks later with: ssh $TARGET_HOST 'lsblk -f'"
        fi
    fi

    log_warning "Data disk setup required!"
    log_info "Please ensure you have a disk labeled 'data' or update the configuration."
    log_info "To prepare a disk for use:"
    echo "  1. Identify the disk (e.g., /dev/sdb)"
    echo "  2. Create a filesystem: sudo mkfs.ext4 -L data /dev/sdb1"
    echo "  3. The system will auto-mount it at /mnt/data"
    echo ""

    read -p "Do you want to continue without data disk setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Please prepare the data disk and run the setup again"
        exit 0
    fi

    log_warning "Continuing without data disk - Samba may not work properly"
}

# Post-deployment checks
post_deployment_checks() {
    log_info "Running post-deployment checks..."

    # Check if services are running
    log_info "Checking Samba service..."
    if ssh "$TARGET_HOST" "systemctl is-active --quiet smbd"; then
        log_success "Samba service is running"
    else
        log_warning "Samba service is not running"
    fi

    log_info "Checking SSH service..."
    if ssh "$TARGET_HOST" "systemctl is-active --quiet sshd"; then
        log_success "SSH service is running"
    else
        log_warning "SSH service is not running"
    fi

    log_info "Checking firewall status..."
    ssh -t "$TARGET_HOST" "sudo iptables -L INPUT | head -10"

    log_info "Checking fail2ban status..."
    if ssh "$TARGET_HOST" "systemctl is-active --quiet fail2ban"; then
        log_success "Fail2ban is running"
    else
        log_warning "Fail2ban is not running"
    fi
}

# Display connection information
show_connection_info() {
    TARGET_IP=$(echo "$TARGET_HOST" | cut -d'@' -f2)

    log_success "Setup completed successfully!"
    echo
    log_info "Connection Information:"
    echo "  SSH: ssh $TARGET_HOST"
    echo "  Samba: smb://$TARGET_IP/data"
    echo "  Web interfaces (if any): http://$TARGET_IP"
    echo
    log_info "Next steps:"
    echo "  1. Test Samba connection from a client machine"
    echo "  2. Copy your data to /mnt/data on the NAS"
    echo "  3. Set up regular backups"
    echo "  4. Consider setting up SSH keys for passwordless access"
    echo
    log_info "For troubleshooting, check:"
    echo "  - System logs: journalctl -f"
    echo "  - Samba logs: journalctl -u smbd"
    echo "  - Fail2ban status: sudo fail2ban-client status"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files on remote machine..."
    ssh "$TARGET_HOST" "rm -rf $REMOTE_FLAKE_DIR" || true
}

# Test configuration locally and remotely
test_configuration() {
    log_info "Testing NixOS configuration..."

    # Test 1: Local flake check
    log_info "Running local flake check..."
    if nix flake check --no-build 2>&1 | tee /tmp/flake-check.log; then
        log_success "Local flake syntax check passed"
    else
        log_error "Local flake check failed!"
        cat /tmp/flake-check.log
        return 1
    fi

    # Test 2: Remote validation
    log_info "Copying test configuration to target..."
    copy_flake

    log_info "Running remote flake check..."
    if ssh "$TARGET_HOST" "cd $REMOTE_FLAKE_DIR && nix flake check --no-build" 2>&1 | tee /tmp/remote-flake-check.log; then
        log_success "Remote flake check passed"
    else
        log_error "Remote flake check failed!"
        cat /tmp/remote-flake-check.log
        return 1
    fi

    # Test 3: Dry run build
    log_info "Testing configuration build (dry-run)..."
    log_info "This will require sudo access on the target..."
    if ssh -t "$TARGET_HOST" "cd $REMOTE_FLAKE_DIR && sudo nixos-rebuild dry-run --flake .#$FLAKE_NAME" 2>&1 | tee /tmp/dry-run.log; then
        log_success "Configuration dry-run successful"
    else
        log_error "Configuration dry-run failed!"
        cat /tmp/dry-run.log
        return 1
    fi

    log_success "All configuration tests passed!"
}

# Main execution
main() {
    echo "==============================================="
    echo "       NixOS NAS Setup Script"
    echo "       Target: $TARGET_HOST"
    echo "==============================================="
    echo

    # Set up cleanup trap
    trap cleanup EXIT

    # Pre-deployment checks
    check_connection
    check_nixos

    # Configuration generation
    prepare_hardware_config
    detect_network_interface
    prepare_data_disk

    # Deployment
    copy_flake
    apply_configuration

    # Post-deployment setup
    setup_samba_user
    post_deployment_checks

    # Show final information
    show_connection_info
}

# Help function
show_help() {
    echo "NixOS NAS Setup Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --check-only   Only run connection and system checks"
    echo "  --hw-only      Only prepare hardware configuration on target"
    echo "  --test         Test configuration without deploying"
    echo
    echo "This script will:"
    echo "  1. Check connection to $TARGET_HOST"
    echo "  2. Prepare hardware configuration on target"
    echo "  3. Detect and configure network interface"
    echo "  4. Deploy the NixOS configuration"
    echo "  5. Set up Samba user"
    echo "  6. Run post-deployment checks"
    echo
    echo "Prerequisites:"
    echo "  - Target machine must be running NixOS"
    echo "  - SSH access to target machine"
    echo "  - sudo privileges on target machine"
}

# Parse command line arguments
case "${1:-}" in
-h | --help)
    show_help
    exit 0
    ;;
--check-only)
    check_connection
    check_nixos
    exit 0
    ;;
--hw-only)
    check_connection
    check_nixos
    prepare_hardware_config
    exit 0
    ;;

--test)
    check_connection
    check_nixos
    prepare_hardware_config
    detect_network_interface
    test_configuration
    exit 0
    ;;
*)
    main
    ;;
esac
