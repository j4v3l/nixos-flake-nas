# Storage Configuration for Beelink ME mini 6-Slot NAS

## 🏗️ Hardware Specifications

Based on the [Beelink ME mini N150](https://www.bee-link.com/products/beelink-me-mini-n150) specifications:

- **6x M.2 NVMe SSD slots** (supports 2230/2242/2280 form factors)
- **Up to 24TB total capacity** (6 slots × 4TB max per slot)  
- **Intel Twin Lake N150 processor** (4 cores, 4 threads, 3.6GHz boost)
- **12GB LPDDR5 4800MHz memory**
- **Built-in 64GB eMMC** (system storage)
- **Dual 2.5GbE LAN ports** for high-speed data transfer
- **WiFi 6 support**

## 📋 Storage Layout

### Slot Configuration

- **Slot 1**: System drive (eMMC 64GB or M.2 SSD) - `/dev/nvme0n1`
- **Slot 2**: Data drive 1 - `/dev/nvme1n1` → `/mnt/drive1`
- **Slot 3**: Data drive 2 - `/dev/nvme2n1` → `/mnt/drive2`
- **Slot 4**: Data drive 3 - `/dev/nvme3n1` → `/mnt/drive3`
- **Slot 5**: Data drive 4 - `/dev/nvme4n1` → `/mnt/drive4`
- **Slot 6**: Data drive 5 - `/dev/nvme5n1` → `/mnt/drive5`

### Mount Points

- **Primary Data**: `/mnt/data` (can be RAID array or single drive)
- **Individual Drives**: `/mnt/drive1` through `/mnt/drive5`
- **Samba Share**: Maps `/mnt/data` to `\\beelink-mini\data`

## ⚙️ Configuration Options

### Individual Drives (Default)

```nix
storage = {
  enable = true;
  raidLevel = null;  # No RAID, individual drives
  dataPath = "/mnt/data";
};
```

### RAID Configurations

#### RAID 0 (Stripe) - Maximum Performance

```nix
storage = {
  enable = true;
  raidLevel = "0";
  # Uses all 5 data drives in stripe for maximum speed
  # ⚠️ No redundancy - if one drive fails, all data is lost
};
```

#### RAID 1 (Mirror) - Maximum Redundancy

```nix
storage = {
  enable = true;
  raidLevel = "1";
  # Mirrors data across drives for redundancy
  # Usable capacity = 50% of total drive space
};
```

#### RAID 5 (Stripe with Parity) - Balanced

```nix
storage = {
  enable = true;
  raidLevel = "5";
  # Good balance of performance, capacity, and redundancy
  # Can survive 1 drive failure
  # Usable capacity = ~80% of total drive space
};
```

#### RAID 6 (Double Parity) - High Redundancy

```nix
storage = {
  enable = true;
  raidLevel = "6";
  # Can survive 2 drive failures
  # Usable capacity = ~60% of total drive space
};
```

## 🔧 Management Commands

### Drive Detection & Health

```bash
# List all NVMe drives
list-nvme

# Check drive health status
drive-health
nvme-health

# Monitor drive temperatures
drive-temp
nvme-temp

# Get detailed drive information
nvme-info
```

### Storage Monitoring

```bash
# Check disk usage for all drives
check-all-drives
df -h

# Monitor real-time I/O
iostat-nvme
iotop-nvme

# Check storage services
storage-status
storage-logs
```

### Navigation Shortcuts

```bash
# Quick navigation to drives
cddata    # Go to /mnt/data
cddrive1  # Go to /mnt/drive1
cddrive2  # Go to /mnt/drive2
cddrive3  # Go to /mnt/drive3
cddrive4  # Go to /mnt/drive4
cddrive5  # Go to /mnt/drive5
```

## 🛠️ Drive Setup Procedures

### 1. Initial Drive Installation

1. **Power down** the Beelink ME mini completely
2. **Open the case** and install M.2 NVMe SSDs in desired slots
3. **Secure drives** with provided screws
4. **Power on** and boot into NixOS

### 2. Drive Formatting (Manual)

```bash
# Check detected drives
sudo lsblk -f

# Format a new drive (example for nvme1n1)
sudo parted /dev/nvme1n1 mklabel gpt
sudo parted /dev/nvme1n1 mkpart primary ext4 0% 100%
sudo mkfs.ext4 -L drive1 /dev/nvme1n1p1

# The system will auto-mount labeled drives
```

### 3. RAID Setup

```bash
# Create RAID 5 array (example)
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=4 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1

# Format RAID array
sudo mkfs.ext4 -L data /dev/md0

# Update configuration to use RAID
# Edit hosts/beelink-mini/configuration.nix:
storage.raidLevel = "5";
```

## 🔍 Troubleshooting

### Drive Not Detected

```bash
# Check if drive is physically detected
sudo lspci | grep -i nvme
sudo lsblk

# Check dmesg for errors
sudo dmesg | grep -i nvme

# Verify drive health
sudo smartctl -a /dev/nvmeXn1
```

### Mount Issues

```bash
# Check filesystem errors
sudo fsck /dev/disk/by-label/drive1

# Manual mount
sudo mount /dev/disk/by-label/drive1 /mnt/drive1

# Check system logs
sudo journalctl -u storage-setup -f
```

### Performance Issues

```bash
# Check I/O scheduler (should be 'none' for NVMe)
cat /sys/block/nvme*/queue/scheduler

# Monitor I/O patterns
sudo iotop -a -o -d 2

# Test drive performance
sudo fio --name=randwrite --ioengine=libaio --iodepth=1 --rw=randwrite --bs=4k --direct=0 --size=512M --numjobs=1 --runtime=60 --group_reporting --filename=/mnt/drive1/test
```

## 📊 Performance Expectations

### Single Drive Performance (per M.2 NVMe)

- **Sequential Read**: Up to 3,500 MB/s (PCIe 3.0 x4 limit)
- **Sequential Write**: Up to 3,000 MB/s
- **Random Read IOPS**: Up to 500K
- **Random Write IOPS**: Up to 450K

### Network Transfer Rates

- **Single 2.5GbE**: Up to 312.5 MB/s theoretical
- **Dual 2.5GbE (bonded)**: Up to 625 MB/s theoretical
- **WiFi 6**: Up to 150 MB/s practical

### RAID Performance Impact

- **RAID 0**: ~5x single drive performance (high CPU usage)
- **RAID 1**: Similar to single drive (write penalty)
- **RAID 5**: ~3-4x single drive read, ~2x write
- **RAID 6**: ~3x single drive read, ~1.5x write

## ⚠️ Important Notes

### Safety Considerations

- **Always backup data** before RAID operations
- **Test configurations** thoroughly before production use
- **Monitor drive health** regularly with SMART data
- **Keep spare drives** for RAID redundancy

### Thermal Management

- The ME mini has **passive cooling** - monitor temperatures
- **Optimal operating temperature**: Below 60°C
- **Critical temperature**: Above 80°C (thermal throttling)
- Use `drive-temp` command to monitor regularly

### Power Consumption

- **Per NVMe drive**: ~2-8W depending on activity
- **Total system**: ~15-50W with all drives active
- Built-in PSU handles full 6-drive configuration

## 🔗 Related Documentation

- [Hardware Specifications](https://www.bee-link.com/products/beelink-me-mini-n150)
- [NixOS Storage Configuration](https://nixos.org/manual/nixos/stable/index.html#sec-luks-file-systems)
- [Linux RAID Setup](https://raid.wiki.kernel.org/index.php/RAID_setup)
- [NVMe Performance Tuning](https://wiki.archlinux.org/title/Solid_state_drive/NVMe)
