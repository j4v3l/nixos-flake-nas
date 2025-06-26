# Container Management Module

The containers module provides comprehensive Docker-based container management for your NixOS NAS, following the same security and usability patterns as your other modules.

## Overview

This module enables and manages containerized services commonly used on NAS systems, including:

- 🐳 **Docker Runtime** - Secure container runtime with optional rootless mode
- 📺 **Media Servers** - Jellyfin/Plex for streaming media
- 🔄 **Sync Services** - Syncthing/Nextcloud for file synchronization
- ⬇️ **Download Managers** - qBittorrent, Transmission, and Usenet tools
- 🏠 **Home Automation** - Home Assistant platform
- 📊 **Monitoring** - Prometheus and Grafana dashboards  
- 🛡️ **Network Services** - AdGuard Home, Nginx Proxy Manager
- 🎛️ **Management** - Portainer web interface, Watchtower auto-updates

## Quick Start

Add the containers module to your configuration:

```nix
# hosts/beelink-mini/configuration.nix
{
  imports = [
    # ... existing imports ...
    ../../modules/containers.nix
  ];

  # Enable containers with media server
  containerServices = {
    enable = true;
    services = {
      media.enable = true;          # Jellyfin media server
      sync.enable = true;           # Syncthing file sync
      downloads.enable = true;      # qBittorrent downloader
    };
  };
}
```

After rebuild, access services at:

- **Portainer**: `http://your-nas-ip:9000` (Container management)
- **Jellyfin**: `http://your-nas-ip:8096` (Media server)
- **Syncthing**: `http://your-nas-ip:8080` (File sync)
- **qBittorrent**: `http://your-nas-ip:8081` (Downloads)

## Configuration Options

### Docker Engine Configuration

```nix
containerServices.docker = {
  enable = true;                    # Enable Docker runtime
  rootless = false;                 # Use rootless Docker for security
  storageDriver = "overlay2";       # Storage driver (overlay2/btrfs/zfs)
  logLevel = "warn";                # Logging level
  autoUpdate = true;                # Enable auto-updates
  pruneInterval = "weekly";         # Cleanup interval
};
```

### Media Services

```nix
containerServices.services.media = {
  enable = true;                    # Enable media server
  type = "jellyfin";                # jellyfin|plex|both
  mediaPath = "/mnt/data/media";    # Path to media files
  port = 8096;                      # Web interface port
  enableHardwareAccel = false;      # GPU transcoding
};
```

### File Synchronization

```nix
containerServices.services.sync = {
  enable = true;                    # Enable sync services
  type = "syncthing";               # syncthing|nextcloud|both
  port = 8080;                      # Web interface port
  dataPath = "/mnt/data/sync";      # Sync data location
};
```

### Download Management

```nix
containerServices.services.downloads = {
  enable = true;                    # Enable download managers
  services = [ "qbittorrent" ];     # Available: qbittorrent, transmission, nzbget, sabnzbd
  downloadPath = "/mnt/data/downloads"; # Download location
  webPort = 8081;                   # Web interface port
};
```

### Home Automation

```nix
containerServices.services.homeAssistant = {
  enable = true;                    # Enable Home Assistant
  port = 8123;                      # Web interface port
  configPath = "/etc/containers/homeassistant"; # Config directory
};
```

### Monitoring Services

```nix
containerServices.services.monitoring = {
  enable = true;                    # Enable monitoring stack
  prometheus = {
    enable = true;                  # Metrics collection
    port = 9090;                    # Prometheus web interface
  };
  grafana = {
    enable = true;                  # Dashboard visualization
    port = 3000;                    # Grafana web interface
  };
};
```

### Network Services

```nix
containerServices.services.network = {
  enable = true;                    # Enable network services
  adguard = {
    enable = false;                 # AdGuard Home DNS blocker
    port = 3001;                    # Web interface port
  };
  reverseProxy = {
    enable = true;                  # Nginx Proxy Manager
    port = 8180;                    # Web interface port
  };
};
```

## Security Configuration

The module follows your existing security patterns:

```nix
containerServices.security = {
  restrictToLocalNetwork = true;                    # Restrict to LAN only
  enableFirewall = true;                            # Configure firewall rules
  allowedNetworks = [                               # Allowed network ranges
    "192.168.0.0/16" 
    "10.0.0.0/8" 
    "172.16.0.0/12"
  ];
};
```

### Security Features

- 🔒 **Local Network Restriction** - Web interfaces only accessible from LAN
- 🛡️ **Firewall Integration** - Automatic firewall rule configuration
- 🔐 **User Namespace Remapping** - Docker security isolation
- 🚫 **No New Privileges** - Prevent privilege escalation
- 📝 **Audit Logging** - All activities logged via journald

## Management Features

```nix
containerServices.management = {
  enablePortainer = true;           # Web-based container management
  portainerPort = 9000;             # Portainer web interface port
  enableWatchtower = true;          # Automatic container updates
  backupContainers = true;          # Backup container configs
};
```

### Management Tools

- **Portainer** - Web interface for container management
- **Watchtower** - Automatic container image updates
- **Backup System** - Daily configuration backups
- **Health Monitoring** - Container health checks every 15 minutes
- **Resource Monitoring** - CPU/memory usage alerts

## Command Line Interface

The module adds convenient shell aliases:

### Docker Management

```bash
dps                    # List running containers
dpsall                 # List all containers  
dlogs <container>      # Follow container logs
dexec <container>      # Execute shell in container
dstats                 # Container resource usage
dimages                # List Docker images
lazy                   # Launch lazydocker TUI
```

### Service Management

```bash
containers-start       # Start all NAS containers
containers-stop        # Stop all NAS containers
containers-restart     # Restart all NAS containers
containers-status      # Show service status
containers-logs        # Follow service logs
```

### Docker Compose

```bash
compose-up            # Start services
compose-down          # Stop services
compose-restart       # Restart services
compose-logs          # Follow all logs
compose-pull          # Update images
```

### Quick Navigation

```bash
cdcontainers          # Go to container data directory
cdcompose             # Go to compose files
cdmedia               # Go to media directory
cddownloads           # Go to downloads directory
```

### Maintenance

```bash
docker-cleanup        # Clean unused containers/images
docker-update         # Update and restart containers
containers-backup     # Manual backup of configs
```

## Directory Structure

The module creates the following directory structure:

```
/mnt/data/
├── containers/          # Container persistent data
│   ├── portainer/       # Portainer data
│   ├── jellyfin/        # Jellyfin config and cache
│   ├── syncthing/       # Syncthing configuration
│   └── qbittorrent/     # qBittorrent settings
├── media/               # Media files for streaming
├── downloads/           # Downloaded files
├── sync/                # Syncthing synchronized files
└── backups/            # Container configuration backups
    └── containers/      # Daily config backups

/etc/containers/
├── compose/             # Docker Compose files
│   └── docker-compose.yml
└── homeassistant/       # Home Assistant config
```

## Network Architecture

The module creates isolated Docker networks:

- **nas-network** (172.20.0.0/16) - General NAS services
- **media-network** (172.21.0.0/16) - Media-specific services

This provides network isolation between service types while maintaining connectivity.

## Backup Strategy

### Automatic Backups

- **Daily** container configuration backups
- **Retention** of last 10 backups
- **Location** `/mnt/data/backups/containers/`

### Manual Backup

```bash
containers-backup      # Trigger manual backup
```

### Backup Contents

- Docker Compose configurations
- Container-specific config files
- Service settings and preferences

## Monitoring and Alerting

### Health Checks

- Container health status monitoring
- Resource usage monitoring (CPU/Memory)
- Automatic alerting for failures

### Log Management

- Centralized logging via journald
- Service-specific log filtering
- Log rotation and retention

### Metrics Collection

- Container resource metrics
- Service availability metrics
- Performance monitoring

## Troubleshooting

### Common Issues

**Container won't start:**

```bash
containers-logs        # Check service logs
dlogs <container>      # Check specific container
docker-cleanup         # Clean up resources
```

**Permission issues:**

```bash
sudo chown -R jager:users /mnt/data/containers
sudo systemctl restart containers-setup
```

**Network connectivity:**

```bash
docker network ls      # List networks
docker network inspect nas-network  # Check network config
```

**Storage issues:**

```bash
docker system df       # Check Docker disk usage
docker-cleanup         # Free up space
```

### Service Restart

```bash
sudo systemctl restart docker-compose-nas
```

### Complete Rebuild

```bash
sudo systemctl stop docker-compose-nas
sudo systemctl start containers-setup
sudo systemctl start docker-compose-nas
```

## Integration with Existing Modules

The containers module integrates seamlessly with your existing setup:

- **Storage Module** - Uses configured storage paths
- **Firewall** - Coordinates with existing firewall rules
- **Base Module** - Leverages existing user and security configuration
- **MOTD** - Can display container status in MOTD
- **Secrets** - Uses existing user permissions and security

## Performance Considerations

### Storage Optimization

- Uses overlay2 storage driver for best performance
- Separate volumes for persistent data
- Optimized I/O scheduler settings from storage module

### Memory Management

- Container memory limits to prevent OOM
- Shared memory optimization for media transcoding
- Buffer tuning for network services

### CPU Optimization

- CPU pinning for critical services
- Process priority management
- Load balancing across cores

## Advanced Configuration

### Custom Services

Add your own services to the Docker Compose configuration:

```nix
# Custom compose file in /etc/containers/compose/
```

### Hardware Acceleration

Enable GPU transcoding for media servers:

```nix
containerServices.services.media.enableHardwareAccel = true;
```

### External Storage

Mount additional storage for containers:

```nix
# Add to storage module configuration
```

This containers module provides a complete, secure, and manageable container platform for your NAS while maintaining the high standards of your existing codebase.
