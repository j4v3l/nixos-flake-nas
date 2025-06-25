# WireGuard VPN Module

This document describes the WireGuard VPN module for secure networking in your NixOS flake configuration.

## Overview

The WireGuard module provides a flexible and secure VPN solution for:

- **Remote NAS Access**: Securely access your home network and file shares from anywhere
- **Site-to-Site VPN**: Connect multiple networks (home, office) securely
- **Peer-to-Peer**: Direct encrypted connections between devices
- **Web Management**: Modern web interface for easy configuration and monitoring

## Features

- **Multi-mode Operation**: Server, client, or peer-to-peer configurations
- **Web Interface**: WGDashboard for browser-based management and monitoring
- **Automatic Key Management**: Server keys are auto-generated and managed
- **Client Config Generator**: Built-in script to generate client configurations
- **Firewall Integration**: Automatic firewall rules with security options
- **QR Code Support**: Generate QR codes for easy mobile device setup
- **Flexible Routing**: Custom post-up/down commands for advanced networking
- **Security Hardening**: Local network restrictions and proper defaults
- **Auto-Updates**: Automatic weekly updates for the web interface
- **Docker Integration**: Containerized web interface with proper isolation

## Quick Start

### 1. Basic NAS Server Configuration

Add to your `hosts/beelink-mini/configuration.nix`:

```nix
{
  imports = [
    ../../modules/wireguard.nix
  ];

  wireguard = {
    enable = true;
    mode = "server";
    
    # Enable web interface for easy management
    webInterface = {
      enable = true;
      port = 10086;
      adminUsername = "admin";
      autoUpdate = true;  # Weekly automatic updates
    };
    
    peers = [
      {
        name = "laptop";
        publicKey = "YOUR_CLIENT_PUBLIC_KEY";
        allowedIPs = [ "10.100.0.2/32" ];
        persistentKeepalive = 25;
      }
    ];
  };
}
```

### 2. Deploy and Access Web Interface

```bash
# Deploy the configuration
sudo nixos-rebuild switch --flake .#beelink-mini

# Access the web interface
# Open browser to: http://192.168.1.253:10086
# Default login: admin/admin
```

### 3. Command Line Client Config Generation (Alternative)

```bash
# Generate client configuration via command line
sudo wireguard-client-config laptop 192.168.1.100:51820 10.100.0.2/32

# Generate QR code for mobile
qrencode -t ansiutf8 < laptop.conf
```

## Configuration Options

### Basic Options

```nix
wireguard = {
  enable = true;                    # Enable WireGuard module
  mode = "server";                  # "server", "client", or "peer"
  interface = "wg0";                # Interface name (default: wg0)
  openFirewall = true;              # Auto-configure firewall
  restrictToLocalNetwork = false;   # Restrict server to local networks only
  enablePacketForwarding = true;    # Enable IP forwarding (server mode)
};
```

### Web Interface Configuration

```nix
wireguard.webInterface = {
  enable = true;                              # Enable WGDashboard web interface
  port = 10086;                               # Web interface port
  adminUsername = "admin";                    # Dashboard admin username
  adminPasswordFile = "/etc/wireguard/dashboard-password";  # Password file path
  autoUpdate = true;                          # Weekly automatic updates
};
```

**Important Notes about Web Interface:**

- When `webInterface.enable = true`, the module uses WGDashboard to manage WireGuard instead of NixOS native configuration
- Your NixOS configuration options are automatically converted to WireGuard config format
- Default login credentials are `admin/admin` - **change immediately after first login**
- The web interface provides real-time monitoring, peer management, and configuration editing
- Automatic updates check weekly for new WGDashboard versions

### Server Configuration

```nix
wireguard.serverConfig = {
  listenPort = 51820;                           # UDP port
  subnet = "10.100.0.0/24";                    # VPN subnet
  serverIP = "10.100.0.1/24";                  # Server VPN IP
  dns = [ "1.1.1.1" "8.8.8.8" ];              # DNS servers for clients
  allowedIPs = [ "0.0.0.0/0" "::/0" ];         # Routes through VPN
  privateKeyFile = "/etc/wireguard/private.key"; # Private key location
};
```

### Client Configuration

```nix
wireguard.clientConfig = {
  privateKeyFile = "/etc/wireguard/client-private.key";
  address = [ "10.100.0.2/32" ];               # Client VPN IP
  dns = [ "1.1.1.1" ];                         # DNS servers
};
```

### Peer Configuration

```nix
wireguard.peers = [
  {
    name = "laptop";
    publicKey = "CLIENT_PUBLIC_KEY_HERE";
    allowedIPs = [ "10.100.0.2/32" ];
    endpoint = "vpn.example.com:51820";         # For client mode
    persistentKeepalive = 25;                   # NAT keepalive
    presharedKeyFile = "/etc/wireguard/psk";    # Optional additional security
  }
];
```

### Advanced Options

```nix
wireguard = {
  # Custom commands after interface up
  postUp = [
    "echo 'WireGuard interface is up'"
    "ip route add 192.168.2.0/24 dev wg0"
  ];
  
  # Custom commands after interface down  
  postDown = [
    "ip route del 192.168.2.0/24 dev wg0 || true"
  ];
};
```

## Web Interface Management

### Accessing WGDashboard

1. **Open browser to**: `http://YOUR_SERVER_IP:10086`
2. **Default login**: `admin/admin` (change immediately!)
3. **Features available**:
   - Real-time connection monitoring
   - Peer management (add/remove/edit)
   - Configuration file editing
   - QR code generation for mobile devices
   - Connection logs and statistics
   - Bulk client operations

### Web Interface Features

- **Dashboard Overview**: Connection status, data transfer, active peers
- **Peer Management**: Add, edit, delete, and monitor individual peers
- **Configuration Editor**: Direct editing of WireGuard configuration files
- **QR Code Generator**: Instant QR codes for mobile device setup
- **Logs & Monitoring**: Real-time logs and connection statistics
- **Bulk Operations**: Export configurations, bulk peer management
- **Settings**: Interface settings, security options, and preferences

### Managing Updates

```bash
# Check update status
sudo systemctl status wgdashboard-update.timer

# Manual update check
sudo systemctl start wgdashboard-update.service

# View update logs
sudo journalctl -u wgdashboard-update.service
```

## Usage Scenarios

### 1. Remote NAS Access with Web Management

**Use Case**: Access your home NAS and network from anywhere with easy web-based management.

```nix
# NAS Configuration
wireguard = {
  enable = true;
  mode = "server";
  
  # Enable web interface for easy management
  webInterface = {
    enable = true;
    port = 10086;
    autoUpdate = true;
  };
  
  serverConfig = {
    subnet = "10.100.0.0/24";
    # Only route home network, not internet
    allowedIPs = [ "192.168.1.0/24" "10.100.0.0/24" ];
  };
  
  peers = [
    {
      name = "laptop";
      publicKey = "...";
      allowedIPs = [ "10.100.0.2/32" ];
      persistentKeepalive = 25;
    }
  ];
};

# Allow VPN access to Samba
networking.firewall.extraCommands = ''
  iptables -A nixos-fw -s 10.100.0.0/24 -p tcp --dport 445 -j ACCEPT
'';
```

**Management**: Use web interface at `http://192.168.1.253:10086` to add clients, monitor connections, and generate mobile configs.

### 2. Site-to-Site VPN

**Use Case**: Connect multiple networks securely.

```nix
# Main site configuration
wireguard = {
  enable = true;
  mode = "server";
  
  webInterface.enable = true;  # Manage remotely
  
  peers = [
    {
      name = "remote-office";
      publicKey = "REMOTE_OFFICE_PUBLIC_KEY";
      allowedIPs = [ "10.200.0.3/32" "192.168.2.0/24" ];
    }
  ];
  
  postUp = [
    # Route remote network
    "ip route add 192.168.2.0/24 dev wg0"
  ];
};

# Remote site configuration (client mode)
wireguard = {
  enable = true;
  mode = "client";
  
  clientConfig = {
    address = [ "10.200.0.3/32" ];
  };
  
  peers = [
    {
      name = "main-office";
      publicKey = "MAIN_OFFICE_PUBLIC_KEY";
      endpoint = "main.example.com:51820";
      allowedIPs = [ "10.200.0.0/24" "192.168.1.0/24" ];
      persistentKeepalive = 25;
    }
  ];
};
```

### 3. Peer-to-Peer Connection

**Use Case**: Direct connection between two devices without a central server.

```nix
# Device A
wireguard = {
  enable = true;
  mode = "peer";
  
  clientConfig.address = [ "10.150.0.1/32" ];
  
  peers = [
    {
      name = "device-b";
      publicKey = "DEVICE_B_PUBLIC_KEY";
      endpoint = "device-b.example.com:51820";
      allowedIPs = [ "10.150.0.2/32" ];
      persistentKeepalive = 25;
    }
  ];
};
```

## Security Best Practices

### 1. Web Interface Security

```nix
wireguard.webInterface = {
  enable = true;
  # Use strong admin password
  adminPasswordFile = "/etc/wireguard/strong-password";
  # Consider non-standard port
  port = 8443;
};

# Restrict web interface access
networking.firewall.extraCommands = ''
  # Only allow web interface from local network
  iptables -A nixos-fw -s 192.168.1.0/24 -p tcp --dport 8443 -j ACCEPT
  iptables -A nixos-fw -p tcp --dport 8443 -j DROP
'';
```

### 2. Key Management

```bash
# Server keys are auto-generated, but you can manage them manually:
sudo wg genkey > /etc/wireguard/private.key
sudo chmod 600 /etc/wireguard/private.key
sudo wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
```

### 3. Network Restrictions

```nix
wireguard = {
  # Restrict server access to local networks only
  restrictToLocalNetwork = true;
  
  serverConfig = {
    # Don't route all internet traffic, only specific networks
    allowedIPs = [ "192.168.1.0/24" "10.100.0.0/24" ];
  };
};
```

### 4. Preshared Keys

```nix
wireguard.peers = [
  {
    name = "high-security-client";
    publicKey = "...";
    allowedIPs = [ "10.100.0.10/32" ];
    # Additional layer of encryption
    presharedKeyFile = "/etc/wireguard/client-psk";
  }
];
```

### 5. Firewall Integration

```nix
networking.firewall = {
  # Manual firewall control
  extraCommands = ''
    # Only allow WireGuard from specific IP ranges
    iptables -A nixos-fw -s 203.0.113.0/24 -p udp --dport 51820 -j ACCEPT
    iptables -A nixos-fw -p udp --dport 51820 -j DROP
  '';
};
```

## Management Commands

### Server Management

```bash
# Check WireGuard status
sudo wg show

# View server public key
sudo cat /etc/wireguard/public.key

# Check web interface status
sudo systemctl status wgdashboard.service

# View web interface logs
sudo journalctl -u wgdashboard.service -f

# Generate client configuration (command line)
sudo wireguard-client-config client-name server-ip:port client-ip

# Generate QR code for mobile
sudo wireguard-client-config phone | qrencode -t ansiutf8

# Monitor connections
sudo journalctl -u wg-quick-wg0 -f
```

### Web Interface Management

```bash
# Restart web interface
sudo systemctl restart wgdashboard.service

# Update web interface manually
sudo systemctl start wgdashboard-update.service

# Check update timer status
sudo systemctl list-timers wgdashboard-update.timer

# View update logs
sudo journalctl -u wgdashboard-update.service
```

### Client Management

```bash
# Connect/disconnect (using NetworkManager)
nmcli connection up client.conf
nmcli connection down client.conf

# Manual connection
sudo wg-quick up /path/to/client.conf
sudo wg-quick down /path/to/client.conf
```

## Troubleshooting

### Connection Issues

```bash
# Check interface status
ip addr show wg0

# Check routing
ip route show table all | grep wg0

# Check firewall
sudo iptables -L INPUT | grep 51820

# Test connectivity
ping 10.100.0.1  # VPN server IP
```

### Web Interface Issues

```bash
# Check Docker service
sudo systemctl status docker.service

# Check WGDashboard container
sudo docker ps | grep wgdashboard

# View container logs
sudo docker logs wgdashboard

# Check firewall for web interface
sudo iptables -L INPUT | grep 10086

# Test web interface connectivity
curl -I http://localhost:10086
```

### Common Problems

1. **Can't connect to server**
   - Check firewall rules on server
   - Verify endpoint IP/port is correct
   - Ensure server is listening: `sudo ss -ulnp | grep 51820`

2. **Web interface not accessible**
   - Check if Docker is running: `sudo systemctl status docker`
   - Verify container is running: `sudo docker ps`
   - Check firewall allows web interface port
   - Ensure port is not already in use

3. **Connected but no internet/network access**
   - Check IP forwarding: `cat /proc/sys/net/ipv4/ip_forward`
   - Verify NAT rules: `sudo iptables -t nat -L POSTROUTING`
   - Check DNS configuration

4. **Keys not working**
   - Regenerate keys: `sudo systemctl restart wireguard-key-gen`
   - Verify public key matches private key
   - Check file permissions (600 for private keys)

5. **Web interface shows wrong configuration**
   - When web interface is enabled, NixOS config is converted to WireGuard format
   - Restart `wgdashboard-setup.service` to regenerate config
   - Check `/etc/wireguard/wg0.conf` for proper format

## Integration with Existing Modules

### With Secrets Module

```nix
# Use secrets module for key management
age.secrets = {
  wireguard-private = {
    file = ../secrets/wireguard-private.age;
    path = "/etc/wireguard/private.key";
    mode = "600";
  };
  dashboard-password = {
    file = ../secrets/dashboard-password.age;
    path = "/etc/wireguard/dashboard-password";
    mode = "600";
  };
};

wireguard = {
  serverConfig.privateKeyFile = "/etc/wireguard/private.key";
  webInterface = {
    enable = true;
    adminPasswordFile = "/etc/wireguard/dashboard-password";
  };
};
```

### With Samba Module

```nix
# Allow VPN clients to access Samba shares
networking.firewall.extraCommands = ''
  # Samba access from WireGuard clients
  iptables -A nixos-fw -s 10.100.0.0/24 -p tcp --dport 445 -j ACCEPT
  iptables -A nixos-fw -s 10.100.0.0/24 -p tcp --dport 139 -j ACCEPT
'';
```

## Performance Tuning

### Server Optimization

```nix
# Kernel parameters for high-throughput VPN
boot.kernel.sysctl = {
  "net.core.default_qdisc" = "fq";
  "net.ipv4.tcp_congestion_control" = "bbr";
  "net.core.rmem_max" = 134217728;
  "net.core.wmem_max" = 134217728;
};
```

### Client Optimization

```nix
# Optimize for mobile devices
wireguard.peers = [
  {
    name = "mobile";
    # Shorter keepalive for NAT traversal
    persistentKeepalive = 15;
    # Reduce allowed IPs for better battery life
    allowedIPs = [ "192.168.1.0/24" ];
  }
];
```

## Monitoring and Maintenance

### Automated Monitoring

```nix
# Add monitoring for WireGuard service
systemd.services.wireguard-monitor = {
  description = "Monitor WireGuard connections";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.bash}/bin/bash -c 'wg show | logger -t wireguard-monitor'";
  };
};

systemd.timers.wireguard-monitor = {
  description = "Monitor WireGuard every 5 minutes";
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "*:0/5";
    Persistent = true;
  };
};
```

### Backup Configuration

```bash
# Backup WireGuard configuration
sudo cp -r /etc/wireguard /backup/wireguard-$(date +%Y%m%d)

# Backup web interface data (if using custom settings)
sudo docker exec wgdashboard tar -czf - /opt/wgdashboard/src/static/configurations > wgdashboard-backup-$(date +%Y%m%d).tar.gz
```

## Examples

See the `examples/` directory for complete configuration examples:

- `examples/wireguard-nas-server.nix` - NAS server setup with web interface

## Migration from Command-Line to Web Interface

If you have an existing WireGuard setup without web interface:

1. **Add web interface to configuration**:

```nix
wireguard.webInterface = {
  enable = true;
  port = 10086;
  autoUpdate = true;
};
```

2. **Deploy the configuration**:

```bash
sudo nixos-rebuild switch --flake .#your-host
```

3. **Access web interface**: Your existing configuration will be automatically converted and available in the web interface.

## Advanced Features

### Custom Interface Names

```nix
wireguard = {
  interface = "wg-nas";  # Custom interface name
  # Configuration uses the custom interface
};
```

### Multiple WireGuard Instances

While this module focuses on single-instance setup, you can run multiple WireGuard interfaces by using the lower-level `networking.wg-quick.interfaces` directly for additional instances.

### Docker Integration

The web interface uses Docker for isolation and easy updates. Docker is automatically enabled when using the web interface, but you can customize Docker settings:

```nix
virtualisation.docker = {
  enable = true;
  autoPrune.enable = true;  # Clean up old images
  daemon.settings = {
    log-driver = "journald";
  };
};
```

This completes the updated WireGuard module documentation, now including comprehensive coverage of the WGDashboard web interface, automatic updates, and enhanced management capabilities.
