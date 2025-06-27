# NVMe Drive Manager for Beelink ME Mini 6-Slot NAS

The NVMe Manager provides comprehensive tools for managing all 6 NVMe slots in your Beelink ME Mini NAS. It includes both a NixOS module for system integration and a standalone script for manual management.

## 🎯 Features

- **Drive Management**: Format, partition, clone, and wipe drives
- **Health Monitoring**: Automated health checks with temperature and SMART monitoring
- **RAID Support**: Create and manage software RAID arrays
- **Mount Management**: Easy mounting/unmounting by slot, label, or path
- **Safety Features**: Confirmation prompts and data protection checks
- **Comprehensive Logging**: Color-coded output and detailed status reporting

## 📋 Quick Reference

### Slot Layout

```
Slot 1: /dev/nvme0n1 (typically system drive - be careful!)
Slot 2: /dev/nvme1n1 (data drive 1)
Slot 3: /dev/nvme2n1 (data drive 2)
Slot 4: /dev/nvme3n1 (data drive 3)
Slot 5: /dev/nvme4n1 (data drive 4)
Slot 6: /dev/nvme5n1 (data drive 5)
```

### Essential Commands

```bash
# List all drives and their status
nvme-manager.sh list

# Format a drive
sudo nvme-manager.sh format 2 ext4 data

# Check health of all drives
nvme-manager.sh health

# Mount all labeled drives
sudo nvme-manager.sh mount all

# Clone a drive
sudo nvme-manager.sh clone 2 3
```

## 🔧 Installation & Setup

The NVMe Manager is automatically installed when you enable it in your NixOS configuration:

```nix
# In hosts/beelink-mini/configuration.nix
nvmeManager = {
  enable = true;
  installUtils = true;           # Install management scripts
  enableMonitoring = true;       # Enable health monitoring
  monitoringInterval = "1h";     # Check health every hour
  
  alertThresholds = {
    temperature = 75;            # Alert if temp > 75°C
    availableSpare = 10;        # Alert if spare < 10%
  };
};
```

After enabling, rebuild your system:

```bash
sudo nixos-rebuild switch --flake .#beelink-mini
```

## 📖 Command Reference

### Drive Listing and Status

#### `nvme-manager.sh list`

Shows comprehensive information about all 6 slots:

- Drive presence and model information
- Serial numbers and capacity
- Filesystem type and labels
- Mount status and health
- Temperature readings

```bash
$ nvme-manager.sh list
=== NVMe Drive Inventory ===

Slot 1: /dev/nvme0n1
  ✓ Present: Samsung SSD 980 PRO (S5GXNX0R123456) - 500GiB
  📁 Formatted: ext4
  🏷️  Label: nixos
  📍 Mount: /
  ❤️  Health: Good
  🌡️  Temp: 45°C

Slot 2: /dev/nvme1n1
  ✓ Present: WD Black SN750 (WDS100T3X0C) - 1.0TiB
  📁 Formatted: ext4
  🏷️  Label: data
  📍 Mount: /mnt/data
  ❤️  Health: Good
  🌡️  Temp: 42°C

Slot 3: /dev/nvme2n1
  ❌ Empty slot

...

Summary:
  Total drives: 2/6
  Total capacity: 1.5TiB
```

### Drive Formatting

#### `nvme-manager.sh format <slot> <filesystem> [label]`

Formats a drive with the specified filesystem and optional label.

**Supported Filesystems:**

- `ext4` - Linux native (recommended for NAS)
- `xfs` - High-performance Linux filesystem
- `btrfs` - Advanced features (snapshots, compression)
- `ntfs` - Windows compatibility

```bash
# Format slot 2 as ext4 with label 'data'
sudo nvme-manager.sh format 2 ext4 data

# Format slot 3 as XFS with label 'backup'
sudo nvme-manager.sh format 3 xfs backup

# Format slot 4 as BTRFS (auto-label as 'drive4')
sudo nvme-manager.sh format 4 btrfs
```

**Safety Features:**

- Shows drive information before formatting
- Requires typing 'yes' to confirm
- Automatically unmounts before formatting
- Creates GPT partition table with single partition

### Drive Cloning

#### `nvme-manager.sh clone <source-slot> <destination-slot>`

Creates an exact bit-for-bit copy of one drive to another.

```bash
# Clone slot 2 to slot 3
sudo nvme-manager.sh clone 2 3

# Clone system drive (be very careful!)
sudo nvme-manager.sh clone 1 6
```

**Features:**

- Progress bar showing clone status
- Automatic unmounting of both drives
- Verification and safety checks
- Works with any filesystem or even unformatted drives

### Health Monitoring

#### `nvme-manager.sh health`

Comprehensive health report for all installed drives.

```bash
$ nvme-manager.sh health
=== NVMe Drive Health Report ===
Generated: Thu Nov 21 10:30:15 PST 2024

Slot 1 (/dev/nvme0n1):
  ✅ Overall Health: PASSED
  ✅ Critical Warning: None
  ✅ Temperature: 45°C
  ✅ Available Spare: 98%
  📊 Power On Time: 1250 hours (52 days)

Slot 2 (/dev/nvme1n1):
  ✅ Overall Health: PASSED
  ✅ Critical Warning: None
  ⚠️  Temperature: 78°C (Warm)
  ✅ Available Spare: 95%
  📊 Power On Time: 890 hours (37 days)
```

**Monitored Parameters:**

- Overall SMART health status
- Critical warnings (wear, temperature, reliability)
- Drive temperature with thresholds
- Available spare blocks
- Power-on hours and data written

### Mount Management

#### `nvme-manager.sh mount <target> [mount-point]`

Mount drives by slot number, label, or mount all at once.

```bash
# Mount all labeled drives to default locations
sudo nvme-manager.sh mount all

# Mount slot 2 to default location (/mnt/drive2)
sudo nvme-manager.sh mount 2

# Mount slot 3 to custom location
sudo nvme-manager.sh mount 3 /mnt/backup

# Mount by label to default location (/mnt/data)
sudo nvme-manager.sh mount data

# Mount by label to custom location
sudo nvme-manager.sh mount data /mnt/nas
```

#### `nvme-manager.sh unmount <target>`

Unmount drives by slot, label, mount point, or all at once.

```bash
# Unmount all NVMe drives
sudo nvme-manager.sh unmount all

# Unmount by slot
sudo nvme-manager.sh unmount 2

# Unmount by label
sudo nvme-manager.sh unmount data

# Unmount by mount point
sudo nvme-manager.sh unmount /mnt/backup
```

### RAID Management

#### `nvme-manager.sh raid <command> [options...]`

Create and manage software RAID arrays using multiple NVMe drives.

**Supported RAID Levels:**

- **RAID 0**: Striping (performance, no redundancy)
- **RAID 1**: Mirroring (redundancy, 50% capacity)
- **RAID 5**: Striping with parity (good balance, N-1 capacity)
- **RAID 6**: Double parity (high redundancy, N-2 capacity)
- **RAID 10**: Stripe of mirrors (performance + redundancy)

```bash
# Show current RAID status
nvme-manager.sh raid status

# Create RAID 5 with slots 2, 3, 4, 5
sudo nvme-manager.sh raid create 5 2 3 4 5

# Create RAID 1 mirror with slots 2 and 3
sudo nvme-manager.sh raid create 1 2 3

# Destroy RAID array
sudo nvme-manager.sh raid destroy /dev/md0
```

**RAID Creation Process:**

1. Validates all specified drives exist
2. Shows confirmation with drive details
3. Unmounts all drives automatically
4. Creates mdadm RAID array
5. Formats with ext4 and appropriate label
6. Provides mount instructions

### Partitioning

#### `nvme-manager.sh partition <slot> [type]`

Create partition tables on drives without formatting.

```bash
# Create GPT partition table (recommended)
sudo nvme-manager.sh partition 2 gpt

# Create MBR partition table (legacy compatibility)
sudo nvme-manager.sh partition 3 mbr
```

Use this when you want to manually create multiple partitions or need specific partition layouts.

### Secure Wiping

#### `nvme-manager.sh wipe <slot>`

Securely erase all data on a drive.

```bash
# Securely wipe slot 2
sudo nvme-manager.sh wipe 2
```

**Wiping Process:**

1. Attempts NVMe secure erase (instant, hardware-level)
2. Falls back to zero-fill if secure erase unavailable
3. Double confirmation required (very destructive!)
4. Automatic unmounting before wiping

### Performance Benchmarking

#### `nvme-manager.sh benchmark <command> [options...]`

Comprehensive performance testing and drive comparison tools.

**Available Commands:**

- `single <slot>` - Full benchmark of a single drive
- `quick <slot>` - Quick benchmark (faster, smaller test size)
- `compare <slot1> <slot2>` - Compare performance between two drives
- `all` - Quick benchmark of all installed drives

```bash
# Full benchmark of slot 2
sudo nvme-manager.sh benchmark single 2

# Quick benchmark of slot 3
nvme-manager.sh benchmark quick 3

# Compare performance between slots 2 and 3
nvme-manager.sh benchmark compare 2 3

# Quick benchmark all drives
nvme-manager.sh benchmark all
```

**Benchmark Features:**

- **Sequential Read Testing**: Measures large file read performance
- **Sequential Write Testing**: Measures large file write performance (non-system drives)
- **Random Read IOPS**: Measures small random read performance
- **Temperature Monitoring**: Tracks drive temperature during testing
- **Health Checks**: Verifies drive health after intensive testing
- **Safety Checks**: Warns about mounted drives and system drive protection
- **Detailed Results**: Saves comprehensive results to temporary files

**Sample Output:**

```bash
$ nvme-manager.sh benchmark single 2
=== NVMe Drive Benchmark - Slot 2 (/dev/nvme1n1) ===

Drive Information:
  Model: CT1000P310SSD8
  Size: 932GiB
  Serial: 25044DCAB855
  Device: /dev/nvme1n1

Running full benchmark (4GB test size, 60s duration)...

🔍 Running sequential read test...
   Sequential Read: 3,200 MB/s

📝 Running sequential write test...
   Sequential Write: 2,800 MB/s

🎲 Running random read test...
   Random Read IOPS: 485,000

🌡️ Checking drive temperature and health...
   Temperature: 42°C
   Health Status: Good

✅ Benchmark completed!
Full results saved to: /tmp/nvme-benchmark-12345/results.txt

📊 Summary:
   Sequential Read: 3,200 MB/s
   Sequential Write: 2,800 MB/s
   Random Read IOPS: 485,000
   Temperature: 42°C
   Health Status: Good
```

**Benchmark Modes:**

- **Full Mode**: 4GB test size, 60-second duration, comprehensive testing
- **Quick Mode**: 1GB test size, 30-second duration, faster results
- **Compare Mode**: Side-by-side performance comparison
- **All Drives**: Quick overview of all installed drives

**Safety Features:**

- **System Drive Protection**: Automatic write test skipping for slot 1
- **Mount Detection**: Warns if drives are mounted during testing
- **Temperature Monitoring**: Alerts if drives get too hot during testing
- **Confirmation Prompts**: Requires confirmation for write tests

## 🔍 Advanced Usage

### Automated Health Monitoring

The system automatically monitors drive health and logs warnings:

```bash
# Check system logs for health alerts
sudo journalctl -t nvme-monitor

# View recent health monitoring
sudo systemctl status nvme-health-monitor

# Check monitoring timer status
sudo systemctl list-timers nvme-health-monitor
```

### Shell Aliases

When the NVMe Manager is enabled, convenient aliases are available:

```bash
nvme-ls           # Same as nvme-list
nvme-fmt          # Same as nvme-format  
nvme-health-check # Same as nvme-health
nvme-temp         # Show just temperature info
nvme-bench        # Same as nvme-benchmark
nvme-bench-all    # Same as nvme-benchmark all
list-drives       # Show lsblk output
mount-all         # Mount all labeled drives
```

### Integration with Existing Storage Module

The NVMe Manager works alongside the existing storage module:

- **Storage Module**: Handles automatic mounting and Samba sharing
- **NVMe Manager**: Provides manual management and advanced operations
- Both modules can be enabled simultaneously
- NVMe Manager commands work with storage module mount points

### Custom Configuration

```nix
nvmeManager = {
  enable = true;
  installUtils = true;
  enableMonitoring = true;
  monitoringInterval = "30m";  # Check every 30 minutes
  
  alertThresholds = {
    temperature = 70;          # Lower temperature threshold
    availableSpare = 15;       # Higher spare threshold
  };
};
```

## 🚨 Safety Guidelines

### ⚠️ Important Warnings

1. **Slot 1 is typically your system drive** - be extremely careful with operations on `/dev/nvme0n1`
2. **Always backup important data** before formatting, cloning, or RAID operations
3. **Confirm slot numbers carefully** - wrong slot selection can destroy data
4. **Test commands on empty drives first** if you're unsure

### 🛡️ Built-in Safety Features

- **Confirmation prompts** for destructive operations
- **Drive information display** before dangerous operations
- **Automatic unmounting** to prevent filesystem corruption
- **Slot validation** to prevent invalid operations
- **Clear labeling** of system vs. data drives

### 🔧 Troubleshooting

#### Drive Not Detected

```bash
# Check if drive is physically present
lspci | grep -i nvme
lsblk

# Check dmesg for hardware issues
sudo dmesg | grep -i nvme

# Verify drive health
sudo smartctl -a /dev/nvmeXn1
```

#### Mount Issues

```bash
# Check filesystem for errors
sudo fsck /dev/nvmeXn1p1

# Check mount status
findmnt

# Manual mount
sudo mount /dev/disk/by-label/yourlabel /mnt/mountpoint
```

#### RAID Problems

```bash
# Check RAID status
cat /proc/mdstat
sudo mdadm --detail /dev/md0

# Reassemble RAID array
sudo mdadm --assemble /dev/md0 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
```

## 📚 Integration Examples

### Complete NAS Setup Workflow

```bash
# 1. Check what drives are installed
nvme-manager.sh list

# 2. Format drives for NAS use
sudo nvme-manager.sh format 2 ext4 data
sudo nvme-manager.sh format 3 ext4 backup
sudo nvme-manager.sh format 4 ext4 media

# 3. Mount all drives
sudo nvme-manager.sh mount all

# 4. Set up directory structure
sudo mkdir -p /mnt/data/{shared,documents,downloads}
sudo mkdir -p /mnt/backup/{daily,weekly,monthly}
sudo mkdir -p /mnt/media/{movies,tv,music,photos}

# 5. Set ownership for your user
sudo chown -R jager:users /mnt/{data,backup,media}

# 6. Check health regularly
nvme-manager.sh health
```

### RAID Setup Example

```bash
# Create RAID 5 for main storage (slots 2-5)
sudo nvme-manager.sh raid create 5 2 3 4 5

# Mount RAID array
sudo mkdir -p /mnt/raid
sudo mount /dev/md0 /mnt/raid

# Use slot 6 as standalone backup
sudo nvme-manager.sh format 6 ext4 backup
sudo nvme-manager.sh mount 6 /mnt/backup
```

This comprehensive NVMe management system gives you complete control over your 6-slot NAS storage while maintaining safety and ease of use.
