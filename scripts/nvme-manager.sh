#!/usr/bin/env bash

# NVMe Drive Manager for Beelink ME Mini 6-Slot NAS
# Comprehensive management tool for all 6 NVMe slots

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}[NVMe]${NC} $1"; }

# Utility functions
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This operation requires root privileges"
    log_info "Run with: sudo $0 $*"
    exit 1
  fi
}

validate_slot() {
  local slot=$1
  if [[ "$slot" -lt 1 || "$slot" -gt 6 ]]; then
    log_error "Invalid slot number: $slot (must be 1-6)"
    exit 1
  fi
}

slot_to_device() {
  local slot=$1
  echo "/dev/nvme$((slot - 1))n1"
}

device_exists() {
  local device=$1
  [[ -e "$device" ]]
}

get_temperature() {
  local device=$1
  nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 | awk '{print $3}' | sed 's/[^0-9]//g' || echo ""
}

get_health() {
  local device=$1
  nvme smart-log "$device" 2>/dev/null | grep "critical_warning" | awk '{print $3}' || echo ""
}

# Main commands
cmd_list() {
  log_header "NVMe Drive Inventory"
  echo

  local total_drives=0
  local total_capacity=0

  for i in {0..5}; do
    local device="/dev/nvme${i}n1"
    local slot=$((i + 1))

    echo "Slot $slot: $device"

    if device_exists "$device"; then
      total_drives=$((total_drives + 1))

      # Get basic info
      local model=$(nvme id-ctrl "$device" 2>/dev/null | grep "^mn" | cut -d: -f2 | xargs || echo "Unknown")
      local serial=$(nvme id-ctrl "$device" 2>/dev/null | grep "^sn" | cut -d: -f2 | xargs || echo "Unknown")
      local size_bytes=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 || echo "0")
      local size_human=$(echo "$size_bytes" | numfmt --to=iec-i || echo "Unknown")

      if [[ "$size_bytes" -gt 0 ]]; then
        total_capacity=$((total_capacity + size_bytes))
      fi

      echo "  ✓ Present: $model ($serial) - $size_human"

      # Check filesystem
      if blkid "${device}p1" >/dev/null 2>&1; then
        local fstype=$(blkid -o value -s TYPE "${device}p1" 2>/dev/null || echo "Unknown")
        local label=$(blkid -o value -s LABEL "${device}p1" 2>/dev/null || echo "No label")
        echo "  📁 Formatted: $fstype"
        echo "  🏷️  Label: $label"

        # Check mount status
        local mount_point=$(findmnt -n -o TARGET "${device}p1" 2>/dev/null || echo "Not mounted")
        echo "  📍 Mount: $mount_point"
      elif blkid "$device" >/dev/null 2>&1; then
        local fstype=$(blkid -o value -s TYPE "$device" 2>/dev/null || echo "Unknown")
        local label=$(blkid -o value -s LABEL "$device" 2>/dev/null || echo "No label")
        echo "  📁 Formatted: $fstype (whole disk)"
        echo "  🏷️  Label: $label"

        # Check mount status
        local mount_point=$(findmnt -n -o TARGET "$device" 2>/dev/null || echo "Not mounted")
        echo "  📍 Mount: $mount_point"
      else
        echo "  ❌ Unformatted"
      fi

      # Health status
      local health=$(get_health "$device")
      if [[ "$health" == "0x00" ]]; then
        echo "  ❤️  Health: Good"
      else
        echo "  ⚠️  Health: Warning ($health)"
      fi

      # Temperature
      local temp=$(get_temperature "$device")
      if [[ -n "$temp" ]]; then
        if [[ "$temp" -lt 60 ]]; then
          echo "  🌡️  Temp: ${temp}°C"
        elif [[ "$temp" -lt 80 ]]; then
          echo "  🌡️  Temp: ${temp}°C (Warm)"
        else
          echo "  🔥 Temp: ${temp}°C (HOT!)"
        fi
      fi
    else
      echo "  ❌ Empty slot"
    fi
    echo
  done

  echo "Summary:"
  echo "  Total drives: $total_drives/6"
  if [[ "$total_capacity" -gt 0 ]]; then
    local total_human=$(echo "$total_capacity" | numfmt --to=iec-i)
    echo "  Total capacity: $total_human"
  fi
}

cmd_format() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: $0 format <slot> <filesystem> [label]"
    echo "Slots: 1-6 (slot 1 is typically system drive)"
    echo "Filesystems: ext4, xfs, btrfs, ntfs"
    echo "Example: $0 format 2 ext4 data"
    exit 1
  fi

  local slot="$1"
  local filesystem="$2"
  local label="${3:-drive$slot}"

  check_root
  validate_slot "$slot"

  local device=$(slot_to_device "$slot")

  if ! device_exists "$device"; then
    log_error "No drive found in slot $slot ($device)"
    exit 1
  fi

  log_warning "This will destroy all data on $device (slot $slot)"
  echo "Drive info:"
  lsblk "$device" || true
  echo
  read -p "Are you sure? Type 'yes' to continue: " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_info "Operation cancelled"
    exit 0
  fi

  log_info "Formatting $device with $filesystem..."

  # Unmount if mounted
  for part in "${device}"*; do
    if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
      log_info "Unmounting $part..."
      umount "$part" || true
    fi
  done

  # Create GPT partition table
  log_info "Creating partition table..."
  parted -s "$device" mklabel gpt
  parted -s "$device" mkpart primary 0% 100%

  # Wait for partition to appear
  sleep 3
  local partition="${device}p1"

  # Make sure partition exists
  if [[ ! -e "$partition" ]]; then
    log_error "Partition $partition was not created"
    exit 1
  fi

  # Format with chosen filesystem
  log_info "Creating $filesystem filesystem with label '$label'..."
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
    log_error "Unsupported filesystem '$filesystem'"
    exit 1
    ;;
  esac

  log_success "Drive formatted successfully!"
  echo "Device: $device"
  echo "Partition: $partition"
  echo "Filesystem: $filesystem"
  echo "Label: $label"
  echo "Mount with: sudo mount LABEL=$label /mnt/your-mount-point"
}

cmd_clone() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 clone <source-slot> <destination-slot>"
    echo "Example: $0 clone 2 3  # Clone slot 2 to slot 3"
    exit 1
  fi

  local src_slot="$1"
  local dst_slot="$2"

  check_root
  validate_slot "$src_slot"
  validate_slot "$dst_slot"

  if [[ "$src_slot" == "$dst_slot" ]]; then
    log_error "Source and destination slots cannot be the same"
    exit 1
  fi

  local src_device=$(slot_to_device "$src_slot")
  local dst_device=$(slot_to_device "$dst_slot")

  if ! device_exists "$src_device"; then
    log_error "No source drive found in slot $src_slot ($src_device)"
    exit 1
  fi

  if ! device_exists "$dst_device"; then
    log_error "No destination drive found in slot $dst_slot ($dst_device)"
    exit 1
  fi

  log_warning "This will completely overwrite the destination drive!"
  echo "Source: Slot $src_slot ($src_device)"
  lsblk "$src_device" || true
  echo
  echo "Destination: Slot $dst_slot ($dst_device)"
  lsblk "$dst_device" || true
  echo
  read -p "Are you sure? Type 'yes' to continue: " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_info "Operation cancelled"
    exit 0
  fi

  # Unmount both drives if mounted
  for device_to_unmount in "$src_device" "$dst_device"; do
    for part in "${device_to_unmount}"*; do
      if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
        log_info "Unmounting $part..."
        umount "$part" || true
      fi
    done
  done

  log_info "Starting clone operation..."
  log_info "This may take a while depending on drive size..."

  # Use dd with progress monitoring
  if command -v pv >/dev/null 2>&1; then
    # Get source size
    local src_size=$(blockdev --getsize64 "$src_device")
    log_info "Cloning $(echo "$src_size" | numfmt --to=iec-i) of data..."
    dd if="$src_device" bs=64M | pv -s "$src_size" | dd of="$dst_device" bs=64M
  else
    dd if="$src_device" of="$dst_device" bs=64M status=progress
  fi

  # Force partition table re-read
  partprobe "$dst_device" || true

  log_success "Clone operation completed successfully!"
  echo "Source: $src_device (slot $src_slot)"
  echo "Destination: $dst_device (slot $dst_slot)"
}

cmd_health() {
  log_header "NVMe Drive Health Report"
  echo "Generated: $(date)"
  echo

  for i in {0..5}; do
    local device="/dev/nvme${i}n1"
    local slot=$((i + 1))

    if device_exists "$device"; then
      echo "Slot $slot ($device):"

      # SMART overall health
      local health=$(smartctl -H "$device" 2>/dev/null | grep "overall-health" | awk '{print $6}' || echo "UNKNOWN")
      if [[ "$health" == "PASSED" ]]; then
        echo "  ✅ Overall Health: PASSED"
      else
        echo "  ❌ Overall Health: $health"
      fi

      # NVMe specific health
      local critical=$(get_health "$device")
      if [[ "$critical" == "0x00" ]]; then
        echo "  ✅ Critical Warning: None"
      else
        echo "  ⚠️  Critical Warning: $critical"
      fi

      # Temperature
      local temp=$(get_temperature "$device")
      if [[ -n "$temp" ]]; then
        if [[ "$temp" -lt 60 ]]; then
          echo "  ✅ Temperature: ${temp}°C"
        elif [[ "$temp" -lt 80 ]]; then
          echo "  ⚠️  Temperature: ${temp}°C (Warm)"
        else
          echo "  🔥 Temperature: ${temp}°C (HOT!)"
        fi
      fi

      # Available spare
      local spare=$(nvme smart-log "$device" 2>/dev/null | grep "available_spare" | awk '{print $3}' | sed 's/%//' || echo "")
      if [[ -n "$spare" ]]; then
        if [[ "$spare" -gt 50 ]]; then
          echo "  ✅ Available Spare: $spare%"
        elif [[ "$spare" -gt 10 ]]; then
          echo "  ⚠️  Available Spare: $spare%"
        else
          echo "  ❌ Available Spare: $spare% (LOW!)"
        fi
      fi

      # Power on hours and data written
      if command -v smartctl >/dev/null 2>&1; then
        local hours=$(smartctl -A "$device" 2>/dev/null | grep -i "power.on.hours" | awk '{print $10}' || echo "")
        if [[ -n "$hours" ]]; then
          local days=$((hours / 24))
          echo "  📊 Power On Time: $hours hours ($days days)"
        fi

        local data_written=$(smartctl -A "$device" 2>/dev/null | grep -i "data.units.written" | awk '{print $10}' || echo "")
        if [[ -n "$data_written" ]]; then
          echo "  📝 Data Written: $data_written units"
        fi
      fi

      echo
    fi
  done
}

cmd_mount() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 mount <slot|label|all> [mount-point]"
    echo "Examples:"
    echo "  $0 mount 2              # Mount slot 2 to /mnt/drive2"
    echo "  $0 mount data /mnt/nas  # Mount drive labeled 'data' to /mnt/nas"
    echo "  $0 mount all            # Mount all labeled drives"
    exit 1
  fi

  local target="$1"
  local mount_point="${2:-}"

  check_root

  if [[ "$target" == "all" ]]; then
    log_info "Mounting all labeled drives..."
    for label in data drive1 drive2 drive3 drive4 drive5; do
      if [[ -e "/dev/disk/by-label/$label" ]]; then
        local default_mount="/mnt/$label"
        mkdir -p "$default_mount"
        if ! mountpoint -q "$default_mount"; then
          mount LABEL="$label" "$default_mount"
          log_success "Mounted $label to $default_mount"
        else
          log_info "$label already mounted at $default_mount"
        fi
      fi
    done
  elif [[ "$target" =~ ^[1-6]$ ]]; then
    # Mount by slot number
    local device=$(slot_to_device "$target")
    if ! device_exists "$device"; then
      log_error "No drive found in slot $target"
      exit 1
    fi

    if [[ -z "$mount_point" ]]; then
      mount_point="/mnt/drive$target"
    fi

    mkdir -p "$mount_point"

    # Try to mount partition first, then whole disk
    local mounted=false
    if [[ -e "${device}p1" ]]; then
      if ! mountpoint -q "$mount_point"; then
        mount "${device}p1" "$mount_point"
        log_success "Mounted slot $target (${device}p1) to $mount_point"
        mounted=true
      fi
    elif [[ -e "$device" ]]; then
      if ! mountpoint -q "$mount_point"; then
        mount "$device" "$mount_point"
        log_success "Mounted slot $target ($device) to $mount_point"
        mounted=true
      fi
    fi

    if ! $mounted; then
      log_info "Slot $target already mounted at $mount_point"
    fi
  else
    # Mount by label
    if [[ ! -e "/dev/disk/by-label/$target" ]]; then
      log_error "No drive found with label '$target'"
      exit 1
    fi

    if [[ -z "$mount_point" ]]; then
      mount_point="/mnt/$target"
    fi

    mkdir -p "$mount_point"
    if ! mountpoint -q "$mount_point"; then
      mount LABEL="$target" "$mount_point"
      log_success "Mounted $target to $mount_point"
    else
      log_info "$target already mounted at $mount_point"
    fi
  fi
}

cmd_unmount() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 unmount <slot|label|all|mount-point>"
    echo "Examples:"
    echo "  $0 unmount 2              # Unmount slot 2"
    echo "  $0 unmount data           # Unmount drive labeled 'data'"
    echo "  $0 unmount all            # Unmount all NVMe drives"
    echo "  $0 unmount /mnt/drive2    # Unmount specific path"
    exit 1
  fi

  local target="$1"

  check_root

  if [[ "$target" == "all" ]]; then
    log_info "Unmounting all NVMe drives..."
    for i in {0..5}; do
      local device="/dev/nvme${i}n1"
      if device_exists "$device"; then
        for part in "${device}"*; do
          if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
            local mount_point=$(findmnt -n -o TARGET "$part" 2>/dev/null || echo "")
            if [[ -n "$mount_point" ]]; then
              umount "$part"
              log_success "Unmounted $part from $mount_point"
            fi
          fi
        done
      fi
    done
  elif [[ "$target" =~ ^[1-6]$ ]]; then
    # Unmount by slot number
    local device=$(slot_to_device "$target")
    if ! device_exists "$device"; then
      log_error "No drive found in slot $target"
      exit 1
    fi

    local unmounted=false
    for part in "${device}"*; do
      if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
        local mount_point=$(findmnt -n -o TARGET "$part" 2>/dev/null || echo "")
        umount "$part"
        log_success "Unmounted slot $target ($part) from $mount_point"
        unmounted=true
      fi
    done

    if ! $unmounted; then
      log_info "Slot $target is not mounted"
    fi
  elif [[ "$target" == /* ]]; then
    # Unmount by mount point
    if mountpoint -q "$target"; then
      umount "$target"
      log_success "Unmounted $target"
    else
      log_info "$target is not a mount point"
    fi
  else
    # Unmount by label
    if [[ -e "/dev/disk/by-label/$target" ]]; then
      local device="/dev/disk/by-label/$target"
      if mountpoint -q "$device" 2>/dev/null; then
        local mount_point=$(findmnt -n -o TARGET "$device" 2>/dev/null || echo "")
        umount "$device"
        log_success "Unmounted $target from $mount_point"
      else
        log_info "Drive labeled '$target' is not mounted"
      fi
    else
      log_error "No drive found with label '$target'"
      exit 1
    fi
  fi
}

cmd_raid() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 raid <command> [options...]"
    echo "Commands:"
    echo "  status                     # Show RAID status"
    echo "  create <level> <slots...>  # Create RAID array"
    echo "  destroy <array>            # Destroy RAID array"
    echo "Examples:"
    echo "  $0 raid create 5 2 3 4 5   # Create RAID 5 with slots 2-5"
    echo "  $0 raid status             # Show RAID status"
    echo "  $0 raid destroy /dev/md0   # Destroy RAID array"
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
  status)
    if [[ -f /proc/mdstat ]]; then
      log_header "RAID Status"
      cat /proc/mdstat
      echo

      for md in /dev/md*; do
        if [[ -e "$md" && -b "$md" ]]; then
          echo "Details for $md:"
          mdadm --detail "$md" 2>/dev/null || echo "No details available"
          echo
        fi
      done
    else
      log_info "No RAID arrays found"
    fi
    ;;

  create)
    if [[ $# -lt 3 ]]; then
      log_error "Need RAID level and at least 2 drives"
      echo "Usage: $0 raid create <level> <slot1> <slot2> [slot3...]"
      exit 1
    fi

    local level="$1"
    shift

    check_root

    local devices=()
    for slot in "$@"; do
      validate_slot "$slot"
      local device=$(slot_to_device "$slot")
      if ! device_exists "$device"; then
        log_error "No drive found in slot $slot ($device)"
        exit 1
      fi
      devices+=("$device")
    done

    log_warning "Creating RAID $level with drives: ${devices[*]}"
    log_warning "This will destroy all data on these drives!"
    read -p "Continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
      log_info "Operation cancelled"
      exit 0
    fi

    # Unmount drives if mounted
    for device in "${devices[@]}"; do
      for part in "${device}"*; do
        if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
          log_info "Unmounting $part..."
          umount "$part" || true
        fi
      done
    done

    # Create RAID array
    log_info "Creating RAID $level array..."
    mdadm --create --verbose /dev/md0 --level="$level" --raid-devices=${#devices[@]} "${devices[@]}"

    # Format RAID array
    log_info "Formatting RAID array..."
    mkfs.ext4 -F -L "raid$level" /dev/md0

    log_success "RAID $level array created successfully!"
    echo "Device: /dev/md0"
    echo "Label: raid$level"
    echo "Mount with: sudo mount /dev/md0 /mnt/raid"
    ;;

  destroy)
    if [[ $# -ne 1 ]]; then
      log_error "Need RAID array device path"
      echo "Usage: $0 raid destroy <array>"
      exit 1
    fi

    local array="$1"
    check_root

    if [[ ! -e "$array" ]]; then
      log_error "RAID array $array not found"
      exit 1
    fi

    log_warning "This will destroy RAID array $array and all data!"
    read -p "Continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
      log_info "Operation cancelled"
      exit 0
    fi

    # Unmount if mounted
    if mountpoint -q "$array" 2>/dev/null; then
      log_info "Unmounting $array..."
      umount "$array"
    fi

    # Stop and remove array
    log_info "Stopping RAID array..."
    mdadm --stop "$array"

    log_info "Removing RAID array..."
    mdadm --remove "$array" 2>/dev/null || true

    log_success "RAID array destroyed"
    ;;

  *)
    log_error "Unknown RAID command '$command'"
    exit 1
    ;;
  esac
}

cmd_partition() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 partition <slot> [partition-type]"
    echo "Partition types: gpt (default), mbr"
    echo "Example: $0 partition 2 gpt"
    exit 1
  fi

  local slot="$1"
  local part_type="${2:-gpt}"

  check_root
  validate_slot "$slot"

  local device=$(slot_to_device "$slot")

  if ! device_exists "$device"; then
    log_error "No drive found in slot $slot ($device)"
    exit 1
  fi

  log_warning "This will create a new partition table on $device (slot $slot)"
  log_warning "All existing data will be lost!"
  echo "Drive info:"
  lsblk "$device" || true
  echo
  read -p "Continue? (yes/no): " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_info "Operation cancelled"
    exit 0
  fi

  # Unmount if mounted
  for part in "${device}"*; do
    if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
      log_info "Unmounting $part..."
      umount "$part" || true
    fi
  done

  # Create partition table
  case "$part_type" in
  gpt)
    log_info "Creating GPT partition table..."
    parted -s "$device" mklabel gpt
    ;;
  mbr)
    log_info "Creating MBR partition table..."
    parted -s "$device" mklabel msdos
    ;;
  *)
    log_error "Unsupported partition type '$part_type'"
    exit 1
    ;;
  esac

  log_success "Partition table created on $device"
  log_info "Use 'parted $device' to create partitions manually"
  log_info "Or use '$0 format $slot <filesystem>' to create a single partition"
}

cmd_wipe() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 wipe <slot>"
    echo "This will securely wipe the drive (WARNING: DESTRUCTIVE!)"
    exit 1
  fi

  local slot="$1"

  check_root
  validate_slot "$slot"

  local device=$(slot_to_device "$slot")

  if ! device_exists "$device"; then
    log_error "No drive found in slot $slot ($device)"
    exit 1
  fi

  log_warning "DANGER: This will securely wipe ALL DATA on $device (slot $slot)"
  log_warning "This operation cannot be undone!"
  echo "Drive info:"
  lsblk "$device" || true
  echo
  echo "Type the slot number again to confirm: "
  read -r confirm_slot

  if [[ "$confirm_slot" != "$slot" ]]; then
    log_info "Operation cancelled"
    exit 0
  fi

  # Unmount if mounted
  for part in "${device}"*; do
    if [[ -e "$part" ]] && mountpoint -q "$part" 2>/dev/null; then
      log_info "Unmounting $part..."
      umount "$part" || true
    fi
  done

  log_info "Starting secure wipe of $device..."
  log_info "This will take a very long time..."

  # Use NVMe secure erase if available, otherwise dd
  if nvme format "$device" --ses=1 2>/dev/null; then
    log_success "NVMe secure erase completed"
  else
    log_info "NVMe secure erase not available, using dd..."
    dd if=/dev/zero of="$device" bs=1M status=progress || true
    log_success "Drive wiped with zeros"
  fi

  log_success "Secure wipe completed on $device"
}

# Benchmark function
cmd_benchmark() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 benchmark <command> [options...]"
    echo "Commands:"
    echo "  single <slot>                  # Benchmark single drive"
    echo "  compare <slot1> <slot2>        # Compare two drives"
    echo "  all                            # Benchmark all drives"
    echo "  quick <slot>                   # Quick benchmark (faster)"
    echo "Examples:"
    echo "  $0 benchmark single 2          # Benchmark slot 2"
    echo "  $0 benchmark compare 2 3       # Compare slots 2 and 3"
    echo "  $0 benchmark all               # Benchmark all installed drives"
    echo "  $0 benchmark quick 2           # Quick benchmark of slot 2"
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
  single)
    if [[ $# -ne 1 ]]; then
      log_error "Usage: $0 benchmark single <slot>"
      exit 1
    fi
    benchmark_single_drive "$1"
    ;;
  compare)
    if [[ $# -ne 2 ]]; then
      log_error "Usage: $0 benchmark compare <slot1> <slot2>"
      exit 1
    fi
    benchmark_compare_drives "$1" "$2"
    ;;
  all)
    benchmark_all_drives
    ;;
  quick)
    if [[ $# -ne 1 ]]; then
      log_error "Usage: $0 benchmark quick <slot>"
      exit 1
    fi
    benchmark_single_drive "$1" "quick"
    ;;
  *)
    log_error "Unknown benchmark command: $command"
    exit 1
    ;;
  esac
}

# Benchmark a single drive
benchmark_single_drive() {
  local slot="$1"
  local mode="${2:-full}"

  validate_slot "$slot"

  local device=$(slot_to_device "$slot")

  if ! device_exists "$device"; then
    log_error "No drive found in slot $slot ($device)"
    exit 1
  fi

  log_header "NVMe Drive Benchmark - Slot $slot ($device)"
  echo

  # Get drive info first
  local model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
  local size_human=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
  local serial=""

  if command -v smartctl >/dev/null 2>&1; then
    serial=$(sudo smartctl -i "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
  fi

  echo "Drive Information:"
  echo "  Model: $model"
  echo "  Size: $size_human"
  echo "  Serial: $serial"
  echo "  Device: $device"
  echo

  # Check if drive is mounted and warn
  if findmnt "$device" >/dev/null 2>&1 || findmnt "${device}p1" >/dev/null 2>&1; then
    log_warning "Drive appears to be mounted. Benchmark results may be affected."
    echo "Mounted partitions:"
    findmnt "$device"* 2>/dev/null || true
    echo
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Benchmark cancelled"
      exit 0
    fi
  fi

  # Create temporary directory for test files
  local temp_dir="/tmp/nvme-benchmark-$$"
  local test_file="$temp_dir/testfile"
  local results_file="$temp_dir/results.txt"

  mkdir -p "$temp_dir"
  trap "rm -rf $temp_dir" EXIT

  log_info "Starting benchmark (this may take several minutes)..."
  echo "Results will be saved to: $results_file"
  echo

  # Initialize results file
  echo "NVMe Drive Benchmark Results" >"$results_file"
  echo "============================" >>"$results_file"
  echo "Date: $(date)" >>"$results_file"
  echo "Drive: $device (Slot $slot)" >>"$results_file"
  echo "Model: $model" >>"$results_file"
  echo "Size: $size_human" >>"$results_file"
  echo "Serial: $serial" >>"$results_file"
  echo "" >>"$results_file"

  # Test parameters based on mode
  local test_size_mb
  local test_duration

  if [[ "$mode" == "quick" ]]; then
    test_size_mb=1024 # 1GB
    test_duration=30  # 30 seconds
    log_info "Running quick benchmark (1GB test size, 30s duration)"
  else
    test_size_mb=4096 # 4GB
    test_duration=60  # 60 seconds
    log_info "Running full benchmark (4GB test size, 60s duration)"
  fi

  echo "Test Configuration:" >>"$results_file"
  echo "  Mode: $mode" >>"$results_file"
  echo "  Test Size: ${test_size_mb}MB" >>"$results_file"
  echo "  Test Duration: ${test_duration}s" >>"$results_file"
  echo "" >>"$results_file"

  # 1. Sequential Read Test
  log_info "🔍 Running sequential read test..."
  echo "1. Sequential Read Test" >>"$results_file"
  if command -v fio >/dev/null 2>&1; then
    local seq_read=$(fio --name=seq_read --filename="$device" --rw=read --bs=1M --size="${test_size_mb}M" --runtime="$test_duration" --direct=1 --ioengine=libaio --iodepth=32 --group_reporting --output-format=json 2>/dev/null | jq -r '.jobs[0].read.bw' 2>/dev/null || echo "0")
    if [[ "$seq_read" != "0" ]]; then
      local seq_read_mb=$((seq_read / 1024))
      echo "   Sequential Read: ${seq_read_mb} MB/s" | tee -a "$results_file"
    else
      # Fallback to dd
      local dd_result=$(dd if="$device" of=/dev/null bs=1M count=1024 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Unknown")
      echo "   Sequential Read: $dd_result (dd fallback)" | tee -a "$results_file"
    fi
  else
    # Fallback to dd
    local dd_result=$(dd if="$device" of=/dev/null bs=1M count=1024 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Unknown")
    echo "   Sequential Read: $dd_result (dd fallback)" | tee -a "$results_file"
  fi

  # 2. Sequential Write Test (only if not system drive)
  if [[ "$slot" != "1" ]]; then
    log_warning "Sequential write test will write to the drive!"
    read -p "Continue with write test? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_info "📝 Running sequential write test..."
      echo "2. Sequential Write Test" >>"$results_file"
      if command -v fio >/dev/null 2>&1; then
        local seq_write=$(fio --name=seq_write --filename="$device" --rw=write --bs=1M --size="${test_size_mb}M" --runtime="$test_duration" --direct=1 --ioengine=libaio --iodepth=32 --group_reporting --output-format=json 2>/dev/null | jq -r '.jobs[0].write.bw' 2>/dev/null || echo "0")
        if [[ "$seq_write" != "0" ]]; then
          local seq_write_mb=$((seq_write / 1024))
          echo "   Sequential Write: ${seq_write_mb} MB/s" | tee -a "$results_file"
        else
          echo "   Sequential Write: Skipped (fio failed)" | tee -a "$results_file"
        fi
      else
        echo "   Sequential Write: Skipped (fio not available)" | tee -a "$results_file"
      fi
    else
      echo "2. Sequential Write Test: Skipped by user" >>"$results_file"
    fi
  else
    log_warning "Skipping write tests on system drive (slot 1)"
    echo "2. Sequential Write Test: Skipped (system drive)" >>"$results_file"
  fi

  # 3. Random Read Test
  log_info "🎲 Running random read test..."
  echo "3. Random Read Test (4K blocks)" >>"$results_file"
  if command -v fio >/dev/null 2>&1; then
    local rand_read_iops=$(fio --name=rand_read --filename="$device" --rw=randread --bs=4k --runtime="$test_duration" --direct=1 --ioengine=libaio --iodepth=32 --group_reporting --output-format=json 2>/dev/null | jq -r '.jobs[0].read.iops' 2>/dev/null || echo "0")
    if [[ "$rand_read_iops" != "0" ]]; then
      local rand_read_iops_int=$(printf "%.0f" "$rand_read_iops")
      echo "   Random Read IOPS: ${rand_read_iops_int}" | tee -a "$results_file"
    else
      echo "   Random Read IOPS: Unknown (fio failed)" | tee -a "$results_file"
    fi
  else
    echo "   Random Read IOPS: Unknown (fio not available)" | tee -a "$results_file"
  fi

  # 4. Temperature and Health Check
  log_info "🌡️ Checking drive temperature and health..."
  echo "4. Drive Health After Benchmark" >>"$results_file"

  # Temperature
  local temp=""
  if command -v nvme >/dev/null 2>&1; then
    temp=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 | awk '{print $3}' | sed 's/[^0-9]//g' || echo "")
  fi

  if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
    temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
  fi

  if [[ -n "$temp" && "$temp" != "0" ]]; then
    echo "   Temperature: ${temp}°C" | tee -a "$results_file"
    if [[ "$temp" -gt 80 ]]; then
      log_warning "Drive temperature is high after benchmark: ${temp}°C"
    fi
  else
    echo "   Temperature: Unknown" | tee -a "$results_file"
  fi

  # Health status
  local health=""
  if command -v nvme >/dev/null 2>&1; then
    health=$(sudo nvme smart-log "$device" 2>/dev/null | grep "critical_warning" | awk '{print $3}' || echo "")
  fi

  if [[ "$health" == "0x00" ]]; then
    echo "   Health Status: Good" | tee -a "$results_file"
  elif [[ -n "$health" ]]; then
    echo "   Health Status: Warning ($health)" | tee -a "$results_file"
  else
    echo "   Health Status: Unknown" | tee -a "$results_file"
  fi

  echo "" >>"$results_file"
  echo "Benchmark completed at: $(date)" >>"$results_file"

  log_success "Benchmark completed!"
  echo "Full results saved to: $results_file"
  echo
  echo "📊 Summary:"
  grep -E "(Sequential|Random|Temperature|Health)" "$results_file" | sed 's/^/  /'
}

# Compare two drives
benchmark_compare_drives() {
  local slot1="$1"
  local slot2="$2"

  validate_slot "$slot1"
  validate_slot "$slot2"

  if [[ "$slot1" == "$slot2" ]]; then
    log_error "Cannot compare a drive with itself"
    exit 1
  fi

  local device1=$(slot_to_device "$slot1")
  local device2=$(slot_to_device "$slot2")

  if ! device_exists "$device1"; then
    log_error "No drive found in slot $slot1 ($device1)"
    exit 1
  fi

  if ! device_exists "$device2"; then
    log_error "No drive found in slot $slot2 ($device2)"
    exit 1
  fi

  log_header "NVMe Drive Comparison - Slot $slot1 vs Slot $slot2"
  echo

  # Create temporary directory for results
  local temp_dir="/tmp/nvme-compare-$$"
  local results_file="$temp_dir/comparison.txt"

  mkdir -p "$temp_dir"
  trap "rm -rf $temp_dir" EXIT

  # Initialize comparison file
  echo "NVMe Drive Comparison Results" >"$results_file"
  echo "=============================" >>"$results_file"
  echo "Date: $(date)" >>"$results_file"
  echo "Drive 1: $device1 (Slot $slot1)" >>"$results_file"
  echo "Drive 2: $device2 (Slot $slot2)" >>"$results_file"
  echo "" >>"$results_file"

  log_info "Gathering drive information..."

  # Get drive info for both drives
  for i in 1 2; do
    local slot_var="slot$i"
    local device_var="device$i"
    local slot="${!slot_var}"
    local device="${!device_var}"

    echo "Drive $i Information:" >>"$results_file"

    local model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
    local size_human=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
    local serial=""

    if command -v smartctl >/dev/null 2>&1; then
      serial=$(sudo smartctl -i "$device" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
    fi

    echo "  Model: $model" >>"$results_file"
    echo "  Size: $size_human" >>"$results_file"
    echo "  Serial: $serial" >>"$results_file"
    echo "  Device: $device" >>"$results_file"
    echo "" >>"$results_file"

    echo "Drive $i: $model ($size_human)"
  done

  echo
  log_info "Running quick benchmarks on both drives..."
  log_warning "This will perform read tests on both drives"

  read -p "Continue with comparison? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Comparison cancelled"
    exit 0
  fi

  # Simple read performance comparison using dd
  echo "Performance Comparison:" >>"$results_file"
  echo "======================" >>"$results_file"

  for i in 1 2; do
    local slot_var="slot$i"
    local device_var="device$i"
    local slot="${!slot_var}"
    local device="${!device_var}"

    log_info "Testing drive $i (slot $slot)..."

    # Sequential read test with dd
    local read_speed=$(dd if="$device" of=/dev/null bs=1M count=1024 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Unknown")
    echo "Drive $i Sequential Read: $read_speed" >>"$results_file"
    echo "  Drive $i: $read_speed"

    # Temperature check
    local temp=""
    if command -v nvme >/dev/null 2>&1; then
      temp=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 | awk '{print $3}' | sed 's/[^0-9]//g' || echo "")
    fi

    if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
      temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
    fi

    if [[ -n "$temp" && "$temp" != "0" ]]; then
      echo "Drive $i Temperature: ${temp}°C" >>"$results_file"
      echo "  Drive $i temp: ${temp}°C"
    fi
  done

  echo "" >>"$results_file"
  echo "Comparison completed at: $(date)" >>"$results_file"

  log_success "Drive comparison completed!"
  echo "Full results saved to: $results_file"
  echo
  echo "📊 Summary:"
  grep -E "(Sequential Read|Temperature)" "$results_file" | sed 's/^/  /'
}

# Benchmark all drives
benchmark_all_drives() {
  log_header "Benchmarking All NVMe Drives"
  echo

  local temp_dir="/tmp/nvme-benchmark-all-$$"
  local summary_file="$temp_dir/all-drives-summary.txt"

  mkdir -p "$temp_dir"
  trap "rm -rf $temp_dir" EXIT

  echo "All Drives Benchmark Summary" >"$summary_file"
  echo "============================" >>"$summary_file"
  echo "Date: $(date)" >>"$summary_file"
  echo "" >>"$summary_file"

  local found_drives=0

  for i in {1..6}; do
    local device=$(slot_to_device "$i")

    if device_exists "$device"; then
      found_drives=$((found_drives + 1))
      log_info "Found drive in slot $i ($device)"

      # Get basic info
      local model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || echo "Unknown")
      local size_human=$(lsblk -n -o SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")

      echo "Slot $i ($device):" >>"$summary_file"
      echo "  Model: $model" >>"$summary_file"
      echo "  Size: $size_human" >>"$summary_file"

      # Quick read test
      log_info "Quick read test for slot $i..."
      local read_speed=$(timeout 30 dd if="$device" of=/dev/null bs=1M count=512 2>&1 | grep -o '[0-9.]* MB/s' | tail -1 || echo "Timeout/Error")
      echo "  Read Speed: $read_speed" >>"$summary_file"
      echo "  Slot $i: $read_speed"

      # Temperature
      local temp=""
      if command -v nvme >/dev/null 2>&1; then
        temp=$(sudo nvme smart-log "$device" 2>/dev/null | grep "temperature" | head -1 | awk '{print $3}' | sed 's/[^0-9]//g' || echo "")
      fi

      if [[ -z "$temp" ]] && command -v smartctl >/dev/null 2>&1; then
        temp=$(sudo smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}' | sed 's/[^0-9]//g' || echo "")
      fi

      if [[ -n "$temp" && "$temp" != "0" ]]; then
        echo "  Temperature: ${temp}°C" >>"$summary_file"
      else
        echo "  Temperature: Unknown" >>"$summary_file"
      fi

      echo "" >>"$summary_file"
    fi
  done

  if [[ "$found_drives" -eq 0 ]]; then
    log_error "No NVMe drives found"
    exit 1
  fi

  echo "Summary completed at: $(date)" >>"$summary_file"

  log_success "All drives benchmark completed!"
  echo "Found and tested $found_drives drives"
  echo "Full results saved to: $summary_file"
  echo
  echo "📊 Summary:"
  grep -E "(Slot|Read Speed)" "$summary_file" | sed 's/^/  /'
}

# Help function
show_help() {
  cat <<EOF
NVMe Drive Manager for Beelink ME Mini 6-Slot NAS

Usage: $0 <command> [options...]

Commands:
  list                           # List all NVMe drives with status
  format <slot> <fs> [label]     # Format a drive
  clone <src-slot> <dst-slot>    # Clone one drive to another
  health                         # Show health status of all drives
  mount <slot|label|all> [path]  # Mount drives
  unmount <slot|label|all|path>  # Unmount drives
  raid <command> [options...]    # RAID management
  partition <slot> [type]        # Create partition table
  wipe <slot>                    # Securely wipe a drive
  benchmark <command> [options...] # Performance benchmarking

Examples:
  $0 list                        # Show all drives
  $0 format 2 ext4 data          # Format slot 2 as ext4 with label 'data'  
  $0 clone 2 3                   # Clone slot 2 to slot 3
  $0 health                      # Check health of all drives
  $0 mount all                   # Mount all labeled drives
  $0 mount 2 /mnt/backup         # Mount slot 2 to /mnt/backup
  $0 unmount data                # Unmount drive labeled 'data'
  $0 raid create 5 2 3 4 5       # Create RAID 5 with slots 2-5
  $0 raid status                 # Show RAID status
  $0 partition 2 gpt             # Create GPT partition table on slot 2
  $0 wipe 2                      # Securely wipe slot 2
  $0 benchmark single 2          # Benchmark slot 2 performance
  $0 benchmark compare 2 3       # Compare performance of slots 2 and 3
  $0 benchmark all               # Quick benchmark all drives

Slot Layout:
  Slot 1: /dev/nvme0n1 (typically system drive)
  Slot 2: /dev/nvme1n1 (data drive 1)
  Slot 3: /dev/nvme2n1 (data drive 2)  
  Slot 4: /dev/nvme3n1 (data drive 3)
  Slot 5: /dev/nvme4n1 (data drive 4)
  Slot 6: /dev/nvme5n1 (data drive 5)

Supported Filesystems: ext4, xfs, btrfs, ntfs
RAID Levels: 0, 1, 5, 6, 10

Note: Most operations require root privileges (sudo)
EOF
}

# Main command dispatcher
main() {
  if [[ $# -eq 0 ]]; then
    show_help
    exit 0
  fi

  local command="$1"
  shift

  case "$command" in
  list | ls)
    cmd_list "$@"
    ;;
  format | fmt)
    cmd_format "$@"
    ;;
  clone)
    cmd_clone "$@"
    ;;
  health | check)
    cmd_health "$@"
    ;;
  mount)
    cmd_mount "$@"
    ;;
  unmount | umount)
    cmd_unmount "$@"
    ;;
  raid)
    cmd_raid "$@"
    ;;
  partition | part)
    cmd_partition "$@"
    ;;
  wipe | erase)
    cmd_wipe "$@"
    ;;
  benchmark | bench)
    cmd_benchmark "$@"
    ;;
  help | --help | -h)
    show_help
    ;;
  *)
    log_error "Unknown command: $command"
    echo
    show_help
    exit 1
    ;;
  esac
}

# Run main function
main "$@"
