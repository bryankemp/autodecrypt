# Example Configurations

This file provides example configurations and real-world scenarios for AutoDecrypt deployment.

## Basic Home Setup

```bash
#!/bin/bash
# home-setup.sh - Simple home user setup

# Download and install
git clone https://github.com/bryankemp/autodecrypt.git
cd autodecrypt
chmod +x autodecrypt.sh

# Install with defaults
./autodecrypt.sh install

# Test configuration
./autodecrypt.sh test

echo "Home setup complete!"
```

## Enterprise Server Setup

```bash
#!/bin/bash
# enterprise-setup.sh - Enterprise server deployment

# Logging setup
LOG_FILE="/var/log/autodecrypt-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "Starting AutoDecrypt enterprise deployment at $(date)"

# Pre-flight checks
echo "Performing pre-flight checks..."

# Check TPM2 availability
if ! sudo tpm2_getrandom --hex 16 &>/dev/null; then
    echo "ERROR: TPM2 not available"
    exit 1
fi

# Check LUKS partitions
if ! lsblk -f | grep -q crypto_LUKS; then
    echo "ERROR: No LUKS partitions found"
    exit 1
fi

# Install AutoDecrypt
echo "Installing AutoDecrypt..."
git clone https://github.com/bryankemp/autodecrypt.git /opt/autodecrypt
cd /opt/autodecrypt
chmod +x autodecrypt.sh

# Install with verbose logging
./autodecrypt.sh --verbose install 2>&1 | tee -a "$LOG_FILE"

# Validate installation
echo "Validating installation..."
./autodecrypt.sh --verbose test 2>&1 | tee -a "$LOG_FILE"

# Create monitoring
cat > /usr/local/bin/autodecrypt-monitor.sh << 'EOF'
#!/bin/bash
cd /opt/autodecrypt
if ! ./autodecrypt.sh test &>/dev/null; then
    logger -t autodecrypt "ALERT: AutoDecrypt test failed on $(hostname)"
    echo "AutoDecrypt failure on $(hostname) at $(date)" | \
        mail -s "AutoDecrypt Alert" ops@company.com
fi
EOF

chmod +x /usr/local/bin/autodecrypt-monitor.sh

# Add to crontab
echo "0 6 * * * /usr/local/bin/autodecrypt-monitor.sh" | crontab -

echo "Enterprise setup complete at $(date)"
```

## Development Environment

```bash
#!/bin/bash
# dev-setup.sh - Development environment setup

# Quick installation for development
./autodecrypt.sh install

# Enable debug mode for troubleshooting
export VERBOSE=true

# Create development testing script
cat > test-dev.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Development Test Suite ==="

# Test basic functionality
./autodecrypt.sh test

# Test with verbose output
./autodecrypt.sh --verbose test

# Manual validation
echo "Manual validation checks:"
echo "1. TPM2 status:"
sudo tpm2_getrandom --hex 16

echo "2. LUKS partitions:"
lsblk -f | grep crypto_LUKS

echo "3. Clevis bindings:"
LUKS_DEV=$(lsblk -o NAME,FSTYPE -n | grep crypto_LUKS | awk '{print "/dev/"$1}' | head -1)
sudo clevis luks list -d "$LUKS_DEV"

echo "Development tests complete!"
EOF

chmod +x test-dev.sh
```

## Multiple Partition Configuration

```bash
#!/bin/bash
# multi-partition-setup.sh

echo "Configuring multiple encrypted partitions..."

# Configure primary partition with AutoDecrypt
./autodecrypt.sh install

# Configure additional partitions manually
ADDITIONAL_PARTITIONS=("/dev/sda3" "/dev/sda4" "/dev/sdb1")

for partition in "${ADDITIONAL_PARTITIONS[@]}"; do
    if cryptsetup isLuks "$partition" 2>/dev/null; then
        echo "Configuring $partition..."
        sudo clevis luks bind -d "$partition" tpm2 '{"hash":"sha256"}'
        echo "Configured $partition"
    else
        echo "Skipping $partition (not LUKS encrypted)"
    fi
done

# Update initramfs to include all partitions
sudo update-initramfs -u

echo "Multiple partition configuration complete!"
```

## High Security Configuration

```bash
#!/bin/bash
# high-security-setup.sh

echo "Setting up high-security AutoDecrypt configuration..."

# Install with default settings first
./autodecrypt.sh install

# Get the LUKS partition
LUKS_PARTITION=$(lsblk -o NAME,FSTYPE -n | grep crypto_LUKS | awk '{print "/dev/"$1}' | head -1)

# Remove default binding and create high-security binding
echo "Upgrading to high-security configuration..."
sudo clevis luks unbind -d "$LUKS_PARTITION" -s 1

# Create PCR 7 binding with SHA256
sudo clevis luks bind -d "$LUKS_PARTITION" tpm2 '{
  "pcr_ids": "7",
  "hash": "sha256",
  "pcr_bank": "sha256"
}'

# Update initramfs
sudo update-initramfs -u

# Test configuration
./autodecrypt.sh test

# Create security monitoring script
cat > /usr/local/bin/security-check.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/autodecrypt-security.log"

log_security() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# Check TPM2 PCR values
CURRENT_PCR=$(sudo tpm2_pcrread sha256:7 | grep "7 :" | awk '{print $3}')
EXPECTED_PCR_FILE="/etc/autodecrypt/expected-pcr7.txt"

if [[ -f "$EXPECTED_PCR_FILE" ]]; then
    EXPECTED_PCR=$(cat "$EXPECTED_PCR_FILE")
    if [[ "$CURRENT_PCR" != "$EXPECTED_PCR" ]]; then
        log_security "ALERT: PCR 7 value changed from $EXPECTED_PCR to $CURRENT_PCR"
        echo "PCR 7 change detected on $(hostname)" | mail -s "Security Alert" security@company.com
    fi
else
    # First run - store current PCR value
    mkdir -p /etc/autodecrypt
    echo "$CURRENT_PCR" > "$EXPECTED_PCR_FILE"
    log_security "Initial PCR 7 value stored: $CURRENT_PCR"
fi

# Test AutoDecrypt functionality
if ! /opt/autodecrypt/autodecrypt.sh test &>/dev/null; then
    log_security "ALERT: AutoDecrypt test failed"
fi
EOF

chmod +x /usr/local/bin/security-check.sh

echo "High-security configuration complete!"
```

## Recovery Configuration

```bash
#!/bin/bash
# recovery-setup.sh - Set up recovery procedures

BACKUP_DIR="/backup/autodecrypt/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "Setting up recovery configuration..."

# Create comprehensive backup script
cat > "$BACKUP_DIR/backup-crypto-config.sh" << 'EOF'
#!/bin/bash
# Comprehensive backup of crypto configuration

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/autodecrypt/$BACKUP_DATE"
mkdir -p "$BACKUP_DIR"

echo "Creating crypto configuration backup..."

# Backup LUKS headers for all encrypted partitions
for device in $(lsblk -o NAME -n | grep -E '^[a-z]+[0-9]+$'); do
    if cryptsetup isLuks "/dev/$device" 2>/dev/null; then
        echo "Backing up LUKS header for /dev/$device"
        sudo cryptsetup luksHeaderBackup "/dev/$device" \
            --header-backup-file "$BACKUP_DIR/luks-header-$device.img"
    fi
done

# Backup TPM2 configuration
echo "Backing up TPM2 configuration..."
sudo tpm2_getcap properties-fixed > "$BACKUP_DIR/tpm2-properties.txt"
sudo tpm2_pcrread > "$BACKUP_DIR/tpm2-pcr-values.txt"

# Backup Clevis bindings
echo "Backing up Clevis bindings..."
for device in $(lsblk -o NAME -n | grep -E '^[a-z]+[0-9]+$'); do
    if cryptsetup isLuks "/dev/$device" 2>/dev/null; then
        sudo clevis luks list -d "/dev/$device" > "$BACKUP_DIR/clevis-bindings-$device.txt" 2>/dev/null || true
    fi
done

# Backup AutoDecrypt script and configuration
cp /opt/autodecrypt/autodecrypt.sh "$BACKUP_DIR/"

# Create restore script
cat > "$BACKUP_DIR/restore-instructions.md" << 'RESTORE_EOF'
# Recovery Instructions

## Emergency Recovery (System won't boot)

1. Boot from live USB/rescue media
2. Mount encrypted partition:
   ```
   sudo cryptsetup luksOpen /dev/sdXY recovery_root
   sudo mount /dev/mapper/recovery_root /mnt
   ```
3. Chroot and fix:
   ```
   sudo chroot /mnt
   /opt/autodecrypt/autodecrypt.sh uninstall
   /opt/autodecrypt/autodecrypt.sh install
   update-initramfs -u
   exit
   ```
4. Unmount and reboot:
   ```
   sudo umount /mnt
   sudo cryptsetup luksClose recovery_root
   ```

## Configuration Recovery

1. Remove existing configuration:
   ```
   /opt/autodecrypt/autodecrypt.sh uninstall
   ```
2. Reinstall:
   ```
   /opt/autodecrypt/autodecrypt.sh install
   ```

## LUKS Header Restore (if needed)

**WARNING: This will overwrite current LUKS header!**
```
sudo cryptsetup luksHeaderRestore /dev/sdXY --header-backup-file luks-header-sdXY.img
```
RESTORE_EOF

echo "Backup completed in $BACKUP_DIR"
echo "Recovery instructions created: $BACKUP_DIR/restore-instructions.md"
EOF

chmod +x "$BACKUP_DIR/backup-crypto-config.sh"

# Create automated recovery testing
cat > /usr/local/bin/test-recovery.sh << 'EOF'
#!/bin/bash
# Test recovery procedures

echo "Testing AutoDecrypt recovery procedures..."

# Test 1: Configuration test
echo "Test 1: Basic configuration test"
if /opt/autodecrypt/autodecrypt.sh test; then
    echo "✓ Basic test passed"
else
    echo "✗ Basic test failed"
fi

# Test 2: Verbose diagnostics
echo "Test 2: Detailed diagnostics"
/opt/autodecrypt/autodecrypt.sh --verbose test > /tmp/autodecrypt-diag.log 2>&1
echo "Diagnostics saved to /tmp/autodecrypt-diag.log"

# Test 3: Manual unlock test
echo "Test 3: Manual unlock capability"
LUKS_DEV=$(lsblk -o NAME,FSTYPE -n | grep crypto_LUKS | awk '{print "/dev/"$1}' | head -1)
if sudo clevis luks unlock -d "$LUKS_DEV" -n recovery_test 2>/dev/null; then
    echo "✓ Manual unlock successful"
    sudo cryptsetup luksClose recovery_test
else
    echo "✗ Manual unlock failed"
fi

echo "Recovery test complete"
EOF

chmod +x /usr/local/bin/test-recovery.sh

echo "Recovery configuration setup complete!"
echo "Backup directory: $BACKUP_DIR"
echo "Run recovery test: /usr/local/bin/test-recovery.sh"
```

These example configurations cover various deployment scenarios and provide templates for different use cases.
