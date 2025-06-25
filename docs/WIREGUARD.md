# WireGuard VPN Module

This document describes the WireGuard VPN module for secure networking in your NixOS flake configuration.

## Overview

The WireGuard module provides a flexible and secure VPN solution for:

- **Remote NAS Access**: Securely access your home network and file shares from anywhere
- **Site-to-Site VPN**: Connect multiple networks (home, office) securely
- **Peer-to-Peer**: Direct encrypted connections between devices

## Features

- **Multi-mode Operation**: Server, client, or peer-to-peer configurations
- **Automatic Key Management**: Server keys are auto-generated and managed
- **Client Config Generator**: Built-in script to generate client configurations
- **Firewall Integration**: Automatic firewall rules with security options
- **QR Code Support**: Generate QR codes for easy mobile device setup
- **Flexible Routing**: Custom post-up/down commands for advanced networking
- **Security Hardening**: Local network restrictions and proper defaults

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

### 2. Deploy and Generate Client Config

```bash
# Deploy the configuration
sudo nixos-rebuild switch --flake .#beelink-mini

# Generate client configuration
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

## Usage Scenarios

### 1. Remote NAS Access

**Use Case**: Access your home NAS and network from anywhere securely.

```nix
# NAS Configuration
wireguard = {
  enable = true;
  mode = "server";
  
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

### 2. Site-to-Site VPN

**Use Case**: Connect multiple networks securely.

```nix
# Main site configuration
wireguard = {
  enable = true;
  mode = "server";
  
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

### 1. Key Management

```bash
# Server keys are auto-generated, but you can manage them manually:
sudo wg genkey > /etc/wireguard/private.key
sudo chmod 600 /etc/wireguard/private.key
sudo wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
```

### 2. Network Restrictions

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

### 3. Preshared Keys

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

### 4. Firewall Integration

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

# Generate client configuration
sudo wireguard-client-config client-name server-ip:port client-ip

# Generate QR code for mobile
sudo wireguard-client-config phone | qrencode -t ansiutf8

# Monitor connections
sudo journalctl -u wg-quick-wg0 -f
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

### Common Problems

1. **Can't connect to server**
   - Check firewall rules on server
   - Verify endpoint IP/port is correct
   - Ensure server is listening: `sudo ss -ulnp | grep 51820`

2. **Connected but no internet/network access**
   - Check IP forwarding: `cat /proc/sys/net/ipv4/ip_forward`
   - Verify NAT rules: `sudo iptables -t nat -L POSTROUTING`
   - Check DNS configuration

3. **Keys not working**
   - Regenerate keys: `sudo systemctl restart wireguard-key-gen`
   - Verify public key matches private key
   - Check file permissions (600 for private keys)

## Integration with Existing Modules

### With Secrets Module

```nix
# Use secrets module for key management
age.secrets.wireguard-private = {
  file = ../secrets/wireguard-private.age;
  path = "/etc/wireguard/private.key";
  mode = "600";
};

wireguard.serverConfig.privateKeyFile = "/etc/wireguard/private.key";
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

## Examples

See the `examples/` directory for complete configuration examples:

- `examples/wireguard-nas-server.nix` - NAS server setup

## Advanced Features

### Custom Interface Names

```nix
wireguard = {
  interface = "wg-nas";  # Custom interface name
  # Configuration uses the custom interface
};
```

### Multiple WireGuard Instances

```nix
# You can run multiple WireGuard interfaces
# by creating multiple module instances or using
# the lower-level networking.wg-quick.interfaces directly
```

This completes the WireGuard module documentation. The module provides a secure, flexible VPN solution that integrates seamlessly with your existing NixOS infrastructure.
