# MOTD (Message of the Day) module for NixOS NAS
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.motd;
in

{
  options.motd = {
    enable = mkEnableOption "Server-style MOTD (Message of the Day)";
    
    updateInterval = mkOption {
      type = types.str;
      default = "5min";
      description = "How often to update the MOTD (systemd timer format)";
    };
    
    showOnLogin = mkOption {
      type = types.bool;
      default = true;
      description = "Show MOTD on interactive shell login";
    };
    
    serverName = mkOption {
      type = types.str;
      default = "NixOS NAS Server";
      description = "Server name to display in MOTD header";
    };
    
    enableColors = mkOption {
      type = types.bool;
      default = true;
      description = "Enable colored output in MOTD";
    };
    
    showWarnings = mkOption {
      type = types.bool;
      default = true;
      description = "Show system warnings (like drive expansion notices)";
    };
    
    extraCommands = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Command name to display";
          };
          description = mkOption {
            type = types.str;
            description = "Description of what the command does";
          };
        };
      });
      default = [
        { name = "storage-status"; description = "View detailed storage information"; }
        { name = "drive-health"; description = "Check all drive health status"; }
        { name = "list-nvme"; description = "List all NVMe drives"; }
        { name = "btop"; description = "System resource monitor"; }
        { name = "fastfetch"; description = "Detailed system information"; }
      ];
      description = "Additional commands to show in the quick commands section";
    };
  };

  config = mkIf cfg.enable {
    # Required packages for MOTD
    environment.systemPackages = with pkgs; [
      figlet     # ASCII art text
      lolcat     # Colorful output (optional)
    ];

    # Custom MOTD script
    environment.etc."motd-script" = {
      text = ''
        #!${pkgs.bash}/bin/bash
        
        ${optionalString cfg.enableColors ''
        # Colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        PURPLE='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[1;37m'
        GRAY='\033[0;37m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color
        ''} ${optionalString (!cfg.enableColors) ''
        # No colors mode
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        PURPLE=""
        CYAN=""
        WHITE=""
        GRAY=""
        BOLD=""
        NC=""
        ''}
        
        # Get system information
        HOSTNAME=$(hostname)
        KERNEL=$(uname -r)
        UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | awk '{print $3,$4}' | sed 's/,//')
        LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
        
        # Memory info
        MEMORY=$(free -h | awk '/^Mem:/ {printf "%s/%s (%.1f%%)", $3, $2, ($3/$2)*100}')
        
        # Disk usage for root
        ROOT_USAGE=$(df -h / | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
        
        # Storage info
        NVME_COUNT=$(ls /dev/nvme*n1 2>/dev/null | wc -l || echo "0")
        
        # Network info
        IP_ADDR=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "No connection")
        
        # Temperature (if available)
        TEMP=$(sensors 2>/dev/null | grep -i 'core 0' | awk '{print $3}' | head -1 || echo "N/A")
        
        # Services status
        SSH_STATUS=$(systemctl is-active sshd 2>/dev/null || echo "inactive")
        SAMBA_STATUS=$(systemctl is-active smbd 2>/dev/null || echo "inactive")
        STORAGE_STATUS=$(systemctl is-active storage-setup 2>/dev/null || echo "inactive")
        
        # Header with hostname
        echo ""
        echo -e "''${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗''${NC}"
        echo -e "''${CYAN}║''${NC}$(figlet -c -w 76 "$HOSTNAME" 2>/dev/null || echo "    $HOSTNAME    ")''${CYAN}║''${NC}"
        echo -e "''${CYAN}║''${WHITE}                           ${cfg.serverName}                        ''${CYAN}║''${NC}"
        echo -e "''${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝''${NC}"
        echo ""
        
        # System Information
        echo -e "''${BOLD}''${WHITE}System Information:''${NC}"
        echo -e "  ''${BLUE}●''${NC} Hostname      : ''${GREEN}$HOSTNAME''${NC}"
        echo -e "  ''${BLUE}●''${NC} Kernel        : ''${GREEN}$KERNEL''${NC}"
        echo -e "  ''${BLUE}●''${NC} Uptime        : ''${GREEN}$UPTIME''${NC}"
        echo -e "  ''${BLUE}●''${NC} Load Average  : ''${GREEN}$LOAD''${NC}"
        echo -e "  ''${BLUE}●''${NC} Memory Usage  : ''${GREEN}$MEMORY''${NC}"
        echo -e "  ''${BLUE}●''${NC} Root Usage    : ''${GREEN}$ROOT_USAGE''${NC}"
        echo -e "  ''${BLUE}●''${NC} Temperature   : ''${GREEN}$TEMP''${NC}"
        echo ""
        
        # Network Information
        echo -e "''${BOLD}''${WHITE}Network Information:''${NC}"
        echo -e "  ''${BLUE}●''${NC} IP Address    : ''${GREEN}$IP_ADDR''${NC}"
        echo -e "  ''${BLUE}●''${NC} SSH Port      : ''${GREEN}22''${NC}"
        echo -e "  ''${BLUE}●''${NC} Samba Ports   : ''${GREEN}139, 445''${NC}"
        echo ""
        
        # Storage Information
        echo -e "''${BOLD}''${WHITE}Storage Information:''${NC}"
        echo -e "  ''${BLUE}●''${NC} NVMe Drives   : ''${GREEN}$NVME_COUNT''${NC}/6 slots"
        
        # Show mounted drives
        if [ -d "/mnt" ]; then
          for drive in /mnt/drive*; do
            if mountpoint -q "$drive" 2>/dev/null; then
              drive_name=$(basename "$drive")
              drive_usage=$(df -h "$drive" 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
              echo -e "  ''${BLUE}●''${NC} $drive_name        : ''${GREEN}$drive_usage''${NC}"
            fi
          done
        fi
        
        # Show main data mount if available
        if mountpoint -q "/mnt/data" 2>/dev/null; then
          data_usage=$(df -h /mnt/data 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
          echo -e "  ''${BLUE}●''${NC} Main Data     : ''${GREEN}$data_usage''${NC}"
        fi
        echo ""
        
        # Services Status
        echo -e "''${BOLD}''${WHITE}Services Status:''${NC}"
        
        # SSH Status
        if [ "$SSH_STATUS" = "active" ]; then
          echo -e "  ''${GREEN}●''${NC} SSH Server    : ''${GREEN}Running''${NC}"
        else
          echo -e "  ''${RED}●''${NC} SSH Server    : ''${RED}Stopped''${NC}"
        fi
        
        # Samba Status
        if [ "$SAMBA_STATUS" = "active" ]; then
          echo -e "  ''${GREEN}●''${NC} Samba Server  : ''${GREEN}Running''${NC}"
        else
          echo -e "  ''${RED}●''${NC} Samba Server  : ''${RED}Stopped''${NC}"
        fi
        
        # Storage Status
        if [ "$STORAGE_STATUS" = "active" ]; then
          echo -e "  ''${GREEN}●''${NC} Storage Mgmt  : ''${GREEN}Active''${NC}"
        else
          echo -e "  ''${RED}●''${NC} Storage Mgmt  : ''${RED}Inactive''${NC}"
        fi
        echo ""
        
        # Quick Commands
        echo -e "''${BOLD}''${WHITE}Quick Commands:''${NC}"
        ${concatStringsSep "\n" (map (cmd: ''
        echo -e "  ''${YELLOW}●''${NC} ''${CYAN}${cmd.name}''${NC}${optionalString (stringLength cmd.name < 12) (concatStrings (genList (_: " ") (12 - stringLength cmd.name)))} - ${cmd.description}"
        '') cfg.extraCommands)}
        echo ""
        
        ${optionalString cfg.showWarnings ''
        # Warning messages
        if [ "$NVME_COUNT" -eq 1 ]; then
          echo -e "''${YELLOW}⚠ ''${NC} ''${YELLOW}Only 1 NVMe drive detected. 5 slots available for expansion.''${NC}"
          echo ""
        fi
        ''}
        
        # Footer
        echo -e "''${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
        echo -e "''${GRAY}Last updated: $(date)''${NC}"
        echo ""
      '';
      mode = "0755";
    };
    
    # SSH MOTD configuration
    services.openssh.extraConfig = mkAfter ''
      PrintMotd no
      PrintLastLog yes
    '';
    
    # Create MOTD update service
    systemd.services.motd-update = {
      description = "Update MOTD";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "update-motd" ''
          /etc/motd-script > /etc/motd.tmp && mv /etc/motd.tmp /etc/motd && chmod 644 /etc/motd
        ''}";
        User = "root";
      };
    };
    
    # Timer to update MOTD regularly
    systemd.timers.motd-update = {
      description = "Update MOTD timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30sec";
        OnUnitActiveSec = cfg.updateInterval;
        Persistent = true;
      };
    };

    # Ensure MOTD is created on boot
    systemd.services.motd-initial = {
      description = "Create initial MOTD";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "create-initial-motd" ''
          if [ ! -f /etc/motd ]; then
            /etc/motd-script > /etc/motd.tmp 2>/dev/null && mv /etc/motd.tmp /etc/motd && chmod 644 /etc/motd || true
          fi
        ''}";
        User = "root";
        RemainAfterExit = true;
      };
    };
    
    # Show MOTD on login for interactive shells
    environment.interactiveShellInit = mkIf cfg.showOnLogin ''
      # Show MOTD on login (only for interactive shells)
      if [[ $- == *i* ]] && [ -f /etc/motd ] && [ -r /etc/motd ]; then
        cat /etc/motd
      elif [[ $- == *i* ]] && [ -f /etc/motd-script ]; then
        # Fallback: show MOTD directly if file doesn't exist
        /etc/motd-script 2>/dev/null || echo "Welcome to NixOS NAS!"
      fi
    '';
  };
} 