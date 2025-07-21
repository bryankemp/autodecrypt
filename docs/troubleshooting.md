# Troubleshooting Guide

This guide helps resolve common issues with AutoDecrypt installation and operation.

## Quick Diagnostics

### Check System Status

Run these commands to quickly assess your system:

```bash
# Check TPM2 functionality
sudo tpm2_getrandom --hex 16

# Check LUKS partitions
lsblk -f | grep crypto_LUKS

# Check Clevis bindings
./autodecrypt.sh test

# Check system logs
journalctl -xe | grep -E "(clevis|tpm|crypt)" | tail -20
```

## Common Issues

### Installation Issues

#### "No LUKS partition detected"

**Symptoms:**
- Script exits with message about no LUKS partitions
- Installation fails immediately

**Diagnosis:**
```bash
# Check with verbose mode
./autodecrypt.sh --verbose install

# Manual verification
sudo lsblk -f
sudo cryptsetup isLuks /dev/sda2  # Replace with your partition
```

**Solutions:**
1. **Verify LUKS encryption exists:**
   ```bash
   lsblk -f | grep crypto_LUKS
   ```

2. **Check for mapped devices:**
   ```bash
   ls -la /dev/mapper/
   ```

3. **Manual detection:**
   ```bash
   for dev in /dev/sd*[0-9]; do
       echo "Checking $dev"
       sudo cryptsetup isLuks "$dev" && echo "  LUKS found"
   done
   ```

#### "TPM2 chip not available"

**Symptoms:**
- Error about TPM2 not functioning
- Installation fails at TPM2 verification

**Diagnosis:**
```bash
# Check TPM devices
ls -la /dev/tpm*

# Test basic functionality
sudo tpm2_getrandom --hex 16
```

**Solutions:**
1. **Enable TPM2 in BIOS/UEFI:**
   - Reboot and enter BIOS setup
   - Navigate to Security settings
   - Enable TPM 2.0 (disable TPM 1.2 if present)
   - Save and reboot

2. **Install TPM2 tools:**
   ```bash
   sudo apt update
   sudo apt install tpm2-tools
   ```

3. **Check TPM2 ownership:**
   ```bash
   sudo tpm2_getcap properties-fixed | grep TPM2_CAP_
   ```

#### "Package installation failed"

**Symptoms:**
- apt install commands fail
- Missing dependencies

**Diagnosis:**
```bash
# Update package lists
sudo apt update

# Check available packages
apt search clevis
```

**Solutions:**
1. **Update system:**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

2. **Install packages manually:**
   ```bash
   sudo apt install clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs
   ```

3. **Check repository configuration:**
   ```bash
   cat /etc/apt/sources.list
   ls /etc/apt/sources.list.d/
   ```

### Runtime Issues

#### "Still prompted for password at boot"

**Symptoms:**
- Installation appears successful
- Boot process still asks for LUKS password

**Diagnosis:**
```bash
# Check bindings exist
sudo clevis luks list -d /dev/sda2  # Replace with your partition

# Check initramfs hooks
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis

# Test unlock capability
sudo clevis luks unlock -d /dev/sda2 -n test_unlock
sudo cryptsetup luksClose test_unlock
```

**Solutions:**
1. **Update initramfs:**
   ```bash
   sudo update-initramfs -u
   sudo reboot
   ```

2. **Reinstall initramfs hooks:**
   ```bash
   sudo apt install --reinstall clevis-initramfs
   sudo update-initramfs -u
   ```

3. **Check boot configuration:**
   ```bash
   # Verify GRUB configuration
   sudo update-grub
   ```

#### "Clevis unlock test failed"

**Symptoms:**
- Binding exists but unlock fails
- TPM2 appears functional

**Diagnosis:**
```bash
# Test with verbose mode
./autodecrypt.sh --verbose test

# Check PCR values
sudo tpm2_pcrread sha256:7

# Check binding details
sudo clevis luks list -d /dev/sda2
```

**Solutions:**
1. **PCR values changed (common after BIOS updates):**
   ```bash
   # Reconfigure bindings
   ./autodecrypt.sh uninstall
   ./autodecrypt.sh install
   ```

2. **TPM2 state issues:**
   ```bash
   # Clear TPM2 state (if safe to do so)
   sudo systemctl stop systemd-cryptsetup@*
   sudo tpm2_clear
   ./autodecrypt.sh install
   ```

3. **Create new binding:**
   ```bash
   # Remove problematic binding
   sudo clevis luks unbind -d /dev/sda2 -s 1  # Replace 1 with slot number
   
   # Create new binding
   sudo clevis luks bind -d /dev/sda2 tpm2 '{"hash":"sha256"}'
   ```

### System Update Issues

#### "Auto-decryption stopped working after update"

**Symptoms:**
- Previously working system now prompts for password
- Recent kernel or system updates

**Diagnosis:**
```bash
# Check kernel version changes
uname -r
ls /boot/initrd.img-*

# Check initramfs contents
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis

# Test current configuration
./autodecrypt.sh --verbose test
```

**Solutions:**
1. **Update initramfs for new kernel:**
   ```bash
   sudo update-initramfs -u -k all
   ```

2. **Reinstall clevis hooks:**
   ```bash
   sudo apt install --reinstall clevis-initramfs
   sudo update-initramfs -u
   ```

3. **Reconfigure completely:**
   ```bash
   ./autodecrypt.sh uninstall
   ./autodecrypt.sh install
   ```

#### "BIOS update broke auto-decryption"

**Symptoms:**
- Auto-decryption stopped after BIOS/UEFI update
- System boots but requires password

**Diagnosis:**
```bash
# Check PCR values (will be different after BIOS update)
sudo tpm2_pcrread sha256:7

# Test binding with new PCR values
./autodecrypt.sh test
```

**Solutions:**
1. **Reconfigure with new PCR values:**
   ```bash
   ./autodecrypt.sh install
   ```

2. **Use non-PCR binding for stability:**
   ```bash
   ./autodecrypt.sh uninstall
   # Then manually create binding without PCR
   sudo clevis luks bind -d /dev/sda2 tpm2 '{"hash":"sha256"}'
   sudo update-initramfs -u
   ```

## Advanced Troubleshooting

### System Logs Analysis

```bash
# Boot-time crypto logs
journalctl -b | grep -E "(clevis|crypt|tpm)"

# Systemd cryptsetup logs
journalctl -u systemd-cryptsetup@*

# Initramfs debug
# Add 'debug' to kernel command line in GRUB
# Check logs after reboot
```

### Manual Testing

#### Test TPM2 Operations

```bash
# Test basic TPM2 functions
sudo tpm2_getrandom --hex 32
sudo tpm2_getcap properties-fixed

# Test PCR operations
sudo tpm2_pcrread sha256:7
sudo tpm2_pcrread sha1:7
```

#### Test Clevis Operations

```bash
# Test encryption/decryption
echo "test data" | clevis encrypt tpm2 '{"hash":"sha256"}' > encrypted.dat
clevis decrypt < encrypted.dat

# Test with actual partition
sudo dd if=/dev/urandom bs=256 count=1 | sudo clevis luks bind -d /dev/sda2 tpm2 '{"hash":"sha256"}'
```

### Recovery Procedures

#### Complete Reset

```bash
# Remove all Clevis configuration
./autodecrypt.sh uninstall

# Clean package cache
sudo apt clean

# Reinstall packages
sudo apt install --reinstall clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs

# Reconfigure from scratch
./autodecrypt.sh install
```

#### Emergency Recovery

If system won't boot:

1. **Boot with live USB/recovery media**
2. **Mount encrypted partition manually:**
   ```bash
   # Enter LUKS passphrase
   sudo cryptsetup luksOpen /dev/sda2 recovery_root
   sudo mount /dev/mapper/recovery_root /mnt
   ```
3. **Chroot and fix:**
   ```bash
   sudo chroot /mnt
   update-initramfs -u
   exit
   ```
4. **Unmount and reboot:**
   ```bash
   sudo umount /mnt
   sudo cryptsetup luksClose recovery_root
   ```

### Debug Mode

Enable maximum debugging:

```bash
# Create debug script
cat > debug-autodecrypt.sh << 'EOF'
#!/bin/bash
set -x  # Enable command tracing
export VERBOSE=true
./autodecrypt.sh --verbose "$@" 2>&1 | tee debug.log
EOF

chmod +x debug-autodecrypt.sh
./debug-autodecrypt.sh test
```

## Hardware-Specific Issues

### Virtual Machines

**QEMU/KVM:**
```bash
# Ensure TPM2 emulation is enabled
# Add to QEMU command: -tpmdev emulator,id=tpm0 -device tpm-tis,tpmdev=tpm0
```

**VMware:**
- Enable "Trusted Platform Module" in VM settings
- Ensure VM hardware version supports TPM 2.0

**VirtualBox:**
- Enable "Trusted Platform Module" in System settings
- Set TPM type to "v2.0"

### Laptop-Specific

**Dell laptops:**
- Check "TPM On" and "TPM Activation" in BIOS
- Disable "TPM Clear" if enabled

**HP laptops:**
- Enable "TPM Device" in Security settings
- Set "TPM Specification Version" to 2.0

**Lenovo laptops:**
- Enable "Security Chip" in Security settings
- Set "Security Chip Selection" to "Discrete TPM"

## Getting Help

### Information to Collect

When reporting issues, include:

1. **System information:**
   ```bash
   lsb_release -a
   uname -a
   sudo tpm2_getcap properties-fixed | head -10
   ```

2. **AutoDecrypt output:**
   ```bash
   ./autodecrypt.sh --verbose test 2>&1 | tee test-output.log
   ```

3. **System logs:**
   ```bash
   journalctl -xe | grep -E "(clevis|tpm|crypt)" > system-logs.txt
   ```

### Support Channels

1. **Check documentation** - Review installation and configuration guides
2. **Search issues** - Look for similar problems in project issues
3. **Create detailed issue** - Include system info and logs
4. **Community forums** - Ubuntu/Debian forums for general Linux crypto questions

### Emergency Contacts

- **System won't boot**: Use live USB with LUKS tools
- **Lost LUKS passphrase**: Data recovery may not be possible
- **TPM2 hardware failure**: Manual password entry required

## Prevention

### Regular Maintenance

```bash
# Monthly health check
./autodecrypt.sh test

# After system updates
./autodecrypt.sh --verbose test

# Document configuration
sudo clevis luks list -d /dev/sda2 > config-backup-$(date +%Y%m%d).txt
```

### Monitoring

```bash
# Create monitoring script
cat > monitor-autodecrypt.sh << 'EOF'
#!/bin/bash
if ! ./autodecrypt.sh test &>/dev/null; then
    echo "AutoDecrypt test failed at $(date)" | mail -s "AutoDecrypt Alert" admin@example.com
fi
EOF

# Add to crontab for weekly checks
echo "0 2 * * 1 /path/to/monitor-autodecrypt.sh" | crontab -
```

This troubleshooting guide covers the most common issues. For additional help, consult the [configuration guide](configuration.md) and [security documentation](security.md).
