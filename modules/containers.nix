# Container management module for NixOS NAS
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.containerServices;
in
{
  options.containerServices = {
    enable = mkEnableOption "Container management and NAS services";

    dataPath = mkOption {
      type = types.str;
      default = "/mnt/data";
      description = "Base path for container data storage";
    };

    configPath = mkOption {
      type = types.str;
      default = "/etc/containers";
      description = "Path for container configuration files";
    };

    # Docker daemon configuration
    docker = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Docker container runtime";
      };

      rootless = mkOption {
        type = types.bool;
        default = false;
        description = "Enable rootless Docker for better security";
      };

      storageDriver = mkOption {
        type = types.str;
        default = "overlay2";
        description = "Docker storage driver";
      };

      logLevel = mkOption {
        type = types.enum [ "debug" "info" "warn" "error" "fatal" ];
        default = "warn";
        description = "Docker daemon log level";
      };

      autoUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic container image updates";
      };

      pruneInterval = mkOption {
        type = types.str;
        default = "weekly";
        description = "How often to prune unused containers and images";
      };
    };

    # NAS-specific services
    services = {
      # Media server configuration
      media = {
        enable = mkEnableOption "Media server services (Plex/Jellyfin)";
        
        type = mkOption {
          type = types.enum [ "plex" "jellyfin" "both" ];
          default = "jellyfin";
          description = "Media server type to deploy";
        };

        mediaPath = mkOption {
          type = types.str;
          default = "${cfg.dataPath}/media";
          description = "Path to media files";
        };

        port = mkOption {
          type = types.port;
          default = 8096;
          description = "Media server web interface port";
        };

        enableHardwareAccel = mkOption {
          type = types.bool;
          default = false;
          description = "Enable hardware acceleration for transcoding";
        };
      };

      # File sync and backup
      sync = {
        enable = mkEnableOption "File synchronization services (Nextcloud/Syncthing)";
        
        type = mkOption {
          type = types.enum [ "nextcloud" "syncthing" "both" ];
          default = "syncthing";
          description = "Sync service type to deploy";
        };

        port = mkOption {
          type = types.port;
          default = 8080;
          description = "Sync service web interface port";
        };

        dataPath = mkOption {
          type = types.str;
          default = "${cfg.dataPath}/sync";
          description = "Path for sync service data";
        };
      };

      # Download management
      downloads = {
        enable = mkEnableOption "Download management services";
        
        services = mkOption {
          type = types.listOf (types.enum [ "qbittorrent" "transmission" "nzbget" "sabnzbd" ]);
          default = [ "qbittorrent" ];
          description = "Download services to enable";
        };

        downloadPath = mkOption {
          type = types.str;
          default = "${cfg.dataPath}/downloads";
          description = "Path for downloaded files";
        };

        webPort = mkOption {
          type = types.port;
          default = 8081;
          description = "Download manager web interface port";
        };
      };

      # Home automation
      homeAssistant = {
        enable = mkEnableOption "Home Assistant automation platform";
        
        port = mkOption {
          type = types.port;
          default = 8123;
          description = "Home Assistant web interface port";
        };

        configPath = mkOption {
          type = types.str;
          default = "${cfg.configPath}/homeassistant";
          description = "Home Assistant configuration directory";
        };
      };

      # Monitoring and observability
      monitoring = {
        enable = mkEnableOption "Monitoring services (Prometheus, Grafana)";
        
        prometheus = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Prometheus metrics collection";
          };
          
          port = mkOption {
            type = types.port;
            default = 9090;
            description = "Prometheus web interface port";
          };
        };

        grafana = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Grafana dashboards";
          };
          
          port = mkOption {
            type = types.port;
            default = 3000;
            description = "Grafana web interface port";
          };
        };
      };

      # VPN and proxy services
      network = {
        enable = mkEnableOption "Network services (AdGuard, Pi-hole, Nginx Proxy Manager)";
        
        adguard = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable AdGuard Home DNS ad blocker";
          };
          
          port = mkOption {
            type = types.port;
            default = 3001;
            description = "AdGuard Home web interface port";
          };
        };

        reverseProxy = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Nginx Proxy Manager for reverse proxy";
          };
          
          port = mkOption {
            type = types.port;
            default = 8180;
            description = "Nginx Proxy Manager web interface port";
          };
        };
      };
    };

    # Security and networking
    security = {
      restrictToLocalNetwork = mkOption {
        type = types.bool;
        default = true;
        description = "Restrict container web interfaces to local network";
      };

      enableFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Configure firewall rules for container services";
      };

      allowedNetworks = mkOption {
        type = types.listOf types.str;
        default = [ "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
        description = "Networks allowed to access container services";
      };
    };

    # Management and convenience
    management = {
      enablePortainer = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Portainer for container management";
      };

      portainerPort = mkOption {
        type = types.port;
        default = 9000;
        description = "Portainer web interface port";
      };

      enableWatchtower = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Watchtower for automatic container updates";
      };

      backupContainers = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic container configuration backups";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable Docker
    virtualisation.docker = mkIf cfg.docker.enable {
      enable = true;
      rootless = mkIf cfg.docker.rootless {
        enable = true;
        setSocketVariable = true;
      };
      storageDriver = cfg.docker.storageDriver;
             daemon.settings = {
         log-level = cfg.docker.logLevel;
         log-driver = "journald";
         storage-driver = cfg.docker.storageDriver;
       };
    };

    # Add container management packages
    environment.systemPackages = with pkgs; [
      # Container runtimes and tools
      docker
      docker-compose
      ctop           # Container monitoring
      dive           # Docker image analyzer
      lazydocker     # TUI for Docker management
      
      # Backup and sync tools
      rsync
      rclone
      
      # Network tools for troubleshooting
      netcat-gnu
      tcpdump
    ];

    # User configuration
    users.users.jager.extraGroups = mkIf cfg.docker.enable [ "docker" ];

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0755 jager users -"
      "d ${cfg.configPath} 0755 jager users -"
      "d ${cfg.dataPath}/containers 0755 jager users -"
      "d ${cfg.dataPath}/media 0755 jager users -"
      "d ${cfg.dataPath}/downloads 0755 jager users -"
      "d ${cfg.dataPath}/sync 0755 jager users -"
      "d ${cfg.dataPath}/backups 0755 jager users -"
      "d ${cfg.configPath}/compose 0755 jager users -"
    ];

    # Systemd services for container management
    systemd.services = {
      # Container setup service
      containers-setup = {
        description = "Container environment setup";
        wantedBy = [ "multi-user.target" ];
        after = [ "docker.service" "local-fs.target" ];
        wants = [ "docker.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutSec = 300;
        };
        script = ''
          #!/bin/bash
          set -euo pipefail

          echo "=== Container Environment Setup ==="
          
          # Ensure Docker is running
          systemctl is-active docker || {
            echo "Docker is not running, attempting to start..."
            systemctl start docker
            sleep 5
          }

          # Create Docker networks for NAS services
          ${pkgs.docker}/bin/docker network ls | grep -q nas-network || {
            echo "Creating NAS docker network..."
            ${pkgs.docker}/bin/docker network create \
              --driver bridge \
              --subnet=172.20.0.0/16 \
              --gateway=172.20.0.1 \
              nas-network
          }

          # Create media network if media services enabled
          ${optionalString cfg.services.media.enable ''
          ${pkgs.docker}/bin/docker network ls | grep -q media-network || {
            echo "Creating media docker network..."
            ${pkgs.docker}/bin/docker network create \
              --driver bridge \
              --subnet=172.21.0.0/16 \
              --gateway=172.21.0.1 \
              media-network
          }
          ''}

          # Set proper permissions
          chown -R jager:users ${cfg.dataPath}/containers
          chown -R jager:users ${cfg.configPath}

          echo "=== Container Environment Setup Complete ==="
        '';
      };

      # Docker compose management service
      docker-compose-nas = mkIf (cfg.services.media.enable || cfg.services.sync.enable || cfg.services.downloads.enable) {
        description = "NAS Docker Compose Services";
        wantedBy = [ "multi-user.target" ];
        after = [ "containers-setup.service" "network.target" ];
        wants = [ "containers-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${cfg.configPath}/compose";
          TimeoutStartSec = 600;
        };
        script = ''
          #!/bin/bash
          set -euo pipefail

          echo "=== Starting NAS Container Services ==="
          
          # Generate docker-compose.yml if it doesn't exist
          if [[ ! -f docker-compose.yml ]]; then
            echo "Generating docker-compose.yml..."
            cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
${optionalString (cfg.management.enablePortainer) ''
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "${toString cfg.management.portainerPort}:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${cfg.dataPath}/containers/portainer:/data
    networks:
      - nas-network
''}
${optionalString (cfg.services.media.enable && cfg.services.media.type == "jellyfin") ''
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    user: "$(id -u jager):$(id -g users)"
    ports:
      - "${toString cfg.services.media.port}:8096"
    volumes:
      - ${cfg.services.media.mediaPath}:/media:ro
      - ${cfg.dataPath}/containers/jellyfin/config:/config
      - ${cfg.dataPath}/containers/jellyfin/cache:/cache
    environment:
      - JELLYFIN_PublishedServerUrl=http://$(hostname -I | awk '{print $1}'):${toString cfg.services.media.port}
    networks:
      - media-network
''}
${optionalString (cfg.services.sync.enable && cfg.services.sync.type == "syncthing") ''
  syncthing:
    image: syncthing/syncthing:latest
    container_name: syncthing
    restart: unless-stopped
    user: "$(id -u jager):$(id -g users)"
    ports:
      - "${toString cfg.services.sync.port}:8384"
      - "22000:22000/tcp"
      - "22000:22000/udp"
      - "21027:21027/udp"
    volumes:
      - ${cfg.services.sync.dataPath}:/var/syncthing/data
      - ${cfg.dataPath}/containers/syncthing/config:/var/syncthing/config
    environment:
      - PUID=$(id -u jager)
      - PGID=$(id -g users)
    networks:
      - nas-network
''}
${optionalString (cfg.services.downloads.enable && elem "qbittorrent" cfg.services.downloads.services) ''
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=$(id -u jager)
      - PGID=$(id -g users)
      - TZ=America/New_York
      - WEBUI_PORT=${toString cfg.services.downloads.webPort}
    ports:
      - "${toString cfg.services.downloads.webPort}:${toString cfg.services.downloads.webPort}"
      - "6881:6881"
      - "6881:6881/udp"
    volumes:
      - ${cfg.dataPath}/containers/qbittorrent/config:/config
      - ${cfg.services.downloads.downloadPath}:/downloads
    networks:
      - nas-network
''}
${optionalString (cfg.management.enableWatchtower) ''
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400
      - WATCHTOWER_INCLUDE_RESTARTING=true
    networks:
      - nas-network
''}

networks:
  nas-network:
    external: true
${optionalString cfg.services.media.enable ''
  media-network:
    external: true
''}
EOF
          fi

          # Start services
          ${pkgs.docker-compose}/bin/docker-compose up -d
          
          echo "=== NAS Container Services Started ==="
        '';
        preStop = ''
          cd ${cfg.configPath}/compose
          ${pkgs.docker-compose}/bin/docker-compose down || true
        '';
      };

      # Container backup service
      containers-backup = mkIf cfg.management.backupContainers {
        description = "Backup container configurations and data";
        serviceConfig = {
          Type = "oneshot";
          User = "jager";
        };
        script = ''
          #!/bin/bash
          set -euo pipefail

          BACKUP_DIR="${cfg.dataPath}/backups/containers"
          DATE=$(date +%Y%m%d_%H%M%S)
          
          mkdir -p "$BACKUP_DIR"
          
          # Backup container configs
          if [[ -d "${cfg.configPath}" ]]; then
            tar -czf "$BACKUP_DIR/container-configs-$DATE.tar.gz" -C "${cfg.configPath}" .
          fi
          
          # Backup docker-compose files
          if [[ -f "${cfg.configPath}/compose/docker-compose.yml" ]]; then
            cp "${cfg.configPath}/compose/docker-compose.yml" "$BACKUP_DIR/docker-compose-$DATE.yml"
          fi
          
          # Keep only last 10 backups
          cd "$BACKUP_DIR"
          ls -t container-configs-*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f || true
          ls -t docker-compose-*.yml 2>/dev/null | tail -n +11 | xargs rm -f || true
          
          echo "Container configurations backed up to $BACKUP_DIR"
        '';
      };

      # Container monitoring service  
      containers-monitor = {
        description = "Monitor container health and performance";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = ''
          #!/bin/bash
          
          # Check container health
          unhealthy=$(${pkgs.docker}/bin/docker ps --filter "health=unhealthy" --format "table {{.Names}}" | tail -n +2)
          if [[ -n "$unhealthy" ]]; then
            echo "WARNING: Unhealthy containers detected: $unhealthy" | systemd-cat -t containers-monitor -p warning
          fi
          
          # Check for containers using excessive resources
          ${pkgs.docker}/bin/docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | \
          while read line; do
            if [[ "$line" =~ ([0-9]+\.[0-9]+)% ]]; then
              cpu_usage=''${BASH_REMATCH[1]}
              if (( $(echo "$cpu_usage > 80" | ${pkgs.bc}/bin/bc -l) )); then
                container_name=$(echo "$line" | awk '{print $1}')
                echo "WARNING: Container $container_name high CPU usage: $cpu_usage%" | systemd-cat -t containers-monitor -p warning
              fi
            fi
          done
        '';
      };
    };

    # Timers for container management
    systemd.timers = {
      containers-backup = mkIf cfg.management.backupContainers {
        description = "Container backup timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };

      containers-monitor = {
        description = "Container monitoring timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/15"; # Every 15 minutes
          Persistent = true;
        };
      };

      docker-system-prune = mkIf cfg.docker.autoUpdate {
        description = "Docker system cleanup timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.docker.pruneInterval;
          Persistent = true;
        };
      };
    };

    # Docker system cleanup service
    systemd.services.docker-system-prune = mkIf cfg.docker.autoUpdate {
      description = "Docker system cleanup";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        # Clean up unused containers, networks, images, and build cache
        ${pkgs.docker}/bin/docker system prune -af --volumes
        
        # Log cleanup results
        echo "Docker system cleanup completed" | systemd-cat -t docker-cleanup
      '';
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.security.enableFirewall {
      allowedTCPPorts = []
        ++ optional cfg.management.enablePortainer cfg.management.portainerPort
        ++ optional cfg.services.media.enable cfg.services.media.port
        ++ optional cfg.services.sync.enable cfg.services.sync.port
        ++ optional cfg.services.downloads.enable cfg.services.downloads.webPort
        ++ optional cfg.services.homeAssistant.enable cfg.services.homeAssistant.port
        ++ optional (cfg.services.monitoring.enable && cfg.services.monitoring.prometheus.enable) cfg.services.monitoring.prometheus.port
        ++ optional (cfg.services.monitoring.enable && cfg.services.monitoring.grafana.enable) cfg.services.monitoring.grafana.port
        ++ optional (cfg.services.network.enable && cfg.services.network.adguard.enable) cfg.services.network.adguard.port
        ++ optional (cfg.services.network.enable && cfg.services.network.reverseProxy.enable) cfg.services.network.reverseProxy.port;

      allowedUDPPorts = []
        ++ optional (cfg.services.sync.enable && cfg.services.sync.type == "syncthing") 21027
        ++ optional (cfg.services.sync.enable && cfg.services.sync.type == "syncthing") 22000
        ++ optional (cfg.services.downloads.enable && elem "qbittorrent" cfg.services.downloads.services) 6881;

      # Restrict access to local networks if configured
      extraCommands = mkIf cfg.security.restrictToLocalNetwork (
        concatStringsSep "\n" (flatten (map (port: map (network: 
          "iptables -A nixos-fw -s ${network} -p tcp --dport ${toString port} -j ACCEPT"
        ) cfg.security.allowedNetworks) [
          cfg.management.portainerPort
          cfg.services.media.port
          cfg.services.sync.port  
          cfg.services.downloads.webPort
          cfg.services.homeAssistant.port
          cfg.services.monitoring.prometheus.port
          cfg.services.monitoring.grafana.port
          cfg.services.network.adguard.port
          cfg.services.network.reverseProxy.port
        ]))
      );
    };

    # Shell aliases for container management
    programs.bash.shellAliases = {
      # Docker management
      "dps" = "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'";
      "dpsall" = "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'";
      "dlogs" = "docker logs -f";
      "dexec" = "docker exec -it";
      "dstats" = "ctop";
      "dimages" = "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'";
      "lazy" = "lazydocker";
      
      # Container service management
      "containers-start" = "sudo systemctl start docker-compose-nas";
      "containers-stop" = "sudo systemctl stop docker-compose-nas";
      "containers-restart" = "sudo systemctl restart docker-compose-nas";
      "containers-status" = "sudo systemctl status docker-compose-nas";
      "containers-logs" = "sudo journalctl -u docker-compose-nas -f";
      
      # Compose management
      "compose-up" = "cd ${cfg.configPath}/compose && docker compose up -d";
      "compose-down" = "cd ${cfg.configPath}/compose && docker compose down";
      "compose-restart" = "cd ${cfg.configPath}/compose && docker compose restart";
      "compose-logs" = "cd ${cfg.configPath}/compose && docker compose logs -f";
      "compose-pull" = "cd ${cfg.configPath}/compose && docker compose pull";
      
      # Quick access to container data
      "cdcontainers" = "cd ${cfg.dataPath}/containers";
      "cdcompose" = "cd ${cfg.configPath}/compose";
      "cdmedia" = "cd ${cfg.services.media.mediaPath}";
      "cddownloads" = "cd ${cfg.services.downloads.downloadPath}";
      
      # Container maintenance
      "docker-cleanup" = "docker system prune -af";
      "docker-update" = "cd ${cfg.configPath}/compose && docker compose pull && docker compose up -d";
      "containers-backup" = "sudo systemctl start containers-backup";
    };

    # Add container management aliases to zsh as well
    programs.zsh.shellAliases = {
      # Docker management  
      "dps" = "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'";
      "dpsall" = "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'";
      "dlogs" = "docker logs -f";
      "dexec" = "docker exec -it";
      "dstats" = "ctop";
      "dimages" = "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'";
      "lazy" = "lazydocker";
      
      # Container service management
      "containers-start" = "sudo systemctl start docker-compose-nas";
      "containers-stop" = "sudo systemctl stop docker-compose-nas";
      "containers-restart" = "sudo systemctl restart docker-compose-nas";
      "containers-status" = "sudo systemctl status docker-compose-nas";
      "containers-logs" = "sudo journalctl -u docker-compose-nas -f";
      
      # Compose management
      "compose-up" = "cd ${cfg.configPath}/compose && docker compose up -d";
      "compose-down" = "cd ${cfg.configPath}/compose && docker compose down";
      "compose-restart" = "cd ${cfg.configPath}/compose && docker compose restart";
      "compose-logs" = "cd ${cfg.configPath}/compose && docker compose logs -f";
      "compose-pull" = "cd ${cfg.configPath}/compose && docker compose pull";
      
      # Quick access to container data
      "cdcontainers" = "cd ${cfg.dataPath}/containers";
      "cdcompose" = "cd ${cfg.configPath}/compose";
      "cdmedia" = "cd ${cfg.services.media.mediaPath}";
      "cddownloads" = "cd ${cfg.services.downloads.downloadPath}";
      
      # Container maintenance
      "docker-cleanup" = "docker system prune -af";
      "docker-update" = "cd ${cfg.configPath}/compose && docker compose pull && docker compose up -d";
      "containers-backup" = "sudo systemctl start containers-backup";
    };
  };
}