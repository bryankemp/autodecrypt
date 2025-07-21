# Usage Guide

This guide covers the day-to-day usage of AutoDecrypt for managing automatic LUKS decryption.

## Basic Commands

AutoDecrypt provides three main commands for system management:

### Install Command

Sets up automatic decryption for your LUKS-encrypted system:

```bash
./autodecrypt.sh install
```

This command:
- Installs required packages (clevis, tpm2-tools, etc.)
- Detects LUKS partitions automatically
- Configures TPM2 bindings with optimal security settings
- Updates initramfs for boot-time decryption
- Validates the complete setup

### Test Command

Validates your current auto-decryption configuration:

```bash
./autodecrypt.sh test
```

This command:
- Verifies TPM2 functionality
- Checks existing Clevis bindings
- Tests unlock capability
- Validates initramfs hooks
- Reports configuration status

### Uninstall Command

Removes auto-decryption configuration:

```bash
./autodecrypt.sh uninstall
```

This command:
- Detects and removes all Clevis bindings
- Preserves original LUKS passphrases
- Leaves packages installed for manual removal
- Does not modify initramfs (auto-removal on next update)

## Command Options

### Verbose Mode

Enable detailed logging for troubleshooting:

```bash
# Verbose installation
./autodecrypt.sh --verbose install
./autodecrypt.sh -v install

# Verbose testing
./autodecrypt.sh --verbose test
./autodecrypt.sh -v test

# Verbose uninstallation
./autodecrypt.sh --verbose uninstall
```

Verbose mode provides:
- Detailed LUKS partition detection attempts
- TPM2 interaction diagnostics
- Step-by-step binding creation process
- Initramfs validation details

### Help

Display usage information:

```bash
./autodecrypt.sh --help
./autodecrypt.sh -h
```

## Typical Workflows

### Initial Setup Workflow

```bash
# 1. Download and prepare the script
git clone https://github.com/bryankemp/autodecrypt.git
cd autodecrypt
chmod +x autodecrypt.sh

# 2. Install and configure
./autodecrypt.sh install

# 3. Test the configuration
./autodecrypt.sh test

# 4. Reboot to verify boot-time decryption
sudo reboot
```

### Maintenance Workflow

```bash
# Regular testing (recommended monthly)
./autodecrypt.sh test

# After system updates or BIOS changes
./autodecrypt.sh --verbose test

# If issues detected, reconfigure
./autodecrypt.sh install
```

### Recovery Workflow

```bash
# If auto-decryption stops working
./autodecrypt.sh --verbose test

# Remove and recreate bindings
./autodecrypt.sh uninstall
./autodecrypt.sh install

# Test new configuration
./autodecrypt.sh test
```

## Advanced Usage

### Manual Partition Specification

If automatic detection fails, you can work with specific partitions:

```bash
# List all block devices
lsblk -f

# Check specific partition for LUKS
sudo cryptsetup isLuks /dev/sda2

# Manually test Clevis unlock
sudo clevis luks unlock -d /dev/sda2 -n test_unlock
sudo cryptsetup luksClose test_unlock
```

### Custom TPM2 Configuration

For advanced users, you can manually configure Clevis:

```bash
# List current bindings
sudo clevis luks list -d /dev/sda2

# Manual binding with specific PCR
sudo clevis luks bind -d /dev/sda2 tpm2 '{"pcr_ids":"7","hash":"sha256"}'

# Manual binding without PCR (less secure)
sudo clevis luks bind -d /dev/sda2 tpm2 '{}'
```

### Initramfs Management

```bash
# Check current initramfs contents
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis

# Manually update initramfs
sudo update-initramfs -u

# Rebuild all initramfs images
sudo update-initramfs -u -k all
```

## Integration with System Management

### Systemd Integration

AutoDecrypt works seamlessly with systemd's cryptsetup service:

```bash
# Check cryptsetup service status
systemctl status systemd-cryptsetup@*

# View boot-time crypto logs
journalctl -u systemd-cryptsetup@*
```

### Boot Process Integration

During boot, the process follows this sequence:

1. **Initramfs loads** with Clevis hooks
2. **TPM2 is accessed** for key retrieval
3. **LUKS partition unlocked** automatically via Clevis
4. **Root filesystem mounted** without user intervention
5. **Normal boot continues** with full disk access

### Package Management

AutoDecrypt installs these packages that integrate with your system:

- **clevis**: Provides the framework
- **clevis-luks**: LUKS-specific functionality  
- **clevis-tpm2**: TPM2 backend
- **tpm2-tools**: Low-level TPM2 utilities
- **clevis-initramfs**: Boot-time integration hooks

## Best Practices

### Regular Testing

```bash
# Monthly verification
./autodecrypt.sh test

# After system updates
./autodecrypt.sh --verbose test

# Before critical reboots
./autodecrypt.sh test && echo "Ready for reboot"
```

### Backup Procedures

```bash
# Always keep LUKS passphrases available
# Test manual unlock capability
sudo cryptsetup luksOpen /dev/sda2 manual_test
# (Enter passphrase when prompted)
sudo cryptsetup luksClose manual_test
```

### Security Monitoring

```bash
# Check TPM2 PCR values
sudo tpm2_pcrread sha256:7

# Monitor for PCR changes after BIOS updates
# (Changes require reconfiguration)
```

## Common Use Cases

### Development Systems

```bash
# Quick setup for development
./autodecrypt.sh install
./autodecrypt.sh test
```

### Production Systems

```bash
# Careful setup with validation
./autodecrypt.sh --verbose install
./autodecrypt.sh --verbose test
# Document configuration
./autodecrypt.sh test > system-crypto-status.log
```

### Laptop/Workstation

```bash
# Standard setup
./autodecrypt.sh install
# Test suspend/resume functionality
# Verify works with laptop's power management
```

### Server Deployment

```bash
# Automated deployment
./autodecrypt.sh --verbose install
# Verify unattended boot capability
# Test recovery procedures
```

## Error Handling

### Common Error Responses

**Installation Errors:**
```bash
# Retry with verbose mode
./autodecrypt.sh --verbose install

# Check prerequisites
sudo tpm2_getrandom --hex 16
lsblk -f | grep crypto_LUKS
```

**Test Failures:**
```bash
# Detailed diagnostics
./autodecrypt.sh --verbose test

# Check system logs
journalctl -xe | grep -i clevis
```

**Boot Issues:**
- System will fall back to password prompt
- Enter LUKS passphrase manually
- Investigate and reconfigure after boot

### Recovery Commands

```bash
# Complete reset
./autodecrypt.sh uninstall
./autodecrypt.sh install
./autodecrypt.sh test

# Manual validation
sudo clevis luks list -d /dev/sda2
sudo clevis luks unlock -d /dev/sda2 -n test
sudo cryptsetup luksClose test
```

## Next Steps

- Learn about [security implications](security.md)
- Review [configuration options](configuration.md)  
- Check [troubleshooting guide](troubleshooting.md) for issues
- See [examples](examples.md) for specific scenarios
