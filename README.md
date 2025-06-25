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
│   └── wifi.nix          # WiFi configuration
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
- **Samba**: File sharing with authentication and local network restrictions
- **WiFi**: NetworkManager-based WiFi configuration
- **Secrets**: Initial password setup and security checklist
- **Home Manager**: User-specific package management and dotfiles

### User Configuration

- **Shell**: Bash with NAS-specific aliases
- **Editor**: Vim with server-friendly configuration
- **Tools**: Git, tmux, htop, network utilities
- **SSH**: Hardened SSH client configuration

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

### Disk Usage & Monitoring

```bash
# Modern disk usage (dysk)
space                    # Show disk usage with dysk
usage                    # Show directory usage
dysk-data                # Check /mnt/data usage
dysk-root                # Check root filesystem

# Traditional tools
df                       # Disk free space
du                       # Directory usage
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
cdetc                    # Go to /etc/nixos
cdlogs                   # Go to /var/log
```
