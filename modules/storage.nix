{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.storage;
in

{
  options.storage = {
    enable = mkEnableOption "Advanced storage management for Beelink ME mini 6-slot NAS";
    
    autoDetect = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically detect and mount NVMe drives";
    };
    
    raidLevel = mkOption {
      type = types.nullOr (types.enum [ "0" "1" "5" "6" "10" ]);
      default = null;
      description = "RAID level to configure (null for individual drives)";
    };
    
    dataPath = mkOption {
      type = types.str;
      default = "/mnt/data";
      description = "Primary data mount point";
    };
    
    drives = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          device = mkOption {
            type = types.str;
            description = "Device path (e.g., /dev/nvme0n1)";
          };
          
          mountPoint = mkOption {
            type = types.str;
            description = "Mount point for this drive";
          };
          
          fsType = mkOption {
            type = types.str;
            default = "ext4";
            description = "Filesystem type";
          };
          
          autoFormat = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically format drive if unformatted";
          };
          
          label = mkOption {
            type = types.str;
            description = "Filesystem label";
          };
        };
      });
      default = {
        drive1 = {
          device = "/dev/nvme1n1";
          mountPoint = "/mnt/drive1";
          label = "drive1";
          autoFormat = false;
        };
        drive2 = {
          device = "/dev/nvme2n1";
          mountPoint = "/mnt/drive2";
          label = "drive2";
          autoFormat = false;
        };
        drive3 = {
          device = "/dev/nvme3n1";
          mountPoint = "/mnt/drive3";
          label = "drive3";
          autoFormat = false;
        };
        drive4 = {
          device = "/dev/nvme4n1";
          mountPoint = "/mnt/drive4";
          label = "drive4";
          autoFormat = false;
        };
        drive5 = {
          device = "/dev/nvme5n1";
          mountPoint = "/mnt/drive5";
          label = "drive5";
          autoFormat = false;
        };
      };
      description = "Configuration for individual drives (slots 2-6, slot 1 is system)";
    };
  };

  config = mkIf cfg.enable {
    # Essential storage packages
    environment.systemPackages = with pkgs; [
      # Storage management
      parted        # Disk partitioning
      gptfdisk      # GPT partition management
      smartmontools # Drive health monitoring
      hdparm        # Hard drive parameter management
      nvme-cli      # NVMe drive management
      lvm2          # Logical volume management
      mdadm         # Software RAID management
      
      # Filesystem tools
      e2fsprogs     # ext2/3/4 filesystem utilities
      xfsprogs      # XFS filesystem utilities
      btrfs-progs   # Btrfs filesystem utilities
      dosfstools    # FAT filesystem utilities
      ntfs3g        # NTFS filesystem support
      
      # Monitoring and diagnostics
      iotop         # I/O monitoring
      sysstat       # Contains iostat for I/O statistics
      lsof          # List open files
      fio           # Flexible I/O tester
    ];

    # Kernel modules for NVMe and storage management
    boot.initrd.availableKernelModules = [
      "nvme"        # NVMe support
      "ahci"        # SATA support
      "xhci_pci"    # USB 3.0 support
      "usbhid"      # USB HID support
      "usb_storage" # USB storage support
      "sd_mod"      # SCSI disk support
    ];

    # Additional kernel modules
    boot.kernelModules = [
      "nvme"        # NVMe driver
      "nvme-core"   # NVMe core
    ];

    # Filesystems configuration for detected drives
    # Note: Only configure filesystems if they exist
    # Individual drive mounts will be handled by the storage-setup service

    # Services for storage management
    systemd.services = {
      # Drive detection and setup service
      storage-setup = {
        description = "Storage setup and drive detection";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutSec = 300;
        };
        script = ''
          #!/bin/bash
          set -euo pipefail

          echo "=== Beelink ME mini Storage Detection ==="
          
          # Create mount directories
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: drive: ''
            mkdir -p ${drive.mountPoint}
            chown jager:users ${drive.mountPoint}
            chmod 755 ${drive.mountPoint}
          '') cfg.drives)}
          
          mkdir -p ${cfg.dataPath}
          chown jager:users ${cfg.dataPath}
          chmod 755 ${cfg.dataPath}

          # Detect NVMe drives
          echo "Detecting NVMe drives..."
          for nvme_dev in /dev/nvme*n1; do
            if [[ -e "$nvme_dev" ]]; then
              echo "Found NVMe device: $nvme_dev"
              
              # Get drive info
              if command -v nvme >/dev/null 2>&1; then
                echo "Drive information:"
                nvme id-ctrl "$nvme_dev" 2>/dev/null | head -20 || echo "Could not get detailed info"
              fi
              
              # Check if drive is partitioned
              if ! blkid "$nvme_dev" >/dev/null 2>&1; then
                echo "Drive $nvme_dev appears unformatted"
                # Note: Auto-formatting disabled by default for safety
                # Set autoFormat = true in drive config to enable
              else
                echo "Drive $nvme_dev is formatted:"
                blkid "$nvme_dev"
              fi
            fi
          done

          # SMART health check for all NVMe drives
          echo "=== NVMe Drive Health Check ==="
          for nvme_dev in /dev/nvme*n1; do
            if [[ -e "$nvme_dev" ]]; then
              echo "Health check for $nvme_dev:"
              if command -v smartctl >/dev/null 2>&1; then
                smartctl -H "$nvme_dev" || echo "SMART check failed for $nvme_dev"
              fi
            fi
          done

          # Try to mount drives if they exist
          echo "=== Attempting to mount available drives ==="
          for label in data drive1 drive2 drive3 drive4 drive5; do
            if [ -e "/dev/disk/by-label/$label" ]; then
              mount_point=""
              case "$label" in
                data) mount_point="${cfg.dataPath}" ;;
                drive1) mount_point="/mnt/drive1" ;;
                drive2) mount_point="/mnt/drive2" ;;
                drive3) mount_point="/mnt/drive3" ;;
                drive4) mount_point="/mnt/drive4" ;;
                drive5) mount_point="/mnt/drive5" ;;
              esac
              
              if [ -n "$mount_point" ]; then
                echo "Mounting $label to $mount_point"
                mkdir -p "$mount_point"
                if ! mountpoint -q "$mount_point"; then
                  mount "/dev/disk/by-label/$label" "$mount_point" || echo "Failed to mount $label"
                else
                  echo "$mount_point already mounted"
                fi
              fi
            else
              echo "Drive with label '$label' not found"
            fi
          done

          # Create basic data structure if main data mount is available and empty
          if mountpoint -q ${cfg.dataPath} && [ -z "$(ls -A ${cfg.dataPath} 2>/dev/null)" ]; then
            echo "Creating basic data structure in ${cfg.dataPath}"
            mkdir -p ${cfg.dataPath}/{shared,media,backups,documents}
            chown -R jager:users ${cfg.dataPath}
            chmod -R 755 ${cfg.dataPath}
          fi

          echo "=== Storage Setup Complete ==="
        '';
      };

      # Storage monitoring service
      storage-monitor = {
        description = "Storage health monitoring";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = ''
          #!/bin/bash
          # Monitor drive health and log warnings
          
          for nvme_dev in /dev/nvme*n1; do
            if [[ -e "$nvme_dev" ]]; then
              # Check SMART status
              if ! smartctl -H "$nvme_dev" | grep -q "PASSED"; then
                echo "WARNING: Drive $nvme_dev may have health issues" | systemd-cat -t storage-monitor -p warning
              fi
              
              # Check temperature (if supported)
              temp=$(smartctl -A "$nvme_dev" | grep -i temperature | head -1 | awk '{print $10}' || echo "")
              if [[ -n "$temp" && "$temp" -gt 70 ]]; then
                echo "WARNING: Drive $nvme_dev temperature is high: ''${temp}°C" | systemd-cat -t storage-monitor -p warning
              fi
            fi
          done
        '';
      };
    };

    # Timer for regular storage monitoring
    systemd.timers.storage-monitor = {
      description = "Storage health monitoring timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    # Tmpfiles rules for mount points
    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0755 jager users -"
    ] ++ (lib.mapAttrsToList (name: drive: 
      "d ${drive.mountPoint} 0755 jager users -"
    ) cfg.drives);

    # Kernel parameters for better NVMe performance
    boot.kernelParams = [
      # NVMe optimizations
      "nvme_core.default_ps_max_latency_us=0"  # Disable power saving for performance
      "nvme.poll_queues=2"                     # Enable polling queues for lower latency
    ];

    # I/O scheduler optimizations for NVMe
    services.udev.extraRules = ''
      # Set I/O scheduler for NVMe drives
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
      
      # Set read-ahead for NVMe drives
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="128"
      
      # Set queue depth for NVMe drives
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="128"
    '';

    # Enable RAID support if configured
    boot.swraid = mkIf (cfg.raidLevel != null) {
      enable = true;
      mdadmConf = ''
        # mdadm.conf for Beelink ME mini NAS
        DEVICE partitions
        ARRAY /dev/md0 level=raid${cfg.raidLevel} num-devices=${toString (length (attrNames cfg.drives))}
      '';
    };

    # Additional system settings for storage performance
    boot.kernel.sysctl = {
      # Virtual memory settings for better I/O performance
      "vm.dirty_ratio" = 15;                    # Percentage of system memory for dirty pages
      "vm.dirty_background_ratio" = 5;          # Background writeback threshold
      "vm.dirty_expire_centisecs" = 12000;      # Time before dirty pages are written (2 minutes)
      "vm.dirty_writeback_centisecs" = 1500;    # Writeback daemon wakeup interval (15 seconds)  
      "vm.vfs_cache_pressure" = 50;             # Prefer inode/dentry cache over page cache
      
      # Network buffer sizes for better NAS performance
      "net.core.rmem_max" = 134217728;          # 128MB receive buffer
      "net.core.wmem_max" = 134217728;          # 128MB send buffer
      "net.core.netdev_max_backlog" = 5000;    # Network device backlog
    };
  };
} 