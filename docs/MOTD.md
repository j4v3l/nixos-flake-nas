# MOTD (Message of the Day) Module

The MOTD module provides a professional server-style welcome message that displays system information, network details, storage status, and service information when you log in to your NixOS NAS.

## Features

- **System Information**: Hostname, kernel version, uptime, load average, memory usage, disk usage, and temperature
- **Network Information**: IP address, SSH port, Samba ports
- **Storage Information**: NVMe drive count, mounted drives, usage statistics
- **Service Status**: SSH, Samba, and Storage management service status
- **Quick Commands**: Customizable list of useful commands
- **Warnings**: Smart alerts (e.g., drive expansion notifications)
- **Configurable**: Colors, update intervals, custom commands, and more

## Basic Usage

To enable the MOTD module in your NixOS configuration:

```nix
{
  imports = [
    ./modules/motd.nix
  ];
  
  motd.enable = true;
}
```

## Configuration Options

### Basic Options

```nix
motd = {
  enable = true;                    # Enable/disable MOTD
  showOnLogin = true;              # Show MOTD on interactive shell login
  updateInterval = "5min";         # How often to update MOTD (systemd timer format)
  serverName = "NixOS NAS Server"; # Server name in header
  enableColors = true;             # Enable colored output
  showWarnings = true;             # Show system warnings
};
```

### Custom Commands

You can customize the "Quick Commands" section:

```nix
motd = {
  enable = true;
  extraCommands = [
    { name = "storage-status"; description = "View detailed storage information"; }
    { name = "drive-health"; description = "Check all drive health status"; }
    { name = "list-nvme"; description = "List all NVMe drives"; }
    { name = "btop"; description = "System resource monitor"; }
    { name = "fastfetch"; description = "Detailed system information"; }
    { name = "docker ps"; description = "List running containers"; }
    { name = "systemctl status"; description = "Check system services"; }
  ];
};
```

## Example Configurations

### Minimal Configuration

```nix
motd.enable = true;
```

### Custom Server Configuration

```nix
motd = {
  enable = true;
  serverName = "My Home NAS";
  updateInterval = "10min";
  extraCommands = [
    { name = "htop"; description = "Process monitor"; }
    { name = "df -h"; description = "Disk usage"; }
    { name = "uptime"; description = "System uptime"; }
  ];
};
```

### Minimal/Quiet Configuration (no colors, no warnings)

```nix
motd = {
  enable = true;
  enableColors = false;
  showWarnings = false;
  updateInterval = "30min";
  extraCommands = [
    { name = "status"; description = "System status"; }
  ];
};
```

### Development/Testing Configuration

```nix
motd = {
  enable = true;
  showOnLogin = false;  # Don't show automatically
  updateInterval = "1min";  # Update frequently for testing
  serverName = "Development NAS";
};
```

## Disabling MOTD

To temporarily disable MOTD without removing the module:

```nix
motd.enable = false;
```

Or to disable just the login display but keep the `/etc/motd` file updated:

```nix
motd = {
  enable = true;
  showOnLogin = false;
};
```

## Manual MOTD Display

Even with `showOnLogin = false`, you can manually display the MOTD:

```bash
# View current MOTD
cat /etc/motd

# Force update and view
sudo systemctl start motd-update && cat /etc/motd
```

## Systemd Services

The MOTD module creates several systemd services:

- `motd-update.service`: Updates the MOTD content
- `motd-update.timer`: Automatically updates MOTD at specified intervals
- `motd-initial.service`: Creates initial MOTD on boot

### Managing MOTD Services

```bash
# Check timer status
systemctl status motd-update.timer

# Manually trigger update
sudo systemctl start motd-update

# View logs
journalctl -u motd-update.service
```

## Customization

### Update Intervals

The `updateInterval` option accepts systemd timer format:

- `"1min"` - Every minute
- `"5min"` - Every 5 minutes (default)
- `"15min"` - Every 15 minutes
- `"1h"` - Every hour
- `"daily"` - Once per day

### Color Themes

Currently, colors are hardcoded but can be disabled with `enableColors = false`. Future versions may support custom color themes.

## Troubleshooting

### MOTD Not Displaying

1. Check if the module is enabled: `motd.enable = true`
2. Verify the service is running: `systemctl status motd-update.timer`
3. Check if the file exists: `ls -la /etc/motd`
4. Check shell configuration: `echo $-` (should show interactive flags)

### Permission Issues

The MOTD script runs as root and creates `/etc/motd` with proper permissions (644). If you see permission errors, check:

```bash
ls -la /etc/motd*
sudo systemctl restart motd-initial
```

### Service Failures

Check service logs:

```bash
journalctl -u motd-update.service
journalctl -u motd-initial.service
```

## Integration with Other Modules

The MOTD module automatically detects and displays status for:

- SSH service (from base.nix)
- Samba service (from samba.nix)
- Storage management (from storage.nix)

It also reads storage information from the storage module's NVMe detection and mount points.
