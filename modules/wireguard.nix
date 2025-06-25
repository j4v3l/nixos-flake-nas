# WireGuard VPN configuration module
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.wireguard;
in
{
  options.wireguard = {
    enable = mkEnableOption "WireGuard VPN support";

    mode = mkOption {
      type = types.enum [ "server" "client" "peer" ];
      default = "server";
      description = ''
        WireGuard operation mode:
        - server: Act as VPN server/gateway with routing
        - client: Connect to remote WireGuard servers
        - peer: Peer-to-peer connections without gateway functionality
      '';
    };

    interface = mkOption {
      type = types.str;
      default = "wg0";
      description = "WireGuard interface name";
    };

    serverConfig = mkOption {
      type = types.submodule {
        options = {
          privateKeyFile = mkOption {
            type = types.path;
            default = "/etc/wireguard/private.key";
            description = "Path to server private key file";
          };

          publicKey = mkOption {
            type = types.str;
            default = "";
            description = "Server public key (auto-generated if empty)";
          };

          listenPort = mkOption {
            type = types.port;
            default = 51820;
            description = "UDP port for WireGuard server";
          };

          subnet = mkOption {
            type = types.str;
            default = "10.100.0.0/24";
            description = "VPN subnet for clients";
          };

          serverIP = mkOption {
            type = types.str;
            default = "10.100.0.1/24";
            description = "Server IP address within VPN subnet";
          };

          dns = mkOption {
            type = types.listOf types.str;
            default = [ "1.1.1.1" "8.8.8.8" ];
            description = "DNS servers to provide to clients";
          };

          allowedIPs = mkOption {
            type = types.listOf types.str;
            default = [ "0.0.0.0/0" "::/0" ];
            description = "IP ranges that clients can route through server";
          };
        };
      };
      default = {};
      description = "Server-specific configuration";
    };

    peers = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Peer name/identifier";
          };

          publicKey = mkOption {
            type = types.str;
            description = "Peer's public key";
          };

          allowedIPs = mkOption {
            type = types.listOf types.str;
            description = "IP addresses/ranges this peer is allowed to use";
          };

          endpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Peer endpoint (host:port) - for client connections";
          };

          persistentKeepalive = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Seconds between keepalive packets (useful for NAT)";
          };

          presharedKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to preshared key file for additional security";
          };
        };
      });
      default = [];
      description = "WireGuard peers configuration";
    };

    clientConfig = mkOption {
      type = types.submodule {
        options = {
          privateKeyFile = mkOption {
            type = types.path;
            default = "/etc/wireguard/client-private.key";
            description = "Path to client private key file";
          };

          address = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Client IP addresses within VPN";
          };

          dns = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "DNS servers to use when connected";
          };
        };
      };
      default = {};
      description = "Client-specific configuration";
    };

    # Security and networking options
    enablePacketForwarding = mkOption {
      type = types.bool;
      default = true;
      description = "Enable IP forwarding (required for server mode)";
    };

    restrictToLocalNetwork = mkOption {
      type = types.bool;
      default = false;
      description = "Restrict WireGuard access to local networks only";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically open firewall ports for WireGuard";
    };

    # Advanced options
    postUp = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Commands to run after interface is up";
    };

    postDown = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Commands to run after interface is down";
    };

    # Add WGDashboard option
    webInterface = {
      enable = mkEnableOption "WGDashboard web interface";
      
      port = mkOption {
        type = types.port;
        default = 10086;
        description = "Port for WGDashboard web interface";
      };
      
      adminUsername = mkOption {
        type = types.str;
        default = "admin";
        description = "Admin username for WGDashboard";
      };
      
      adminPasswordFile = mkOption {
        type = types.path;
        default = "/etc/wireguard/dashboard-password";
        description = "File containing admin password for WGDashboard";
      };
      
      autoUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically update WGDashboard weekly";
      };
    };
  };

  config = mkIf cfg.enable {
    # Install WireGuard tools
    environment.systemPackages = with pkgs; [
      wireguard-tools
      qrencode  # For generating QR codes for mobile clients
    ] ++ (optionals (cfg.mode == "server") [
      # Helper script for client configuration generation
      (pkgs.writeScriptBin "wireguard-client-config" ''
        #!${pkgs.bash}/bin/bash
        
        CLIENT_NAME="''${1:-client}"
        SERVER_ENDPOINT="''${2:-$(hostname -I | awk '{print $1}'):${toString cfg.serverConfig.listenPort}}"
        CLIENT_IP="''${3:-10.100.0.2/32}"
        
        echo "Generating WireGuard client configuration for: $CLIENT_NAME"
        echo "Server endpoint: $SERVER_ENDPOINT"
        echo "Client IP: $CLIENT_IP"
        echo
        
        # Generate client keys
        CLIENT_PRIVATE_KEY=$(${pkgs.wireguard-tools}/bin/wg genkey)
        CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | ${pkgs.wireguard-tools}/bin/wg pubkey)
        
        # Read server public key
        SERVER_PUBLIC_KEY=$(cat /etc/wireguard/public.key 2>/dev/null || echo "SERVER_PUBLIC_KEY_NOT_FOUND")
        
        cat > "$CLIENT_NAME.conf" << EOF
        [Interface]
        PrivateKey = $CLIENT_PRIVATE_KEY
        Address = $CLIENT_IP
        DNS = ${concatStringsSep ", " cfg.serverConfig.dns}
        
        [Peer]
        PublicKey = $SERVER_PUBLIC_KEY  
        Endpoint = $SERVER_ENDPOINT
        AllowedIPs = ${concatStringsSep ", " cfg.serverConfig.allowedIPs}
        PersistentKeepalive = 25
        EOF
        
        echo "Client configuration saved to: $CLIENT_NAME.conf"
        echo "Client public key (add this to server peers): $CLIENT_PUBLIC_KEY"
        echo
        echo "To generate QR code for mobile:"
        echo "${pkgs.qrencode}/bin/qrencode -t ansiutf8 < $CLIENT_NAME.conf"
      '')
    ]);

    # Enable IP forwarding if in server mode
    boot.kernel.sysctl = mkIf (cfg.mode == "server" && cfg.enablePacketForwarding) {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # WireGuard interface configuration (only if not using web interface)
    networking.wg-quick.interfaces = mkIf (!cfg.webInterface.enable) {
      ${cfg.interface} = {
        # Interface configuration
        address = if cfg.mode == "server" 
          then [ cfg.serverConfig.serverIP ]
          else cfg.clientConfig.address;
        
        listenPort = mkIf (cfg.mode == "server") cfg.serverConfig.listenPort;
        
        privateKeyFile = if cfg.mode == "server"
          then cfg.serverConfig.privateKeyFile
          else cfg.clientConfig.privateKeyFile;

        # DNS configuration
        dns = if cfg.mode == "client" && (length cfg.clientConfig.dns > 0)
          then cfg.clientConfig.dns
          else if cfg.mode == "server" then cfg.serverConfig.dns
          else [];

        # Peers configuration
        peers = map (peer: {
          inherit (peer) publicKey allowedIPs;
          endpoint = peer.endpoint;
          persistentKeepalive = peer.persistentKeepalive;
          presharedKeyFile = peer.presharedKeyFile;
        }) cfg.peers;

        # Post up/down commands
        postUp = cfg.postUp ++ (optionals (cfg.mode == "server") [
          # Server-specific iptables rules for NAT
          "${pkgs.iptables}/bin/iptables -A FORWARD -i ${cfg.interface} -j ACCEPT"
          "${pkgs.iptables}/bin/iptables -A FORWARD -o ${cfg.interface} -j ACCEPT"
          "${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.serverConfig.subnet} -o eth0 -j MASQUERADE"
        ]);

        postDown = cfg.postDown ++ (optionals (cfg.mode == "server") [
          # Clean up server-specific iptables rules
          "${pkgs.iptables}/bin/iptables -D FORWARD -i ${cfg.interface} -j ACCEPT 2>/dev/null || true"
          "${pkgs.iptables}/bin/iptables -D FORWARD -o ${cfg.interface} -j ACCEPT 2>/dev/null || true"
          "${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.serverConfig.subnet} -o eth0 -j MASQUERADE 2>/dev/null || true"
        ]);
      };
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = mkIf (cfg.mode == "server") [ cfg.serverConfig.listenPort ];
      allowedTCPPorts = mkIf cfg.webInterface.enable [ cfg.webInterface.port ];
      
      # Restrict to local networks if enabled
      extraCommands = mkIf cfg.restrictToLocalNetwork (mkIf (cfg.mode == "server") ''
        # Allow WireGuard from local networks only
        iptables -A nixos-fw -s 192.168.0.0/16 -p udp --dport ${toString cfg.serverConfig.listenPort} -j ACCEPT
        iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport ${toString cfg.serverConfig.listenPort} -j ACCEPT
        iptables -A nixos-fw -s 172.16.0.0/12 -p udp --dport ${toString cfg.serverConfig.listenPort} -j ACCEPT
      '');
    };

    # Create systemd service for key generation
    systemd.services.wireguard-key-gen = mkIf (cfg.mode == "server") {
      description = "Generate WireGuard server keys";
      wantedBy = [ "multi-user.target" ];
      before = [ "wg-quick-${cfg.interface}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "wireguard-key-gen" ''
          #!${pkgs.bash}/bin/bash
          set -e
          
          PRIVATE_KEY_FILE="${cfg.serverConfig.privateKeyFile}"
          PUBLIC_KEY_FILE="/etc/wireguard/public.key"
          
          # Create directory if it doesn't exist
          mkdir -p "$(dirname "$PRIVATE_KEY_FILE")"
          
          # Generate private key if it doesn't exist
          if [[ ! -f "$PRIVATE_KEY_FILE" ]]; then
            echo "Generating WireGuard private key..."
            ${pkgs.wireguard-tools}/bin/wg genkey > "$PRIVATE_KEY_FILE"
            chmod 600 "$PRIVATE_KEY_FILE"
          fi
          
          # Generate public key
          echo "Generating WireGuard public key..."
          ${pkgs.wireguard-tools}/bin/wg pubkey < "$PRIVATE_KEY_FILE" > "$PUBLIC_KEY_FILE"
          chmod 644 "$PUBLIC_KEY_FILE"
          
          echo "WireGuard keys generated successfully:"
          echo "Private key: $PRIVATE_KEY_FILE (keep secret!)"
          echo "Public key: $(cat "$PUBLIC_KEY_FILE")"
        '';
      };
    };

    # WGDashboard web interface
    virtualisation.docker.enable = mkIf cfg.webInterface.enable true;
    
    systemd.services.wgdashboard = mkIf cfg.webInterface.enable {
      description = "WGDashboard - WireGuard Web Interface";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "wg-quick-${cfg.interface}.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10";
        ExecStartPre = [
          # Pull the latest image
          "${pkgs.docker}/bin/docker pull donaldzou/wgdashboard:latest"
          # Remove any existing container
          "-${pkgs.docker}/bin/docker rm -f wgdashboard"
        ];
        ExecStart = "${pkgs.docker}/bin/docker run --rm --name wgdashboard " +
          "--cap-add NET_ADMIN " +
          "--cap-add SYS_MODULE " +
          "-v /etc/wireguard:/etc/wireguard " +
          "-v /lib/modules:/lib/modules:ro " +
          "-p ${toString cfg.webInterface.port}:10086 " +
          "donaldzou/wgdashboard:latest";
        ExecStop = "${pkgs.docker}/bin/docker stop wgdashboard";
      };
    };

    # WGDashboard automatic update service
    systemd.services.wgdashboard-update = mkIf (cfg.webInterface.enable && cfg.webInterface.autoUpdate) {
      description = "Update WGDashboard Docker image";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "wgdashboard-update" ''
          #!${pkgs.bash}/bin/bash
          set -e
          
          echo "Checking for WGDashboard updates..."
          
          # Pull latest image
          ${pkgs.docker}/bin/docker pull donaldzou/wgdashboard:latest
          
          # Get current and latest image IDs
          CURRENT_ID=$(${pkgs.docker}/bin/docker inspect wgdashboard --format='{{.Image}}' 2>/dev/null || echo "")
          LATEST_ID=$(${pkgs.docker}/bin/docker inspect donaldzou/wgdashboard:latest --format='{{.Id}}' 2>/dev/null || echo "")
          
          if [[ "$CURRENT_ID" != "$LATEST_ID" && -n "$LATEST_ID" ]]; then
            echo "New WGDashboard version available. Restarting service..."
            systemctl restart wgdashboard.service
            echo "WGDashboard updated successfully!"
          else
            echo "WGDashboard is already up to date."
          fi
        '';
      };
    };

    # Weekly update timer for WGDashboard
    systemd.timers.wgdashboard-update = mkIf (cfg.webInterface.enable && cfg.webInterface.autoUpdate) {
      description = "Weekly WGDashboard update check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    # Create default dashboard password if it doesn't exist
    systemd.services.wgdashboard-setup = mkIf cfg.webInterface.enable {
      description = "Setup WGDashboard default password and config";
      wantedBy = [ "multi-user.target" ];
      before = [ "wgdashboard.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c '" + ''
          set -e
          
          PASSWORD_FILE="${cfg.webInterface.adminPasswordFile}"
          WG_CONFIG="/etc/wireguard/${cfg.interface}.conf"
          
          # Create directory if it doesn't exist
          mkdir -p "$(dirname "$PASSWORD_FILE")"
          
          # Generate default password if file doesn't exist
          if [[ ! -f "$PASSWORD_FILE" ]]; then
            echo "admin" > "$PASSWORD_FILE"
            chmod 600 "$PASSWORD_FILE"
            echo "WGDashboard default password created at: $PASSWORD_FILE"
            echo "Default login: ${cfg.webInterface.adminUsername}/admin"
            echo "Please change the password after first login!"
          fi
          
          # Create WireGuard config file for WGDashboard if it doesn't exist
          if [[ ! -f "$WG_CONFIG" ]]; then
            echo "Creating WireGuard config for WGDashboard..."
            cat > "$WG_CONFIG" << 'EOF'
[Interface]
Address = ${cfg.serverConfig.serverIP}
PrivateKey = $(cat ${cfg.serverConfig.privateKeyFile})
ListenPort = ${toString cfg.serverConfig.listenPort}
DNS = ${concatStringsSep ", " cfg.serverConfig.dns}
PostUp = iptables -A FORWARD -i ${cfg.interface} -j ACCEPT; iptables -A FORWARD -o ${cfg.interface} -j ACCEPT; iptables -t nat -A POSTROUTING -s ${cfg.serverConfig.subnet} -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i ${cfg.interface} -j ACCEPT; iptables -D FORWARD -o ${cfg.interface} -j ACCEPT; iptables -t nat -D POSTROUTING -s ${cfg.serverConfig.subnet} -o eth0 -j MASQUERADE
SaveConfig = true

EOF
            chmod 600 "$WG_CONFIG"
            echo "WireGuard config created for WGDashboard management"
          fi
        '' + "';";
      };
    };



  };
} 