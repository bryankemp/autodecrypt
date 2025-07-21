# Examples

This guide provides practical examples for common AutoDecrypt use cases and scenarios.

## Basic Usage Examples

### Standard Installation

```bash
# Download the script
git clone https://github.com/bryankemp/autodecrypt.git
cd autodecrypt

# Make executable
chmod +x autodecrypt.sh

# Install with default settings
./autodecrypt.sh install
```

**Expected Output:**
```
[autodecrypt] INFO: Starting installation process
Installing necessary packages...
Verifying TPM2 availability...
TPM2 verification successful.
Detected LUKS partition: /dev/sda2
Creating new TPM2 binding...
PCR 7 binding successful with sha256
Auto decryption configured for /dev/sda2.
Setup complete! Your drive should now automatically unlock at boot.
```

### Testing Configuration

```bash
# Test current setup
./autodecrypt.sh test

# Test with verbose output
./autodecrypt.sh --verbose test
```

**Expected Output (Success):**
```
[autodecrypt] INFO: Starting test process
Testing current autodecrypt setup...
Detected LUKS partition: /dev/sda2
Verifying TPM2 availability...
TPM2 verification successful.
1: tpm2 '{"hash":"sha256","pcr_ids":"7"}'
Device is already unlocked (this is normal for root filesystem).
Clevis should automatically unlock this device at boot via initramfs.
Initramfs hooks appear to be properly configured.
Test complete.
```

## Environment-Specific Examples

### Laptop/Desktop Setup

```bash
# Standard home user setup
./autodecrypt.sh install

# Verify setup before traveling
./autodecrypt.sh test && echo "Ready for travel"

# Check after suspend/resume
./autodecrypt.sh --verbose test
```

### Server Deployment

```bash
# Server installation with logging
./autodecrypt.sh --verbose install 2>&1 | tee install.log

# Create monitoring script
cat > /usr/local/bin/check-autodecrypt.sh << 'EOF'
#!/bin/bash
cd /path/to/autodecrypt
if ! ./autodecrypt.sh test &>/dev/null; then
    logger -t autodecrypt "AutoDecrypt test failed"
    exit 1
fi
EOF

chmod +x /usr/local/bin/check-autodecrypt.sh

# Add to crontab for weekly monitoring
echo "0 2 * * 1 /usr/local/bin/check-autodecrypt.sh" | sudo crontab -
```

### Development Environment

```bash
# Quick setup for development
./autodecrypt.sh install

# Enable verbose logging for debugging
export VERBOSE=true
./autodecrypt.sh test
```

## Advanced Configuration Examples

### Manual Clevis Binding

```bash
# Create binding with specific configuration
sudo clevis luks bind -d /dev/sda2 tpm2 '{
  "pcr_ids": "7",
  "hash": "sha256",
  "pcr_bank": "sha256"
}'

# Create multiple bindings for redundancy
sudo clevis luks bind -d /dev/sda2 tpm2 '{"hash":"sha256"}'
sudo clevis luks bind -d /dev/sda2 tpm2 '{"hash":"sha1"}'

# Update initramfs after manual changes
sudo update-initramfs -u
```

### Multiple Partition Setup

```bash
# Configure multiple encrypted partitions
./autodecrypt.sh install  # Configures primary partition

# Manually configure additional partitions
sudo clevis luks bind -d /dev/sda3 tpm2 '{"hash":"sha256"}'
sudo clevis luks bind -d /dev/sda4 tpm2 '{"hash":"sha256"}'

# Update initramfs to include all partitions
sudo update-initramfs -u

# Test all partitions
for device in /dev/sda2 /dev/sda3 /dev/sda4; do
    echo "Testing $device:"
    sudo clevis luks unlock -d "$device" -n "test_$(basename $device)"
    sudo cryptsetup luksClose "test_$(basename $device)"
done
```

## Troubleshooting Examples

### PCR Value Changes (After BIOS Update)

```bash
# Check current PCR values
sudo tpm2_pcrread sha256:7

# Test current binding (will likely fail)
./autodecrypt.sh test

# Reconfigure with new PCR values
./autodecrypt.sh uninstall
./autodecrypt.sh install

# Verify new configuration
./autodecrypt.sh test
```

### Package Installation Issues

```bash
# Manual package installation
sudo apt update
sudo apt install -y clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs

# Verify packages are installed
dpkg -l | grep -E "(clevis|tpm2-tools)"

# Run configuration only
./autodecrypt.sh install
```

### Initramfs Hook Problems

```bash
# Check if hooks are installed
ls -la /usr/share/initramfs-tools/hooks/clevis

# Reinstall hooks
sudo apt install --reinstall clevis-initramfs

# Manual initramfs update
sudo update-initramfs -u -k all

# Verify hooks in initramfs
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis
```

## Recovery Examples

### Emergency Recovery

```bash
# If system won't boot, use live USB
# Mount the encrypted partition
sudo cryptsetup luksOpen /dev/sda2 recovery_root
sudo mount /dev/mapper/recovery_root /mnt

# Chroot and fix configuration
sudo chroot /mnt
cd /path/to/autodecrypt
./autodecrypt.sh uninstall
./autodecrypt.sh install
update-initramfs -u
exit

# Unmount and reboot
sudo umount /mnt
sudo cryptsetup luksClose recovery_root
```

### Complete Reset

```bash
# Remove all Clevis configuration
./autodecrypt.sh uninstall

# Remove packages (optional)
sudo apt remove clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs
sudo apt autoremove

# Clean installation
sudo apt update
./autodecrypt.sh install
```

## Integration Examples

### Ansible Playbook

```yaml
---
- name: Configure AutoDecrypt on servers
  hosts: encrypted_servers
  become: yes
  tasks:
    - name: Clone AutoDecrypt repository
      git:
        repo: https://github.com/bryankemp/autodecrypt.git
        dest: /opt/autodecrypt
    
    - name: Make script executable
      file:
        path: /opt/autodecrypt/autodecrypt.sh
        mode: '0755'
    
    - name: Install and configure AutoDecrypt
      command: /opt/autodecrypt/autodecrypt.sh install
      register: result
      failed_when: result.rc != 0
    
    - name: Test configuration
      command: /opt/autodecrypt/autodecrypt.sh test
      register: test_result
      failed_when: test_result.rc != 0
    
    - name: Create monitoring script
      copy:
        content: |
          #!/bin/bash
          cd /opt/autodecrypt
          if ! ./autodecrypt.sh test &>/dev/null; then
              logger -t autodecrypt "AutoDecrypt test failed on $(hostname)"
          fi
        dest: /usr/local/bin/check-autodecrypt.sh
        mode: '0755'
```

### Docker Container (Host Encryption)

```dockerfile
# Dockerfile for management container
FROM ubuntu:22.04

RUN apt-update && apt-get install -y \
    clevis \
    clevis-luks \
    clevis-tpm2 \
    tpm2-tools \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Note: This container would manage host encryption
# TPM2 device must be mounted into container
# VOLUME ["/dev/tpm0", "/dev/tpmrm0"]
```

### Systemd Service for Monitoring

```ini
# /etc/systemd/system/autodecrypt-monitor.service
[Unit]
Description=AutoDecrypt Status Monitor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/autodecrypt/autodecrypt.sh test
User=root

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/autodecrypt-monitor.timer
[Unit]
Description=Run AutoDecrypt Monitor Weekly
Requires=autodecrypt-monitor.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

## Testing Examples

### Comprehensive Test Suite

```bash
#!/bin/bash
# comprehensive-test.sh

set -e

echo "=== AutoDecrypt Comprehensive Test ==="

# Test 1: Basic functionality
echo "Test 1: Basic functionality test"
./autodecrypt.sh test

# Test 2: TPM2 functionality
echo "Test 2: TPM2 functionality"
sudo tpm2_getrandom --hex 16

# Test 3: LUKS detection
echo "Test 3: LUKS partition detection"
lsblk -f | grep crypto_LUKS

# Test 4: Clevis bindings
echo "Test 4: Clevis bindings"
LUKS_DEV=$(lsblk -o NAME,FSTYPE -n | grep crypto_LUKS | awk '{print "/dev/"$1}' | head -1)
sudo clevis luks list -d "$LUKS_DEV"

# Test 5: Initramfs hooks
echo "Test 5: Initramfs hooks"
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis

# Test 6: Unlock capability
echo "Test 6: Unlock capability"
sudo clevis luks unlock -d "$LUKS_DEV" -n autodecrypt_test
sudo cryptsetup luksClose autodecrypt_test

echo "All tests passed!"
```

### Performance Testing

```bash
#!/bin/bash
# performance-test.sh

LUKS_DEV="/dev/sda2"  # Adjust as needed
ITERATIONS=10

echo "=== AutoDecrypt Performance Test ==="

total_time=0
for i in $(seq 1 $ITERATIONS); do
    echo "Iteration $i..."
    start_time=$(date +%s.%N)
    
    sudo clevis luks unlock -d "$LUKS_DEV" -n "perf_test_$i" >/dev/null 2>&1
    sudo cryptsetup luksClose "perf_test_$i"
    
    end_time=$(date +%s.%N)
    iteration_time=$(echo "$end_time - $start_time" | bc)
    total_time=$(echo "$total_time + $iteration_time" | bc)
    
    echo "  Time: ${iteration_time}s"
done

average_time=$(echo "scale=3; $total_time / $ITERATIONS" | bc)
echo "Average unlock time: ${average_time}s"
```

## Maintenance Examples

### Backup and Restore

```bash
#!/bin/bash
# backup-config.sh

BACKUP_DIR="/backup/autodecrypt/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "Creating AutoDecrypt configuration backup..."

# Backup LUKS headers
for device in $(lsblk -o NAME -n | grep -E '^[a-z]+[0-9]+$'); do
    if cryptsetup isLuks "/dev/$device" 2>/dev/null; then
        echo "Backing up LUKS header for /dev/$device"
        sudo cryptsetup luksHeaderBackup "/dev/$device" \
            --header-backup-file "$BACKUP_DIR/luks-header-$device.img"
    fi
done

# Backup TPM2 configuration
sudo tpm2_getcap properties-fixed > "$BACKUP_DIR/tpm2-properties.txt"
sudo tpm2_pcrread > "$BACKUP_DIR/tpm2-pcr-values.txt"

# Backup Clevis configuration
for device in $(lsblk -o NAME -n | grep -E '^[a-z]+[0-9]+$'); do
    if cryptsetup isLuks "/dev/$device" 2>/dev/null; then
        sudo clevis luks list -d "/dev/$device" > "$BACKUP_DIR/clevis-bindings-$device.txt" 2>/dev/null || true
    fi
done

# Backup script configuration
cp autodecrypt.sh "$BACKUP_DIR/"

echo "Backup completed in $BACKUP_DIR"
```

### Monitoring Script

```bash
#!/bin/bash
# monitor-autodecrypt.sh

LOG_FILE="/var/log/autodecrypt-monitor.log"
ALERT_EMAIL="admin@example.com"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# Test AutoDecrypt functionality
if ./autodecrypt.sh test &>/dev/null; then
    log_message "AutoDecrypt test passed"
    exit 0
else
    log_message "AutoDecrypt test FAILED"
    
    # Send alert email
    if command -v mail >/dev/null 2>&1; then
        echo "AutoDecrypt test failed on $(hostname) at $(date)" | \
            mail -s "AutoDecrypt Alert" "$ALERT_EMAIL"
    fi
    
    # Log detailed diagnostics
    ./autodecrypt.sh --verbose test >> "$LOG_FILE" 2>&1
    
    exit 1
fi
```

These examples cover common use cases and provide templates for integrating AutoDecrypt into various environments and workflows.
