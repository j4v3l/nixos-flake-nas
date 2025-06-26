# Atuin shell history sync module
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.atuin;
in
{
  options.atuin = {
    enable = mkEnableOption "Atuin shell history sync";

    package = mkOption {
      type = types.package;
      default = pkgs.atuin;
      description = "The atuin package to use";
    };

    # System-wide daemon configuration
    daemon = {
      enable = mkEnableOption "Atuin daemon for system-wide shell history sync";
      
      user = mkOption {
        type = types.str;
        default = "jager";
        description = "User to run the Atuin daemon as";
      };

      logLevel = mkOption {
        type = types.enum [ "trace" "debug" "info" "warn" "error" ];
        default = "info";
        description = "Log level for the Atuin daemon";
      };

      syncFrequency = mkOption {
        type = types.str;
        default = "15m";
        description = "How often to sync with the server (e.g., 15m, 1h, 30s)";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open firewall ports for Atuin server mode";
      };
    };

    # Server configuration (for self-hosting)
    server = {
      enable = mkEnableOption "Atuin sync server";
      
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Host to bind the Atuin server to";
      };

      port = mkOption {
        type = types.port;
        default = 8888;
        description = "Port for the Atuin sync server";
      };

      databaseUrl = mkOption {
        type = types.str;
        default = "sqlite:///var/lib/atuin/atuin.db";
        description = "Database URL for Atuin server";
      };

      registrationDisabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to disable new user registration";
      };

      maxHistoryLength = mkOption {
        type = types.int;
        default = 8192;
        description = "Maximum length of each history entry";
      };

      maxRecordSize = mkOption {
        type = types.int;
        default = 1048576; # 1MB
        description = "Maximum size of each record in bytes";
      };

      pageSize = mkOption {
        type = types.int;
        default = 1100;
        description = "Default page size for queries";
      };
    };

    # Global settings that affect all users
    globalSettings = mkOption {
      type = types.attrs;
      default = {
        dialect = "us";
        auto_sync = true;
        update_check = false;
        sync_frequency = cfg.daemon.syncFrequency;
        network_connect_timeout = 60;
        network_timeout = 60;
      };
      description = "Global Atuin settings applied system-wide";
    };

    # Default sync server configuration
    syncServer = mkOption {
      type = types.str;
      default = "https://api.atuin.sh";
      description = "Default sync server URL for users";
    };
  };

  config = mkIf cfg.enable {
    # Add atuin package to system packages
    environment.systemPackages = [ cfg.package ];

    # Configure system-wide daemon if enabled
    systemd.user.services.atuin-daemon = mkIf cfg.daemon.enable {
      description = "Atuin shell history sync daemon";
      wantedBy = [ "default.target" ];
      after = [ "network.target" ];
      
      environment = {
        ATUIN_LOG = cfg.daemon.logLevel;
        XDG_RUNTIME_DIR = "/run/user/%i";
      };
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/atuin daemon";
        Restart = "on-failure";
        RestartSec = "5s";
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false; # Need access to user home for config
        ReadWritePaths = [ "/run/user/%i" ];
      };
    };

    # Configure Atuin server if enabled
    systemd.services.atuin-server = mkIf cfg.server.enable {
      description = "Atuin sync server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      environment = {
        ATUIN_HOST = cfg.server.host;
        ATUIN_PORT = toString cfg.server.port;
        ATUIN_DB_URI = cfg.server.databaseUrl;
        ATUIN_REGISTRATION_DISABLED = if cfg.server.registrationDisabled then "true" else "false";
        ATUIN_MAX_HISTORY_LENGTH = toString cfg.server.maxHistoryLength;
        ATUIN_MAX_RECORD_SIZE = toString cfg.server.maxRecordSize;
        ATUIN_PAGE_SIZE = toString cfg.server.pageSize;
      };
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/atuin server start";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "atuin";
        Group = "atuin";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/atuin" ];
        
        # Network security
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        
        # Capabilities
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        
        # Namespaces
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        
        # System calls
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
      };
      
      preStart = ''
        # Create data directory
        mkdir -p /var/lib/atuin
        chown atuin:atuin /var/lib/atuin
        chmod 750 /var/lib/atuin
        
        # Initialize database if needed
        if [ ! -f /var/lib/atuin/atuin.db ]; then
          cd /var/lib/atuin
          ${cfg.package}/bin/atuin server init
          chown atuin:atuin /var/lib/atuin/atuin.db
        fi
      '';
    };

    # Create atuin user for server
    users.users.atuin = mkIf cfg.server.enable {
      isSystemUser = true;
      group = "atuin";
      home = "/var/lib/atuin";
      createHome = true;
      description = "Atuin sync server user";
    };

    users.groups.atuin = mkIf cfg.server.enable {};

    # Open firewall ports if requested
    networking.firewall.allowedTCPPorts = mkIf (cfg.server.enable && cfg.daemon.openFirewall) [
      cfg.server.port
    ];

    # Create global configuration directory and files
    environment.etc."atuin/config.toml" = {
      text = ''
        # Global Atuin configuration
        dialect = "${cfg.globalSettings.dialect or "us"}"
        auto_sync = ${if cfg.globalSettings.auto_sync or true then "true" else "false"}
        update_check = ${if cfg.globalSettings.update_check or false then "true" else "false"}
        sync_frequency = "${cfg.globalSettings.sync_frequency or cfg.daemon.syncFrequency}"
        network_connect_timeout = ${toString (cfg.globalSettings.network_connect_timeout or 60)}
        network_timeout = ${toString (cfg.globalSettings.network_timeout or 60)}
        sync_address = "${cfg.syncServer}"

        [daemon]
        enabled = true
        systemd_socket = true
      '';
      mode = "0644";
    };

    # Shell integration hints for users
    environment.interactiveShellInit = ''
      # Atuin is available system-wide
      # Users can enable it in their shell configs with:
      # - programs.atuin.enable = true; (in Home Manager)
      # - eval "$(atuin init bash)" (manual setup)
      
      # Global Atuin configuration is available at /etc/atuin/config.toml
      export ATUIN_CONFIG_DIR="/etc/atuin"
    '';

    # Add helpful aliases to the base system
    environment.shellAliases = {
      "atuin-status" = "systemctl --user status atuin-daemon";
      "atuin-restart" = "systemctl --user restart atuin-daemon";
      "atuin-logs" = "journalctl --user -u atuin-daemon -f";
      "atuin-sync" = "${cfg.package}/bin/atuin sync";
      "atuin-search" = "${cfg.package}/bin/atuin search";
      "atuin-stats" = "${cfg.package}/bin/atuin stats";
    };

    # Ensure proper permissions and directories
    system.activationScripts.atuin = mkIf cfg.daemon.enable ''
      # Ensure atuin data directories exist for all users
      for user_home in /home/*; do
        if [ -d "$user_home" ]; then
          user=$(basename "$user_home")
          atuin_dir="$user_home/.local/share/atuin"
          config_dir="$user_home/.config/atuin"
          
          # Create directories if they don't exist
          mkdir -p "$atuin_dir" "$config_dir"
          chown "$user:users" "$atuin_dir" "$config_dir" 2>/dev/null || true
          chmod 755 "$atuin_dir" "$config_dir" 2>/dev/null || true
        fi
      done
    '';
  };
} 