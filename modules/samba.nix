{ config, pkgs, ... }:

{
  services.samba = {
    enable = true;
    # Don't automatically open firewall - we'll configure it manually
    openFirewall = false;
    
    # Global samba settings for security
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "NixOS NAS";
        "netbios name" = "beelink-mini";
        security = "user";
        "map to guest" = "never";
        # Disable older, insecure protocols
        "min protocol" = "SMB2";
        "client min protocol" = "SMB2";
      };
      
      data = {
        path = "/mnt/data";
        browseable = true;
        writable = true;
        # Disable guest access for security
        "guest ok" = false;
        # Only allow specific users
        "valid users" = "jager";
        # Set secure file permissions
        "create mask" = "0644";
        "directory mask" = "0755";
        # Additional security settings
        "force user" = "jager";
        "force group" = "users";
      };
    };
  };

  # Configure firewall for Samba on local network only
  networking.firewall = {
    # Allow Samba ports on all local interfaces
    # This is more robust than hardcoding specific interface names
    allowedTCPPorts = [ 139 445 ]; # Samba
    allowedUDPPorts = [ 137 138 ]; # NetBIOS
    # Restrict to local network ranges for security
    extraCommands = ''
      iptables -A nixos-fw -s 192.168.0.0/16 -p tcp --dport 139 -j ACCEPT
      iptables -A nixos-fw -s 192.168.0.0/16 -p tcp --dport 445 -j ACCEPT
      iptables -A nixos-fw -s 192.168.0.0/16 -p udp --dport 137 -j ACCEPT
      iptables -A nixos-fw -s 192.168.0.0/16 -p udp --dport 138 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p tcp --dport 139 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p tcp --dport 445 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport 137 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport 138 -j ACCEPT
      iptables -A nixos-fw -s 172.16.0.0/12 -p tcp --dport 139 -j ACCEPT
      iptables -A nixos-fw -s 172.16.0.0/12 -p tcp --dport 445 -j ACCEPT
      iptables -A nixos-fw -s 172.16.0.0/12 -p udp --dport 137 -j ACCEPT
      iptables -A nixos-fw -s 172.16.0.0/12 -p udp --dport 138 -j ACCEPT
    '';
  };

  # Data disk configuration - flexible to handle different setups
  fileSystems."/mnt/data" = {
    # Try by-label first, fall back to by-uuid if needed
    # This will need to be configured based on actual disk setup
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    options = [ "defaults" "user_xattr" "acl" "nofail" ]; # nofail prevents boot failure if disk not present
  };

  # Create data directory and set permissions
  systemd.services.setup-data-directory = {
    description = "Setup data directory permissions";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Create the directory if it doesn't exist
      mkdir -p /mnt/data
      
      # Set proper ownership and permissions
      chown jager:users /mnt/data
      chmod 755 /mnt/data
      
      # If the filesystem is mounted and empty, create a basic structure
      if mountpoint -q /mnt/data && [ -z "$(ls -A /mnt/data 2>/dev/null)" ]; then
        mkdir -p /mnt/data/shared
        chown jager:users /mnt/data/shared
        chmod 755 /mnt/data/shared
      fi
    '';
  };

  # Ensure the mount directory exists with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt/data 0755 jager users -"
  ];

  # Add fail2ban protection for Samba
  services.fail2ban = {
    enable = true;
    jails.samba = ''
      enabled = true
      filter = samba
      action = iptables-multiport[name=samba, port="139,445", protocol=tcp]
      logpath = /var/log/samba/log.smbd
      maxretry = 3
      bantime = 3600
    '';
  };
}
