{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nvmeManager;
  
  # Helper function to generate drive commands
  driveCommand = name: cmd: pkgs.writeShellScriptBin name ''
    #!/bin/bash
    set -euo pipefail
    
    # Source common functions
    source /etc/nixos/nvme-utils.sh
    
    ${cmd}
  '';
  
  # Management scripts for each operation
  nvmeScripts = {
    # List all NVMe drives with detailed information
    nvme-list = driveCommand "nvme-list" ''
      echo "=== NVMe Drive Inventory ==="
      echo
      
      for i in {0..5}; do
        device="/dev/nvme''${i}n1"
        echo "Slot $((i+1)): $device"
        
        if [[ -e "$device" ]]; then
          # Get basic info using multiple methods
          model=""
          serial=""
          
          # Try nvme-cli first
          if command -v nvme >/dev/null 2>&1; then
            model=$(nvme id-ctrl "$device" 2>/dev/null | grep -E "^mn\s*:" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "")
            serial=$(nvme id-ctrl "$device" 2>/dev/null | grep -E "^sn\s*:" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "")
          fi
          
          # Fallback to smartctl if nvme-cli fails
          if [[ -z "$model" ]] && command -v smartctl >/dev/null 2>&1; then
            model=$(smartctl -i "$device" 2>/dev/null | grep "Device Model" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "")
            serial=$(smartctl -i "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "")
          fi
          
          # Fallback to lsblk model info
          if [[ -z "$model" ]]; then
            model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown Model")
          fi
          
          # Get size
          size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 | numfmt --to=iec-i || echo "Unknown Size")
          
          # Clean up empty values
          [[ -z "$model" ]] && model="Unknown Model"
          [[ -z "$serial" ]] && serial="Unknown Serial"
          
          echo "  ✓ Present: $model ($serial) - $size"
          
                     # Check for formatted partitions (check both whole disk and partitions)
           formatted=false
           fs_info=""
           label=""
           mount_info=""
           
           # Check if device has partitions
           partitions=($(ls "''${device}p"* "''${device}"[0-9]* 2>/dev/null || true))
           
           if [[ ''${#partitions[@]} -gt 0 ]]; then
                           # Device has partitions - show summary
              formatted=true
              part_types=()
              mount_points=()
              
              for part in "''${partitions[@]}"; do
                if [[ -e "$part" ]]; then
                  part_fs=$(lsblk -n -o FSTYPE "$part" 2>/dev/null | head -1 | tr -d ' ')
                  part_label=$(lsblk -n -o LABEL "$part" 2>/dev/null | head -1 | tr -d ' ')
                  part_mount=$(findmnt -n -o TARGET "$part" 2>/dev/null || echo "")
                 
                 if [[ -n "$part_fs" ]]; then
                   part_types+=("$part_fs")
                 fi
                 
                 if [[ -n "$part_mount" ]]; then
                   if [[ "$part_mount" == "/" ]]; then
                     mount_points=("/ (root)" "''${mount_points[@]}")  # Put root first
                   else
                     mount_points+=("$part_mount")
                   fi
                 fi
                 
                 # Use the label from the root partition if available
                 if [[ "$part_mount" == "/" ]] && [[ -n "$part_label" ]]; then
                   label="$part_label"
                 fi
               fi
             done
             
                           # Create filesystem summary
              if [[ ''${#part_types[@]} -gt 0 ]]; then
                # Remove duplicates and create summary
                unique_types=($(printf "%s\n" "''${part_types[@]}" | sort -u | tr '\n' ' '))
               if [[ ''${#unique_types[@]} -eq 1 ]]; then
                 fs_info="''${unique_types[0]}"
               else
                 fs_info="Multi ($(IFS=', '; echo "''${unique_types[*]}"))"
               fi
             else
               fs_info="Partitioned"
             fi
             
             # Create mount summary
             if [[ ''${#mount_points[@]} -gt 0 ]]; then
               if [[ ''${#mount_points[@]} -eq 1 ]]; then
                 mount_info="''${mount_points[0]}"
               else
                 mount_info="Multiple ($(IFS=', '; echo "''${mount_points[*]}"))"
               fi
             else
               mount_info="Not mounted"
             fi
                       else
              # Check whole disk (no partitions)
              fs_info=$(lsblk -n -o FSTYPE "$device" 2>/dev/null | head -1 | tr -d ' ')
              if [[ -n "$fs_info" ]]; then
                label=$(lsblk -n -o LABEL "$device" 2>/dev/null | head -1 | tr -d ' ')
                mount_info=$(findmnt -n -o TARGET "$device" 2>/dev/null || echo "Not mounted")
                formatted=true
              fi
            fi
           
           if $formatted; then
             echo "  📁 Formatted: ''${fs_info:-Unknown FS}"
             echo "  🏷️  Label: ''${label:-No label}"
           else
             echo "  ❌ Unformatted"
           fi
           
           echo "  📍 Mount: ''${mount_info:-Not mounted}"
          
          # Health status using multiple methods
          health_status="Unknown"
          health_detail=""
          
          # Try nvme smart-log first (needs sudo)
          if command -v nvme >/dev/null 2>&1; then
            critical=$(sudo nvme smart-log "$device" 2>/dev/null | grep "critical_warning" | awk '{print $3}' || echo "")
            if [[ "$critical" == "0" ]]; then
              health_status="Good"
            elif [[ -n "$critical" && "$critical" != "0" ]]; then
              health_status="Warning"
              health_detail="(critical: $critical)"
            fi
          fi
          
          # Fallback to smartctl (needs sudo)
          if [[ "$health_status" == "Unknown" ]] && command -v smartctl >/dev/null 2>&1; then
            smart_health=$(sudo smartctl -H "$device" 2>/dev/null | grep -i "overall-health" | awk '{print $6}' || echo "")
            if [[ "$smart_health" == "PASSED" ]]; then
              health_status="Good"
            elif [[ -n "$smart_health" ]]; then
              health_status="$smart_health"
            fi
          fi
          
          # Display health with appropriate icon
          if [[ "$health_status" == "Good" ]]; then
            echo "  ❤️  Health: Good"
          else
            echo "  ⚠️  Health: $health_status $health_detail"
          fi
          
          # Temperature
          temp=""
          temp_unit="°C"
          
          # Try nvme-cli first (needs sudo)
          if command -v nvme >/dev/null 2>&1; then
            # Parse temperature from nvme output (e.g., "107 °F (315 K)")
            temp_line=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 || echo "")
            if [[ -n "$temp_line" ]]; then
              # Extract Celsius from Kelvin value in parentheses
              kelvin=$(echo "$temp_line" | grep -o '([0-9]* K)' | sed 's/[^0-9]//g')
              if [[ -n "$kelvin" && "$kelvin" -gt 0 ]]; then
                temp=$((kelvin - 273))  # Convert Kelvin to Celsius
              fi
            fi
          fi
          
          # Fallback to smartctl (needs sudo)
          if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
            temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
          fi
          
          if [[ -n "$temp" && "$temp" != "0" ]]; then
            if [[ "$temp" -lt 60 ]]; then
              echo "  🌡️  Temp: ''${temp}''${temp_unit}"
            elif [[ "$temp" -lt 80 ]]; then
              echo "  🌡️  Temp: ''${temp}''${temp_unit} (Warm)"
            else
              echo "  🔥 Temp: ''${temp}''${temp_unit} (HOT!)"
            fi
          fi
        else
          echo "  ❌ Empty slot"
        fi
        echo
      done
    '';
    
    # Format a drive with options
    nvme-format = driveCommand "nvme-format" ''
      if [[ $# -lt 2 ]]; then
        echo "Usage: nvme-format <slot> <filesystem> [label]"
        echo "Slots: 1-6 (slot 1 is typically system drive)"
        echo "Filesystems: ext4, xfs, btrfs, ntfs"
        echo "Example: nvme-format 2 ext4 data"
        exit 1  
      fi
      
      slot="$1"
      filesystem="$2"
      label="''${3:-drive$slot}"
      
      if [[ "$slot" -lt 1 || "$slot" -gt 6 ]]; then
        echo "Error: Slot must be between 1-6"
        exit 1
      fi
      
      device="/dev/nvme$((slot-1))n1"
      
      if [[ ! -e "$device" ]]; then
        echo "Error: No drive found in slot $slot ($device)"
        exit 1
      fi
      
      echo "WARNING: This will destroy all data on $device (slot $slot)"
      echo "Drive info:"
      lsblk "$device"
      echo
      read -p "Are you sure? Type 'yes' to continue: " confirm
      
      if [[ "$confirm" != "yes" ]]; then
        echo "Operation cancelled"
        exit 0
      fi
      
      echo "Formatting $device with $filesystem..."
      
      # Unmount if mounted
      if mountpoint -q "$device" 2>/dev/null; then
        echo "Unmounting $device..."
        umount "$device"
      fi
      
      # Create GPT partition table
      echo "Creating partition table..."
      parted -s "$device" mklabel gpt
      parted -s "$device" mkpart primary 0% 100%
      
      # Wait for partition to appear
      sleep 2
      partition="''${device}p1"
      
      # Format with chosen filesystem
      echo "Creating $filesystem filesystem with label '$label'..."
      case "$filesystem" in
        ext4)
          mkfs.ext4 -F -L "$label" "$partition"
          ;;
        xfs)
          mkfs.xfs -f -L "$label" "$partition"
          ;;
        btrfs)
          mkfs.btrfs -f -L "$label" "$partition"
          ;;
        ntfs)
          mkfs.ntfs -f -L "$label" "$partition"
          ;;
        *)
          echo "Error: Unsupported filesystem '$filesystem'"
          exit 1
          ;;
      esac
      
      echo "✓ Drive formatted successfully!"
      echo "Device: $device"
      echo "Filesystem: $filesystem"
      echo "Label: $label"
      echo "You can now mount it with: sudo mount LABEL=$label /mnt/your-mount-point"
    '';
    
    # Clone one drive to another
    nvme-clone = driveCommand "nvme-clone" ''
      if [[ $# -ne 2 ]]; then
        echo "Usage: nvme-clone <source-slot> <destination-slot>"
        echo "Example: nvme-clone 2 3  # Clone slot 2 to slot 3"
        exit 1
      fi
      
      src_slot="$1"
      dst_slot="$2"
      
      if [[ "$src_slot" -lt 1 || "$src_slot" -gt 6 || "$dst_slot" -lt 1 || "$dst_slot" -gt 6 ]]; then
        echo "Error: Slots must be between 1-6"
        exit 1
      fi
      
      if [[ "$src_slot" == "$dst_slot" ]]; then
        echo "Error: Source and destination slots cannot be the same"
        exit 1
      fi
      
      src_device="/dev/nvme$((src_slot-1))n1"
      dst_device="/dev/nvme$((dst_slot-1))n1"
      
      if [[ ! -e "$src_device" ]]; then
        echo "Error: No source drive found in slot $src_slot ($src_device)"
        exit 1
      fi
      
      if [[ ! -e "$dst_device" ]]; then
        echo "Error: No destination drive found in slot $dst_slot ($dst_device)"
        exit 1
      fi
      
      echo "WARNING: This will completely overwrite the destination drive!"
      echo "Source: Slot $src_slot ($src_device)"
      lsblk "$src_device"
      echo
      echo "Destination: Slot $dst_slot ($dst_device)"
      lsblk "$dst_device"
      echo
      read -p "Are you sure? Type 'yes' to continue: " confirm
      
      if [[ "$confirm" != "yes" ]]; then
        echo "Operation cancelled"
        exit 0
      fi
      
      # Unmount both drives if mounted
      for device in "$src_device" "$dst_device"; do
        if mountpoint -q "$device" 2>/dev/null; then
          echo "Unmounting $device..."
          umount "$device"
        fi
      done
      
      echo "Starting clone operation..."
      echo "This may take a while depending on drive size..."
      
      # Use dd with progress monitoring
      if command -v pv >/dev/null; then
        # Get source size
        src_size=$(blockdev --getsize64 "$src_device")
        echo "Cloning $(numfmt --to=iec-i "$src_size") of data..."
        dd if="$src_device" | pv -s "$src_size" | dd of="$dst_device" bs=64M
      else
        dd if="$src_device" of="$dst_device" bs=64M status=progress
      fi
      
      # Force partition table re-read
      partprobe "$dst_device"
      
      echo "✓ Clone operation completed successfully!"
      echo "Source: $src_device (slot $src_slot)"
      echo "Destination: $dst_device (slot $dst_slot)"
    '';
    
    # Health check for all drives
    nvme-health = driveCommand "nvme-health" ''
      echo "=== NVMe Drive Health Report ==="
      echo "Generated: $(date)"
      echo
      
      for i in {0..5}; do
        device="/dev/nvme''${i}n1"
        slot=$((i+1))
        
        if [[ -e "$device" ]]; then
          echo "Slot $slot ($device):"
          
          # SMART overall health
          health=$(sudo smartctl -H "$device" 2>/dev/null | grep "overall-health" | awk '{print $6}' || echo "UNKNOWN")
          if [[ "$health" == "PASSED" ]]; then
            echo "  ✅ Overall Health: PASSED"
          else
            echo "  ❌ Overall Health: $health"
          fi
          
          # NVMe specific health
          critical=$(sudo nvme smart-log "$device" 2>/dev/null | grep "critical_warning" | awk '{print $3}' || echo "N/A")
          if [[ "$critical" == "0" ]]; then
            echo "  ✅ Critical Warning: None"
          else
            echo "  ⚠️  Critical Warning: $critical"
          fi
          
          # Temperature (convert from Kelvin to Celsius)
          temp_line=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 || echo "")
          if [[ -n "$temp_line" ]]; then
            # Extract Celsius from Kelvin value in parentheses
            kelvin=$(echo "$temp_line" | grep -o '([0-9]* K)' | sed 's/[^0-9]//g')
            if [[ -n "$kelvin" && "$kelvin" -gt 0 ]]; then
              temp=$((kelvin - 273))  # Convert Kelvin to Celsius
              if [[ "$temp" -lt 60 ]]; then
                echo "  ✅ Temperature: ''${temp}°C"
              elif [[ "$temp" -lt 80 ]]; then
                echo "  ⚠️  Temperature: ''${temp}°C (Warm)"
              else
                echo "  🔥 Temperature: ''${temp}°C (HOT!)"
              fi
            fi
          fi
          
          # Available spare
          spare=$(sudo nvme smart-log "$device" 2>/dev/null | grep "^available_spare[[:space:]]*:" | awk '{print $3}' | sed 's/%//' || echo "N/A")
          if [[ -n "$spare" && "$spare" != "N/A" ]]; then
            if [[ "$spare" -gt 50 ]]; then
              echo "  ✅ Available Spare: $spare%"
            elif [[ "$spare" -gt 10 ]]; then
              echo "  ⚠️  Available Spare: $spare%"
            else
              echo "  ❌ Available Spare: $spare% (LOW!)"
            fi
          fi
          
          # Power on hours
          hours=$(sudo smartctl -A "$device" 2>/dev/null | grep "Power On Hours:" | awk '{print $4}' || echo "")
          if [[ -n "$hours" && "$hours" != "" && "$hours" -gt 0 ]]; then
            days=$((hours / 24))
            echo "  📊 Power On Time: $hours hours ($days days)"
          fi
          
          echo
        fi
      done
    '';
    
    # Performance benchmarking
    nvme-benchmark = driveCommand "nvme-benchmark" ''
      if [[ $# -lt 1 ]]; then
        echo "Usage: nvme-benchmark <command> [options...]"
        echo "Commands:"
        echo "  single <slot>                  # Benchmark single drive"
        echo "  compare <slot1> <slot2>        # Compare two drives"
        echo "  all                            # Benchmark all drives"
        echo "  quick <slot>                   # Quick benchmark (faster)"
        echo "Examples:"
        echo "  nvme-benchmark single 2        # Benchmark slot 2"
        echo "  nvme-benchmark compare 2 3     # Compare slots 2 and 3"
        echo "  nvme-benchmark all             # Benchmark all installed drives"
        echo "  nvme-benchmark quick 2         # Quick benchmark of slot 2"
        exit 1
      fi
      
      command="$1"
      shift
      
      case "$command" in
        single|quick)
          if [[ $# -ne 1 ]]; then
            echo "Usage: nvme-benchmark $command <slot>"
            exit 1
          fi
          
          slot="$1"
          mode="full"
          [[ "$command" == "quick" ]] && mode="quick"
          
          if [[ "$slot" -lt 1 || "$slot" -gt 6 ]]; then
            echo "Error: Slot must be between 1-6"
            exit 1
          fi
          
          device="/dev/nvme$((slot-1))n1"
          
          if [[ ! -e "$device" ]]; then
            echo "Error: No drive found in slot $slot ($device)"
            exit 1
          fi
          
          echo "=== NVMe Drive Benchmark - Slot $slot ($device) ==="
          echo
          
          # Get drive info
          model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
          size_human=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
          serial=""
          
          if command -v smartctl >/dev/null 2>&1; then
            serial=$(sudo smartctl -i "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
          fi
          
          echo "Drive Information:"
          echo "  Model: $model"
          echo "  Size: $size_human"
          echo "  Serial: $serial"
          echo "  Device: $device"
          echo
          
          # Check if mounted
          if findmnt "$device" >/dev/null 2>&1 || findmnt "''${device}p1" >/dev/null 2>&1; then
            echo "⚠️  WARNING: Drive appears to be mounted. Results may be affected."
            findmnt "$device"* 2>/dev/null || true
            echo
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
              echo "Benchmark cancelled"
              exit 0
            fi
          fi
          
          # Test parameters
          if [[ "$mode" == "quick" ]]; then
            test_size=512
            echo "Running quick benchmark (512MB test)..."
          else
            test_size=1024
            echo "Running full benchmark (1GB test)..."
          fi
          echo
          
          # Sequential read test
          echo "🔍 Sequential Read Test:"
          read_speed=$(sudo dd if="$device" of=/dev/null bs=1M count=$test_size 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Unknown")
          echo "   Sequential Read: $read_speed"
          
          # Temperature check
          temp=""
          if command -v nvme >/dev/null 2>&1; then
            # Extract Celsius from Kelvin value in parentheses
            temp_line=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 || echo "")
            if [[ -n "$temp_line" ]]; then
              kelvin=$(echo "$temp_line" | grep -o '([0-9]* K)' | sed 's/[^0-9]//g')
              if [[ -n "$kelvin" && "$kelvin" -gt 0 ]]; then
                temp=$((kelvin - 273))  # Convert Kelvin to Celsius
              fi
            fi
          fi
          
          if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
            temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
          fi
          
          echo "🌡️  Drive Status:"
          if [[ -n "$temp" && "$temp" != "0" ]]; then
            echo "   Temperature: ''${temp}°C"
            if [[ "$temp" -gt 80 ]]; then
              echo "   ⚠️  High temperature detected!"
            fi
          else
            echo "   Temperature: Unknown"
          fi
          
          # Health check
          health=""
          if command -v nvme >/dev/null 2>&1; then
            health=$(sudo nvme smart-log "$device" 2>/dev/null | grep "critical_warning" | awk '{print $3}' || echo "")
          fi
          
          if [[ "$health" == "0x00" || "$health" == "0" ]]; then
            echo "   Health Status: ✅ Good"
          elif [[ -n "$health" ]]; then
            echo "   Health Status: ⚠️  Warning ($health)"
          else
            echo "   Health Status: Unknown"
          fi
          
          echo
          echo "✅ Benchmark completed!"
          ;;
          
        compare)
          if [[ $# -ne 2 ]]; then
            echo "Usage: nvme-benchmark compare <slot1> <slot2>"
            exit 1
          fi
          
          slot1="$1"
          slot2="$2"
          
          if [[ "$slot1" -lt 1 || "$slot1" -gt 6 || "$slot2" -lt 1 || "$slot2" -gt 6 ]]; then
            echo "Error: Slots must be between 1-6"
            exit 1
          fi
          
          if [[ "$slot1" == "$slot2" ]]; then
            echo "Error: Cannot compare a drive with itself"
            exit 1
          fi
          
          device1="/dev/nvme$((slot1-1))n1"
          device2="/dev/nvme$((slot2-1))n1"
          
          if [[ ! -e "$device1" ]]; then
            echo "Error: No drive found in slot $slot1 ($device1)"
            exit 1
          fi
          
          if [[ ! -e "$device2" ]]; then
            echo "Error: No drive found in slot $slot2 ($device2)"
            exit 1
          fi
          
          echo "=== NVMe Drive Comparison - Slot $slot1 vs Slot $slot2 ==="
          echo
          
          # Get info for both drives
          for i in 1 2; do
            slot_var="slot$i"
            device_var="device$i"
            slot="''${!slot_var}"
            device="''${!device_var}"
            
            model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
            size_human=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
            
            echo "Drive $i (Slot $slot): $model ($size_human)"
          done
          
          echo
          echo "Running quick performance comparison..."
          read -p "Continue? (y/N): " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Comparison cancelled"
            exit 0
          fi
          
          echo "📊 Performance Results:"
          
          for i in 1 2; do
            slot_var="slot$i"
            device_var="device$i"
            slot="''${!slot_var}"
            device="''${!device_var}"
            
            echo "Testing Drive $i (Slot $slot)..."
            
            # Quick read test
            read_speed=$(sudo dd if="$device" of=/dev/null bs=1M count=512 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Unknown")
            echo "   Drive $i Read Speed: $read_speed"
            
            # Temperature
            temp=""
            if command -v nvme >/dev/null 2>&1; then
              # Extract Celsius from Kelvin value in parentheses
              temp_line=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 || echo "")
              if [[ -n "$temp_line" ]]; then
                kelvin=$(echo "$temp_line" | grep -o '([0-9]* K)' | sed 's/[^0-9]//g')
                if [[ -n "$kelvin" && "$kelvin" -gt 0 ]]; then
                  temp=$((kelvin - 273))  # Convert Kelvin to Celsius
                fi
              fi
            fi
            
            if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
              temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
            fi
            
            if [[ -n "$temp" && "$temp" != "0" ]]; then
              echo "   Drive $i Temperature: ''${temp}°C"
            fi
          done
          
          echo
          echo "✅ Comparison completed!"
          ;;
          
        all)
          echo "=== Benchmarking All NVMe Drives ==="
          echo
          
          found_drives=0
          
          for i in {1..6}; do
            device="/dev/nvme$((i-1))n1"
            
            if [[ -e "$device" ]]; then
              found_drives=$((found_drives + 1))
              
              model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
              size_human=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
              
              echo "Slot $i: $model ($size_human)"
              
              # Quick read test
              read_speed=$(timeout 30 sudo dd if="$device" of=/dev/null bs=1M count=256 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Timeout/Error")
              echo "   Read Speed: $read_speed"
              
              # Temperature
              temp=""
              if command -v nvme >/dev/null 2>&1; then
                # Extract Celsius from Kelvin value in parentheses
                temp_line=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 || echo "")
                if [[ -n "$temp_line" ]]; then
                  kelvin=$(echo "$temp_line" | grep -o '([0-9]* K)' | sed 's/[^0-9]//g')
                  if [[ -n "$kelvin" && "$kelvin" -gt 0 ]]; then
                    temp=$((kelvin - 273))  # Convert Kelvin to Celsius
                  fi
                fi
              fi
              
              if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
                temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
              fi
              
              if [[ -n "$temp" && "$temp" != "0" ]]; then
                echo "   Temperature: ''${temp}°C"
              fi
              
              echo
            fi
          done
          
          if [[ "$found_drives" -eq 0 ]]; then
            echo "No NVMe drives found"
            exit 1
          fi
          
          echo "✅ Found and tested $found_drives drives"
          ;;
          
        *)
          echo "Error: Unknown benchmark command '$command'"
          exit 1
          ;;
      esac
    '';

    # Mount/unmount drives
    nvme-mount = driveCommand "nvme-mount" ''
      if [[ $# -lt 1 ]]; then
        echo "Usage: nvme-mount <slot|label|all> [mount-point]"
        echo "Examples:"
        echo "  nvme-mount 2              # Mount slot 2 to /mnt/drive2"
        echo "  nvme-mount data /mnt/nas  # Mount drive labeled 'data' to /mnt/nas"
        echo "  nvme-mount all            # Mount all labeled drives"
        exit 1
      fi
      
      target="$1"
      mount_point="''${2:-}"
      
      if [[ "$target" == "all" ]]; then
        echo "Mounting all labeled drives..."
        for label in data drive1 drive2 drive3 drive4 drive5; do
          if [[ -e "/dev/disk/by-label/$label" ]]; then
            default_mount="/mnt/$label"
            mkdir -p "$default_mount"
            if ! mountpoint -q "$default_mount"; then
              mount LABEL="$label" "$default_mount"
              echo "✓ Mounted $label to $default_mount"
              
              # Fix permissions after mounting
              chown jager:users "$default_mount"
              chmod 755 "$default_mount"
              echo "✓ Fixed permissions for $default_mount"
            else
              echo "- $label already mounted at $default_mount"
            fi
          fi
        done
      elif [[ "$target" =~ ^[1-6]$ ]]; then
        # Mount by slot number
        device="/dev/nvme$((target-1))n1"
        if [[ ! -e "$device" ]]; then
          echo "Error: No drive found in slot $target"
          exit 1
        fi
        
        if [[ -z "$mount_point" ]]; then
          mount_point="/mnt/drive$target"
        fi
        
        mkdir -p "$mount_point"
        if ! mountpoint -q "$mount_point"; then
          mount "$device" "$mount_point"
          echo "✓ Mounted slot $target to $mount_point"
          
          # Fix permissions after mounting
          chown jager:users "$mount_point"
          chmod 755 "$mount_point"
          echo "✓ Fixed permissions for $mount_point"
        else
          echo "- Slot $target already mounted at $mount_point"
        fi
      else
        # Mount by label
        if [[ ! -e "/dev/disk/by-label/$target" ]]; then
          echo "Error: No drive found with label '$target'"
          exit 1
        fi
        
        if [[ -z "$mount_point" ]]; then
          mount_point="/mnt/$target"
        fi
        
        mkdir -p "$mount_point"
        if ! mountpoint -q "$mount_point"; then
          mount LABEL="$target" "$mount_point"
          echo "✓ Mounted $target to $mount_point"
          
          # Fix permissions after mounting
          chown jager:users "$mount_point"
          chmod 755 "$mount_point"
          echo "✓ Fixed permissions for $mount_point"
        else
          echo "- $target already mounted at $mount_point"  
        fi
      fi
    '';
    
    # RAID management
    nvme-raid = driveCommand "nvme-raid" ''
      if [[ $# -lt 2 ]]; then
        echo "Usage: nvme-raid <command> <level> [slots...]"
        echo "Commands: create, destroy, status, add, remove"
        echo "Levels: 0, 1, 5, 6, 10"
        echo "Examples:"
        echo "  nvme-raid create 5 2 3 4 5    # Create RAID 5 with slots 2-5"
        echo "  nvme-raid status              # Show RAID status"
        echo "  nvme-raid destroy /dev/md0    # Destroy RAID array"
        exit 1
      fi
      
      command="$1"
      level="$2"
      shift 2
      
      case "$command" in
        create)
          if [[ $# -lt 2 ]]; then
            echo "Error: Need at least 2 drives for RAID"
            exit 1
          fi
          
          devices=()
          for slot in "$@"; do
            device="/dev/nvme$((slot-1))n1"
            if [[ ! -e "$device" ]]; then
              echo "Error: No drive found in slot $slot ($device)"
              exit 1
            fi
            devices+=("$device")
          done
          
          echo "Creating RAID $level with drives: ''${devices[*]}"
          echo "WARNING: This will destroy all data on these drives!"
          read -p "Continue? (yes/no): " confirm
          
          if [[ "$confirm" != "yes" ]]; then
            echo "Operation cancelled"
            exit 0
          fi
          
          # Unmount drives if mounted
          for device in "''${devices[@]}"; do
            if mountpoint -q "$device" 2>/dev/null; then
              umount "$device"
            fi
          done
          
          # Create RAID array
          mdadm --create --verbose /dev/md0 --level="$level" --raid-devices=''${#devices[@]} "''${devices[@]}"
          
          # Format RAID array
          echo "Formatting RAID array..."
          mkfs.ext4 -F -L "raid$level" /dev/md0
          
          echo "✓ RAID $level array created successfully!"
          echo "Device: /dev/md0"
          echo "Mount with: sudo mount /dev/md0 /mnt/raid"
          ;;
        
        status)
          if [[ -f /proc/mdstat ]]; then
            echo "=== RAID Status ==="
            cat /proc/mdstat
            echo
            
            for md in /dev/md*; do
              if [[ -e "$md" ]]; then
                echo "Details for $md:"
                mdadm --detail "$md" 2>/dev/null || echo "No details available"
                echo
              fi
            done
          else
            echo "No RAID arrays found"
          fi
          ;;
        
        destroy)
          array="/dev/md0"
          if [[ -n "$level" && "$level" != "0" ]]; then
            array="$level"  # Allow specifying custom array path
          fi
          
          if [[ ! -e "$array" ]]; then
            echo "Error: RAID array $array not found"
            exit 1
          fi
          
          echo "WARNING: This will destroy RAID array $array and all data!"
          read -p "Continue? (yes/no): " confirm
          
          if [[ "$confirm" != "yes" ]]; then
            echo "Operation cancelled"
            exit 0
          fi
          
          # Unmount if mounted
          if mountpoint -q "$array" 2>/dev/null; then
            umount "$array"
          fi
          
          # Stop and remove array
          mdadm --stop "$array"
          mdadm --remove "$array"
          
          echo "✓ RAID array destroyed"
          ;;
        
        *)
          echo "Error: Unknown command '$command'"
          exit 1
          ;;
      esac
    '';
  };
  
in

{
  options.nvmeManager = {
    enable = mkEnableOption "Advanced NVMe drive management for 6-slot NAS";
    
    installUtils = mkOption {
      type = types.bool;
      default = true;
      description = "Install NVMe management utilities";
    };
    
    enableMonitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automated health monitoring";
    };
    
    monitoringInterval = mkOption {
      type = types.str;
      default = "1h";
      description = "How often to check drive health";
    };
    
    alertThresholds = mkOption {
      type = types.submodule {
        options = {
          temperature = mkOption {
            type = types.int;
            default = 75;
            description = "Temperature threshold in Celsius";
          };
          
          availableSpare = mkOption {
            type = types.int;
            default = 10;
            description = "Available spare threshold percentage";
          };
        };
      };
      default = {};
      description = "Health monitoring alert thresholds";
    };
  };
  
  config = mkIf cfg.enable {
    # Install management packages
    environment.systemPackages = with pkgs; [
      # Storage management tools
      smartmontools
      nvme-cli
      parted
      gptfdisk
      e2fsprogs
      xfsprogs
      btrfs-progs
      ntfs3g
      mdadm
      lvm2
      pv  # Progress viewer for clone operations
      
      # Monitoring tools
      iotop
      sysstat
      lsof
      hdparm
      
      # Benchmarking tools
      fio      # Flexible I/O tester
      jq       # JSON processor for fio output
      
    ] ++ (if cfg.installUtils then (attrValues nvmeScripts) else []);
    
    # Create utility script file
    environment.etc."nixos/nvme-utils.sh".text = ''
      # Common utility functions for NVMe management
      
      # Color output functions
      log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
      log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
      log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
      log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
      
      # Check if user is root or has sudo
      check_root() {
        if [[ $EUID -ne 0 ]]; then
          log_error "This operation requires root privileges"
          exit 1
        fi
      }
      
      # Validate slot number
      validate_slot() {
        local slot=$1
        if [[ "$slot" -lt 1 || "$slot" -gt 6 ]]; then
          log_error "Invalid slot number: $slot (must be 1-6)"
          exit 1
        fi
      }
      
      # Get device path from slot
      slot_to_device() {
        local slot=$1
        echo "/dev/nvme$((slot-1))n1"
      }
      
      # Check if device exists
      device_exists() {
        local device=$1
        [[ -e "$device" ]]
      }
      
      # Get drive temperature
      get_temperature() {
        local device=$1
        nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 | awk '{print $3}' | sed 's/[^0-9]//g' || echo ""
      }
      
      # Get drive health status
      get_health() {
        local device=$1
        nvme smart-log "$device" 2>/dev/null | grep "critical_warning" | awk '{print $3}' || echo ""
      }
    '';
    
    # Enable monitoring service if requested
    systemd.services.nvme-health-monitor = mkIf cfg.enableMonitoring {
      description = "NVMe Health Monitoring Service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        #!/bin/bash
        source /etc/nixos/nvme-utils.sh
        
        # Check all NVMe drives for health issues
        for i in {0..5}; do
          device="/dev/nvme''${i}n1"
          slot=$((i+1))
          
          if device_exists "$device"; then
            # Check temperature
            temp=$(get_temperature "$device")
            if [[ -n "$temp" && "$temp" -gt ${toString cfg.alertThresholds.temperature} ]]; then
              echo "WARNING: Slot $slot ($device) temperature is high: ''${temp}°C" | systemd-cat -t nvme-monitor -p warning
            fi
            
            # Check critical warnings
            health=$(get_health "$device")
            if [[ -n "$health" && "$health" != "0x00" ]]; then
              echo "CRITICAL: Slot $slot ($device) has critical warning: $health" | systemd-cat -t nvme-monitor -p crit
            fi
            
            # Check available spare
            spare=$(nvme smart-log "$device" 2>/dev/null | grep "available_spare" | awk '{print $3}' | sed 's/%//' || echo "")
            if [[ -n "$spare" && "$spare" -lt ${toString cfg.alertThresholds.availableSpare} ]]; then
              echo "WARNING: Slot $slot ($device) available spare is low: $spare%" | systemd-cat -t nvme-monitor -p warning
            fi
          fi
        done
      '';
    };
    
    # Timer for health monitoring
    systemd.timers.nvme-health-monitor = mkIf cfg.enableMonitoring {
      description = "NVMe Health Monitoring Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.monitoringInterval;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
    
    # Shell aliases for convenience (works with both bash and zsh)
    programs.bash.shellAliases = mkIf cfg.installUtils {
      "nvme-ls" = "nvme-list";
      "nvme-fmt" = "nvme-format";
      "nvme-health-check" = "nvme-health";
      "nvme-temp" = "nvme-health | grep Temperature";
      "nvme-bench" = "nvme-benchmark";
      "nvme-bench-all" = "nvme-benchmark all";
      "list-drives" = "lsblk -f";
      "mount-all" = "nvme-mount all";
    };
    
    # Enable zsh and configure aliases
    programs.zsh = mkIf cfg.installUtils {
      enable = true;
      shellAliases = {
        "nvme-ls" = "nvme-list";
        "nvme-fmt" = "nvme-format";
        "nvme-health-check" = "nvme-health";
        "nvme-temp" = "nvme-health | grep Temperature";
        "nvme-bench" = "nvme-benchmark";
        "nvme-bench-all" = "nvme-benchmark all";
        "list-drives" = "lsblk -f";
        "mount-all" = "nvme-mount all";
      };
    };
    
    # Add NVMe optimization settings
    boot.kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"  # Disable power saving
      "nvme.poll_queues=2"                     # Enable polling queues
    ];
    
    # udev rules for consistent device naming and permissions
    services.udev.extraRules = ''
      # NVMe drive permissions for management tools
      SUBSYSTEM=="nvme", GROUP="wheel", MODE="0664"
      
      # Set optimal I/O scheduler for NVMe drives
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
      
      # Set optimal queue depth
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="128"
    '';
  };
} 