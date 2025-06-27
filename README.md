# NixOS NAS Configuration

A NixOS flake configuration for a Beelink Mini NAS server with Samba, Home Manager, and security hardening.

## 📁 Directory Structure

```
nixos-flake-nas/
├── flake.nix              # Main flake configuration
├── flake.lock             # Locked input versions
├── README.md              # This file
│
├── hosts/                 # Host-specific configurations
│   └── beelink-mini/
│       └── configuration.nix
│
├── hardware/              # Hardware configurations
│   └── beelink-mini.nix   # Generated hardware config
│
├── modules/               # NixOS system modules
│   ├── base.nix          # Base system configuration
│   ├── samba.nix         # Samba file sharing
│   ├── secrets.nix       # Security and secrets management
│   ├── storage.nix       # Advanced 6-drive NVMe management
│   ├── motd.nix          # Server-style MOTD (Message of the Day)
│   ├── wifi.nix          # WiFi configuration
│   ├── wireguard.nix     # WireGuard VPN server
│   └── atuin.nix         # Atuin shell history sync
│
├── home/                  # Home Manager configurations
│   └── jager.nix         # User-specific configuration
│
├── lib/                   # Common library functions
│   └── default.nix       # Helper functions
│
└── scripts/               # Deployment and utility scripts
    └── deploy.sh          # Main deployment script
```

## 🚀 Quick Start

1. **Deploy to NAS:**

   ```bash
   ./scripts/deploy.sh
   ```

2. **Local testing:**

   ```bash
   nix flake check
   nix build .#nixosConfigurations.beelink-mini.config.system.build.toplevel --dry-run
   ```

## 🔧 Configuration

### System Components

- **Base System**: Essential packages, users, security hardening
- **Storage**: Advanced 6-drive NVMe management with RAID support
- **Samba**: File sharing with authentication and local network restrictions
- **WiFi**: NetworkManager-based WiFi configuration
- **MOTD**: Professional server-style welcome message with system status
- **Secrets**: Initial password setup and security checklist
- **WireGuard**: VPN server with web dashboard management
- **Atuin**: Shell history sync with end-to-end encryption
- **Home Manager**: User-specific package management and dotfiles

### User Configuration

- **Shell**: Bash and Zsh with NAS-specific aliases and Atuin history sync
- **Editor**: Vim with server-friendly configuration
- **Tools**: Git, tmux, htop, network utilities, modern CLI replacements
- **SSH**: Hardened SSH client configuration
- **History**: Atuin for magical shell history sync across machines

## 📡 Network Services

- **SSH**: Port 22 (password auth initially, disable after key setup)
- **Samba**: Ports 139, 445 (TCP) and 137, 138 (UDP)
  - Share: `/mnt/data` → `\\nas\data`
  - Local network access only
- **Fail2ban**: Protection against brute force attacks

## 🔐 Security Features

- Firewall with local network restrictions
- Fail2ban for intrusion prevention
- Automatic security updates
- SSH hardening
- User access controls
- Secure Samba configuration

## 📦 Management

### System Updates

```bash
# Update flake inputs
nix flake update

# Rebuild system
sudo nixos-rebuild switch --flake .#beelink-mini
```

### Home Manager

```bash
# Check generations
home-manager generations

# Switch to specific generation
home-manager switch -b backup
```

### Monitoring

```bash
# Service status
samba-status
systemctl status fail2ban

# System resources
check-data
meminfo
diskusage

# Logs
nas-logs
journalctl -f
```

## 🛠 Customization

### Adding New Hosts

1. Create `hosts/new-host/configuration.nix`
2. Add hardware config to `hardware/new-host.nix`
3. Add to `flake.nix` outputs

### Adding Services

1. Create module in `modules/service-name.nix`
2. Import in host configuration
3. Configure firewall rules if needed

### User Management

1. Create home config in `home/username.nix`
2. Add to flake.nix home-manager users
3. Configure in host's user settings

## 📋 Initial Setup Checklist

- [ ] Set strong password: `sudo passwd jager`
- [ ] Configure Samba password: `sudo smbpasswd -a jager`
- [ ] Add SSH public keys
- [ ] Disable SSH password authentication
- [ ] Test Samba access from client
- [ ] Set up data disk with label 'data'
- [ ] Configure automatic backups
- [ ] Set up Atuin shell history sync: `atuin register -u username -e email`
- [ ] Import existing shell history: `atuin import auto`
- [ ] Mark passwords configured: `sudo touch /etc/nixos/.passwords-configured`

## 🔗 Useful Commands & Aliases

### System Management

```bash
# NixOS Flake Management
rebuild                   # Full system rebuild
rebuild-test             # Test configuration
rebuild-dry              # Preview changes
flake-update             # Update flake inputs
flake-check              # Validate configuration
hm-rebuild               # Home Manager rebuilds with system  
hm-test                  # Test both system and HM config
hm-gen                   # List system generations (includes HM)
update-all               # Update inputs and rebuild everything
update-check             # Update and preview changes
```

### Samba Management

```bash
# Service Control
samba-status             # Service status
samba-start              # Start service
samba-stop               # Stop service
samba-restart            # Restart service
samba-config             # Test configuration
samba-users              # Show connected users
samba-shares             # Show active shares
samba-logs               # Recent logs
```

### Atuin History Management

```bash
# History Management
atuin-status             # Check daemon status
atuin-restart            # Restart daemon
atuin-logs               # View daemon logs
atuin-sync               # Manual sync
atuin-search             # Search history
atuin-stats              # View statistics
atuin register           # Register new account
atuin import auto        # Import existing history
atuin key                # Show encryption key
```

### Storage & Drive Management

```bash
# Drive Status & Health
list-nvme                # List all NVMe drives
drive-health             # Check all drive health
drive-temp               # Monitor drive temperatures
nvme-health              # NVMe health status  
check-all-drives         # Check all drive usage

# Performance Benchmarking
nvme-bench               # Access benchmark commands
nvme-bench-all           # Quick benchmark all drives

# Storage Monitoring
storage-status           # Storage services status
storage-logs             # Storage service logs
iostat-nvme              # Real-time I/O monitoring
iotop-nvme               # I/O process monitoring

# Disk Usage Analysis
space                    # Show disk usage with dysk
usage                    # Show directory usage
dysk-data                # Check /mnt/data usage
dysk-root                # Check root filesystem
df                       # Disk free space
check-data               # Check data disk
diskusage                # All filesystem usage
```

### System Information

```bash
# Hardware & System
neofetch                 # System information
temps                    # Hardware temperatures
meminfo                  # Memory usage
cpuinfo                  # CPU information
processes                # Process monitor (htop)

# Network & Services
ports                    # Show open ports
listening                # Show listening services
services                 # Running services
failed                   # Failed services
journal                  # Live system logs
```

### Quick Navigation

```bash
cddata                   # Go to /mnt/data
cddrive1                 # Go to /mnt/drive1
cddrive2                 # Go to /mnt/drive2
cddrive3                 # Go to /mnt/drive3
cddrive4                 # Go to /mnt/drive4
cddrive5                 # Go to /mnt/drive5
cdetc                    # Go to /etc/nixos
cdlogs                   # Go to /var/log
```

## 💾 Storage Configuration

This configuration supports the **Beelink ME mini's 6x M.2 NVMe slots** with advanced storage management features:

- **Automatic drive detection** and health monitoring
- **RAID support** (RAID 0, 1, 5, 6, 10) for redundancy and performance
- **Individual drive mounting** at `/mnt/drive1` through `/mnt/drive5`
- **Performance optimization** with NVMe-specific tuning
- **Temperature monitoring** and thermal management
- **SMART health checks** with automated alerting

For detailed storage setup and configuration options, see **[docs/STORAGE.md](docs/STORAGE.md)**.

## 🖥️ MOTD (Message of the Day)

The MOTD module provides a professional server-style welcome message that displays:

- **System Information**: Hostname, kernel, uptime, load, memory, temperature
- **Network Details**: IP address, SSH/Samba ports
- **Storage Status**: NVMe drive count, mounted drives, usage
- **Service Status**: SSH, Samba, Storage management
- **Quick Commands**: Useful server management commands
- **Smart Warnings**: Drive expansion alerts and system notices

### Configuration

```nix
motd = {
  enable = true;                    # Enable MOTD
  serverName = "My NAS Server";     # Custom server name
  updateInterval = "5min";          # Update frequency
  showOnLogin = true;              # Show on shell login
  enableColors = true;             # Colored output
  showWarnings = true;             # System warnings
};
```

For detailed MOTD configuration and customization options, see **[docs/MOTD.md](docs/MOTD.md)**.
