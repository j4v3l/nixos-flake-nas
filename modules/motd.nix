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
      gawk       # GNU awk for text processing
      iproute2   # ip command
      procps     # free, uptime commands
      util-linux # df, hostname commands
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
        
        # Get system information with better error handling
        HOSTNAME=$(${pkgs.util-linux}/bin/hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "nixos")
        KERNEL=$(uname -r 2>/dev/null || echo "unknown")
        
        # Better uptime handling
        UPTIME=""
        if command -v ${pkgs.procps}/bin/uptime >/dev/null 2>&1; then
          # Try uptime -p first (human readable)
          UPTIME=$(${pkgs.procps}/bin/uptime -p 2>/dev/null | sed 's/up //')
          if [ -z "$UPTIME" ]; then
            # Fallback to regular uptime and parse it
            UPTIME=$(${pkgs.procps}/bin/uptime 2>/dev/null | sed 's/.*up \([^,]*\).*/\1/' | sed 's/^ *//')
          fi
        fi
        # If still empty, try /proc/uptime
        if [ -z "$UPTIME" ] && [ -f /proc/uptime ]; then
          UPTIME_SECONDS=$(${pkgs.gawk}/bin/awk '{print int($1)}' /proc/uptime 2>/dev/null)
          if [ -n "$UPTIME_SECONDS" ] && [ "$UPTIME_SECONDS" -gt 0 ]; then
            DAYS=$((UPTIME_SECONDS / 86400))
            HOURS=$(((UPTIME_SECONDS % 86400) / 3600))
            MINUTES=$(((UPTIME_SECONDS % 3600) / 60))
            if [ $DAYS -gt 0 ]; then
              UPTIME="$DAYS days, $HOURS hours, $MINUTES minutes"
            elif [ $HOURS -gt 0 ]; then
              UPTIME="$HOURS hours, $MINUTES minutes"
            else
              UPTIME="$MINUTES minutes"
            fi
          fi
        fi
        [ -z "$UPTIME" ] && UPTIME="unknown"
        
        # Load average
        LOAD=""
        if command -v ${pkgs.procps}/bin/uptime >/dev/null 2>&1; then
          LOAD=$(${pkgs.procps}/bin/uptime 2>/dev/null | grep -o 'load average:.*' | sed 's/load average: //')
        fi
        if [ -z "$LOAD" ] && [ -f /proc/loadavg ]; then
          LOAD=$(${pkgs.gawk}/bin/awk '{printf "%s, %s, %s", $1, $2, $3}' /proc/loadavg 2>/dev/null)
        fi
        [ -z "$LOAD" ] && LOAD="unknown"
        
        # Memory info - simplified and more reliable
        MEMORY=""
        if [ -f /proc/meminfo ]; then
          MEMORY=$(${pkgs.gawk}/bin/awk '
            /MemTotal:/ { total = $2 }
            /MemFree:/ { free = $2 }
            /Buffers:/ { buffers = $2 }
            /Cached:/ { cached = $2 }
            END { 
              if (total > 0) {
                used = total - free - buffers - cached
                printf "%.1fG/%.1fG (%.1f%%)", used/1024/1024, total/1024/1024, (used/total)*100
              }
            }' /proc/meminfo 2>/dev/null)
        fi
        if [ -z "$MEMORY" ] && command -v ${pkgs.procps}/bin/free >/dev/null 2>&1; then
          MEMORY=$(${pkgs.procps}/bin/free -h 2>/dev/null | ${pkgs.gawk}/bin/awk '/^Mem:/ {print $3"/"$2}')
        fi
        [ -z "$MEMORY" ] && MEMORY="unknown"
        
        # Disk usage for root - more reliable
        ROOT_USAGE=""
        if command -v df >/dev/null 2>&1; then
          ROOT_USAGE=$(df -h / 2>/dev/null | ${pkgs.gawk}/bin/awk 'NR==2 {print $3"/"$2" ("$5")"}')
        fi
        if [ -z "$ROOT_USAGE" ] && [ -f /proc/mounts ]; then
          # Alternative method using /proc/mounts and stat
          ROOT_DEV=$(${pkgs.gawk}/bin/awk '$2 == "/" {print $1; exit}' /proc/mounts 2>/dev/null)
          if [ -n "$ROOT_DEV" ]; then
            ROOT_USAGE=$(df -h "$ROOT_DEV" 2>/dev/null | ${pkgs.gawk}/bin/awk 'NR==2 {print $3"/"$2" ("$5")"}')
          fi
        fi
        [ -z "$ROOT_USAGE" ] && ROOT_USAGE="unknown"
        
        # Storage info
        NVME_COUNT=$(ls /dev/nvme*n1 2>/dev/null | wc -l || echo "0")
        
        # Network info - simplified and more reliable
        IP_ADDR=""
        
        # Method 1: Try ip route with better awk pattern
        if [ -z "$IP_ADDR" ] && command -v ${pkgs.iproute2}/bin/ip >/dev/null 2>&1; then
          IP_ADDR=$(${pkgs.iproute2}/bin/ip route get 1.1.1.1 2>/dev/null | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
        fi
        
        # Method 2: Try hostname -I
        if [ -z "$IP_ADDR" ] && command -v ${pkgs.util-linux}/bin/hostname >/dev/null 2>&1; then
          IP_ADDR=$(${pkgs.util-linux}/bin/hostname -I 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}')
        fi
        
        # Method 3: Parse ip addr show
        if [ -z "$IP_ADDR" ] && command -v ${pkgs.iproute2}/bin/ip >/dev/null 2>&1; then
          IP_ADDR=$(${pkgs.iproute2}/bin/ip addr show 2>/dev/null | ${pkgs.gawk}/bin/awk '/inet [0-9]/ && !/127\.0\.0\.1/ {gsub(/\/.*/, "", $2); print $2; exit}')
        fi
        
        # Method 4: Check common interface names
        if [ -z "$IP_ADDR" ]; then
          for iface in eth0 enp0s3 wlan0 br0; do
            if [ -f "/sys/class/net/$iface/operstate" ]; then
              STATE=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)
              if [ "$STATE" = "up" ]; then
                IP_ADDR=$(${pkgs.iproute2}/bin/ip addr show "$iface" 2>/dev/null | ${pkgs.gawk}/bin/awk '/inet [0-9]/ {gsub(/\/.*/, "", $2); print $2; exit}')
                [ -n "$IP_ADDR" ] && break
              fi
            fi
          done
        fi
        
        # Default fallback
        [ -z "$IP_ADDR" ] && IP_ADDR="No connection"
        
        # Temperature (if available) - check multiple sources
        TEMP="N/A"
        if command -v sensors >/dev/null 2>&1; then
          TEMP=$(sensors 2>/dev/null | grep -i 'core 0\|package id 0' | ${pkgs.gawk}/bin/awk '{print $3}' | head -1 | grep -o '[0-9]*\.[0-9]*°C' || echo "N/A")
        fi
        if [ "$TEMP" = "N/A" ] && [ -f /sys/class/thermal/thermal_zone0/temp ]; then
          TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
          if [ -n "$TEMP_RAW" ] && [ "$TEMP_RAW" -gt 0 ]; then
            TEMP="$((TEMP_RAW/1000))°C"
          fi
        fi
        
        # Services status
        SSH_STATUS=$(systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || echo "inactive")
        SAMBA_STATUS=$(systemctl is-active samba-smbd 2>/dev/null || systemctl is-active smbd 2>/dev/null || systemctl is-active samba 2>/dev/null || echo "inactive")
        STORAGE_STATUS=$(systemctl is-active storage-setup 2>/dev/null || echo "inactive")
        
        # Header with hostname - improved banner generation
        echo ""
        echo -e "''${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗''${NC}"
        
        # Generate hostname banner - handle figlet failure gracefully
        if command -v ${pkgs.figlet}/bin/figlet >/dev/null 2>&1; then
          FIGLET_OUTPUT=$(${pkgs.figlet}/bin/figlet -c -w 76 "$HOSTNAME" 2>/dev/null)
          if [ $? -eq 0 ] && [ -n "$FIGLET_OUTPUT" ]; then
            echo "$FIGLET_OUTPUT" | while IFS= read -r line; do
              # Pad line to fit in box (76 chars)
              line_length=''${#line}
              if [ $line_length -lt 76 ]; then
                padding=$(( (76 - line_length) / 2 ))
                left_pad=$(printf "%*s" $padding "")
                right_pad=$(printf "%*s" $((76 - line_length - padding)) "")
                echo -e "''${CYAN}║''${NC}$left_pad$line$right_pad''${CYAN}║''${NC}"
              else
                echo -e "''${CYAN}║''${NC}$line''${CYAN}║''${NC}"
              fi
            done
          else
            # Fallback if figlet fails
            hostname_length=''${#HOSTNAME}
            padding=$(( (76 - hostname_length) / 2 ))
            left_pad=$(printf "%*s" $padding "")
            right_pad=$(printf "%*s" $((76 - hostname_length - padding)) "")
            echo -e "''${CYAN}║''${NC}$left_pad''${BOLD}''${WHITE}$HOSTNAME''${NC}$right_pad''${CYAN}║''${NC}"
          fi
        else
          # No figlet available
          hostname_length=''${#HOSTNAME}
          padding=$(( (76 - hostname_length) / 2 ))
          left_pad=$(printf "%*s" $padding "")
          right_pad=$(printf "%*s" $((76 - hostname_length - padding)) "")
          echo -e "''${CYAN}║''${NC}$left_pad''${BOLD}''${WHITE}$HOSTNAME''${NC}$right_pad''${CYAN}║''${NC}"
        fi
        
        # Server name line
        server_name="${cfg.serverName}"
        server_length=''${#server_name}
        server_padding=$(( (76 - server_length) / 2 ))
        server_left_pad=$(printf "%*s" $server_padding "")
        server_right_pad=$(printf "%*s" $((76 - server_length - server_padding)) "")
        echo -e "''${CYAN}║''${WHITE}$server_left_pad$server_name$server_right_pad''${CYAN}║''${NC}"
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
            if [ -d "$drive" ] && mountpoint -q "$drive" 2>/dev/null; then
              drive_name=$(basename "$drive")
              drive_usage=$(df -h "$drive" 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
              if [ -n "$drive_usage" ]; then
                echo -e "  ''${BLUE}●''${NC} $drive_name        : ''${GREEN}$drive_usage''${NC}"
              fi
            fi
          done
        fi
        
        # Show main data mount if available
        if mountpoint -q "/mnt/data" 2>/dev/null; then
          data_usage=$(df -h /mnt/data 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
          if [ -n "$data_usage" ]; then
            echo -e "  ''${BLUE}●''${NC} Main Data     : ''${GREEN}$data_usage''${NC}"
          fi
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