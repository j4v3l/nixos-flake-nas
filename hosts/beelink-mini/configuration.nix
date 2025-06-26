{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/beelink-mini.nix  # This will be the actual system hardware config
    ../../modules/base.nix
    ../../modules/samba.nix
    ../../modules/secrets.nix
    ../../modules/wifi.nix
    ../../modules/storage.nix
    ../../modules/motd.nix
    ../../modules/wireguard.nix
    ../../modules/atuin.nix
    ../../modules/containers.nix
    # Home Manager configuration is now handled through flake.nix
  ];

  networking.hostName = "beelink-mini";
  wifi.enable = true;
  storage.enable = true;  # Enable advanced storage management for 6-slot NAS
  motd.enable = true;     # Enable server-style MOTD
  
  # Container management configuration
  containerServices = {
    enable = true;
    # Enable essential NAS services
    services = {
      media = {
        enable = true;
        type = "jellyfin";
        enableHardwareAccel = true;  # Now enabled with proper Intel graphics drivers
        # Uses /mnt/data/media from storage module by default
      };
      sync = {
        enable = true;
        type = "syncthing";
        # Uses /mnt/data/sync by default
      };
      downloads = {
        enable = true;
        services = [ "qbittorrent" ];
        # Uses /mnt/data/downloads by default
      };
      # Monitoring disabled by default - uncomment to enable
      # monitoring = {
      #   enable = true;
      #   prometheus.enable = true;
      #   grafana.enable = true;
      # };
    };
    # Security follows existing patterns
    security = {
      restrictToLocalNetwork = true;
      enableFirewall = true;
      # Inherits allowed networks from WireGuard and Samba configs
    };
    management = {
      enablePortainer = true;
      enableWatchtower = false;  # Temporarily disabled for initial testing
      backupContainers = true;
    };
  };
  
  # Atuin shell history sync configuration
  atuin = {
    enable = true;
    daemon = {
      enable = true;
      logLevel = "info";
      syncFrequency = "15m";
    };
    # Optionally enable self-hosted server (disabled by default)
    # server = {
    #   enable = true;
    #   port = 8888;
    #   registrationDisabled = true;
    # };
  };
  
  # WireGuard VPN Configuration
  wireguard = {
    enable = true;
    mode = "server";
    
    serverConfig = {
      listenPort = 51820;
      subnet = "10.100.0.0/24";
      serverIP = "10.100.0.1/24";
      dns = [ "1.1.1.1" "8.8.8.8" ];
      # Only route home network and VPN subnet, not all internet traffic
      allowedIPs = [ "192.168.1.0/24" "10.100.0.0/24" ];
    };
    
    # Restrict to local network for security
    restrictToLocalNetwork = true;
    
    # Enable WGDashboard web interface
    webInterface = {
      enable = true;
      port = 10086;
      adminUsername = "admin";
    };
    
    # Example peers - you'll need to replace with actual client public keys
    peers = [
      # {
      #   name = "laptop";
      #   publicKey = "YOUR_CLIENT_PUBLIC_KEY_HERE";
      #   allowedIPs = [ "10.100.0.2/32" ];
      #   persistentKeepalive = 25;
      # }
    ];
  };
  
  system.stateVersion = "25.05";
}
