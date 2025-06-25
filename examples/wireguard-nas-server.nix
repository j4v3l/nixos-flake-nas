# Example: WireGuard Server Configuration for NAS
# Add this to your hosts/beelink-mini/configuration.nix

{
  imports = [
    # ... your existing imports ...
    ../../modules/wireguard.nix
  ];

  # Enable WireGuard server for remote NAS access
  wireguard = {
    enable = true;
    mode = "server";
    
    serverConfig = {
      listenPort = 51820;
      subnet = "10.100.0.0/24";
      serverIP = "10.100.0.1/24";
      # Use secure DNS servers
      dns = [ "1.1.1.1" "8.8.8.8" ];
      # Allow full internet access through VPN (or restrict to local network only)
      allowedIPs = [ "0.0.0.0/0" "::/0" ];
    };

    # Example client/peer configurations
    peers = [
      {
        name = "laptop";
        publicKey = "CLIENT_PUBLIC_KEY_HERE";
        allowedIPs = [ "10.100.0.2/32" ];
        persistentKeepalive = 25;
      }
      {
        name = "phone";
        publicKey = "PHONE_PUBLIC_KEY_HERE";
        allowedIPs = [ "10.100.0.3/32" ];
        persistentKeepalive = 25;
      }
    ];

    # Security options
    openFirewall = true;
    restrictToLocalNetwork = false;  # Set to true if only local access is needed
    enablePacketForwarding = true;   # Required for server mode
  };

  # Optional: Additional firewall rules for secure NAS access
  networking.firewall = {
    # Allow Samba access from VPN clients
    extraCommands = ''
      # Allow Samba from WireGuard clients
      iptables -A nixos-fw -s 10.100.0.0/24 -p tcp --dport 139 -j ACCEPT
      iptables -A nixos-fw -s 10.100.0.0/24 -p tcp --dport 445 -j ACCEPT
      iptables -A nixos-fw -s 10.100.0.0/24 -p udp --dport 137 -j ACCEPT
      iptables -A nixos-fw -s 10.100.0.0/24 -p udp --dport 138 -j ACCEPT
    '';
  };
}

# After deployment:
# 1. Server keys are auto-generated in /etc/wireguard/
# 2. Use `wireguard-client-config` command to generate client configs:
#    sudo wireguard-client-config laptop 192.168.1.100:51820 10.100.0.2/32
# 3. Add the client's public key to the peers configuration above
# 4. Rebuild the system: sudo nixos-rebuild switch --flake .#beelink-mini 