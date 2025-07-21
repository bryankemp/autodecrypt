# Configuration Guide

AutoDecrypt automatically configures optimal settings, but understanding the configuration details helps with troubleshooting and customization.

## Automatic Configuration

AutoDecrypt uses intelligent detection and configuration:

### TPM2 Hash Algorithm Detection

The script automatically detects the best available hash algorithm:

```bash
# Priority order (most secure to most compatible):
1. SHA256 with PCR 7 binding
2. SHA1 with PCR 7 binding  
3. SHA256 without PCR binding
4. SHA1 without PCR binding
5. Default TPM2 settings
```

### LUKS Partition Detection

Three methods are used to detect LUKS partitions:

1. **Filesystem type detection**: `lsblk` output analysis
2. **Mapped device detection**: Active cryptsetup mappings
3. **Direct verification**: `cryptsetup isLuks` testing

### PCR Binding Configuration

Platform Configuration Register (PCR) binding enhances security:

- **PCR 7**: Used for Secure Boot policy measurements
- **Benefits**: Detects unauthorized boot modifications
- **Limitations**: BIOS updates invalidate bindings

## Configuration Files

### System Integration

AutoDecrypt integrates with several system components:

#### Initramfs Hooks

Location: `/usr/share/initramfs-tools/hooks/clevis`

```bash
# Check if hooks are installed
ls -la /usr/share/initramfs-tools/hooks/clevis

# Verify hooks in current initramfs
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis
```

#### Systemd Integration

AutoDecrypt works with systemd's cryptsetup:

```bash
# View systemd crypto services
systemctl list-units | grep crypt

# Check specific service status
systemctl status systemd-cryptsetup@luks-*
```

### Clevis Configuration

#### Binding Storage

Clevis bindings are stored in LUKS keyslots:

```bash
# List all keyslots and bindings
sudo clevis luks list -d /dev/sda2

# Example output:
# 1: tpm2 '{"hash":"sha256","key":"ecc"}'
# 7: tpm2 '{"hash":"sha256","pcr_ids":"7"}'
```

#### TPM2 Policy Configuration

Different policy configurations used by AutoDecrypt:

**Most Secure (PCR 7 + SHA256):**
```json
{
  "pcr_ids": "7",
  "hash": "sha256",
  "pcr_bank": "sha256"
}
```

**Compatible (SHA256 only):**
```json
{
  "hash": "sha256"
}
```

**Maximum Compatibility (Default):**
```json
{}
```

## Manual Configuration

### Custom Clevis Bindings

For advanced users who need specific configurations:

#### PCR Binding with Multiple PCRs

```bash
# Bind to multiple PCRs (more restrictive)
sudo clevis luks bind -d /dev/sda2 tpm2 '{
  "pcr_ids": "0,2,7",
  "hash": "sha256"
}'
```

#### ECC Key Configuration

```bash
# Use ECC key type
sudo clevis luks bind -d /dev/sda2 tpm2 '{
  "hash": "sha256",
  "key": "ecc"
}'
```

#### RSA Key Configuration

```bash
# Use RSA key type (default)
sudo clevis luks bind -d /dev/sda2 tpm2 '{
  "hash": "sha256",
  "key": "rsa"
}'
```

### Keyslot Management

#### Viewing Keyslot Usage

```bash
# Show LUKS header with keyslot information
sudo cryptsetup luksDump /dev/sda2

# Show only Clevis bindings
sudo clevis luks list -d /dev/sda2
```

#### Manual Keyslot Operations

```bash
# Remove specific binding
sudo clevis luks unbind -d /dev/sda2 -s 1

# Test specific keyslot
sudo clevis luks unlock -d /dev/sda2 -s 1 -n test
```

## Advanced Configuration

### Custom Initramfs Configuration

#### Manual Hook Configuration

If you need to customize initramfs behavior:

```bash
# Edit hook configuration
sudo nano /etc/initramfs-tools/conf.d/clevis

# Add custom options
CLEVIS_LUKS_TIMEOUT=30
CLEVIS_LUKS_DEBUG=true
```

#### Rebuild Initramfs

```bash
# Update current kernel initramfs
sudo update-initramfs -u

# Update all kernel versions
sudo update-initramfs -u -k all
```

### TPM2 Advanced Configuration

#### Direct TPM2 Operations

```bash
# Read current PCR values
sudo tpm2_pcrread sha256:7

# Test TPM2 capabilities
sudo tpm2_getcap properties-fixed
sudo tpm2_getcap algorithms
```

#### PCR Policy Verification

```bash
# Create policy session for testing
sudo tpm2_startauthsession -S session.ctx
sudo tpm2_policypcr -S session.ctx -l sha256:7
```

### Multiple Partition Configuration

For systems with multiple encrypted partitions:

```bash
# Configure each partition separately
./autodecrypt.sh install  # Configures detected partition

# Manual configuration for additional partitions
sudo clevis luks bind -d /dev/sda3 tpm2 '{"hash":"sha256"}'
sudo clevis luks bind -d /dev/sda4 tpm2 '{"hash":"sha256"}'

# Update initramfs after manual changes
sudo update-initramfs -u
```

## Configuration Validation

### Comprehensive Testing

```bash
# Test complete configuration
./autodecrypt.sh --verbose test

# Test specific components
sudo clevis luks unlock -d /dev/sda2 -n validation_test
sudo cryptsetup luksClose validation_test
```

### Configuration Backup

```bash
# Document current configuration
sudo clevis luks list -d /dev/sda2 > clevis-config-backup.txt
sudo cryptsetup luksDump /dev/sda2 > luks-header-backup.txt
sudo tpm2_pcrread > tpm2-pcr-backup.txt
```

### Configuration Restoration

```bash
# Restore after issues
./autodecrypt.sh uninstall
./autodecrypt.sh install

# Or manual restoration
sudo clevis luks bind -d /dev/sda2 tpm2 '{"hash":"sha256"}'
sudo update-initramfs -u
```

## Environment-Specific Configuration

### Laptop/Mobile Configuration

```bash
# Standard configuration works well
./autodecrypt.sh install

# Consider suspend/resume implications
# PCR values may change with some power states
```

### Server Configuration

```bash
# Use most secure configuration
./autodecrypt.sh --verbose install

# Consider remote management needs
# Document recovery procedures for remote access
```

### Development Environment

```bash
# Standard configuration sufficient
./autodecrypt.sh install

# Enable verbose logging for troubleshooting
./autodecrypt.sh --verbose test
```

### Virtual Machine Configuration

TPM2 in VMs requires special consideration:

```bash
# Ensure VM has TPM2 enabled
# QEMU: -tpmdev emulator -device tpm-tis
# VMware: Enable TPM in VM settings
# VirtualBox: Enable TPM 2.0 in settings

# Verify TPM2 availability
sudo tpm2_getrandom --hex 16
```

## Configuration Troubleshooting

### Common Configuration Issues

**PCR Values Changed:**
```bash
# Check current PCR values
sudo tpm2_pcrread sha256:7

# Reconfigure with new values
./autodecrypt.sh install
```

**Multiple Conflicting Bindings:**
```bash
# Remove all bindings and start fresh
./autodecrypt.sh uninstall
./autodecrypt.sh install
```

**Initramfs Issues:**
```bash
# Reinstall initramfs hooks
sudo apt install --reinstall clevis-initramfs
sudo update-initramfs -u
```

### Configuration Validation Script

```bash
#!/bin/bash
# Save as validate-config.sh

echo "=== AutoDecrypt Configuration Validation ==="
echo "TPM2 Status:"
sudo tpm2_getrandom --hex 16 && echo "✓ TPM2 functional" || echo "✗ TPM2 issue"

echo -e "\nLUKS Partitions:"
lsblk -f | grep crypto_LUKS

echo -e "\nClevis Bindings:"
for dev in $(lsblk -o NAME -n | grep -E '^[a-z]+[0-9]+$'); do
    if cryptsetup isLuks "/dev/$dev" 2>/dev/null; then
        echo "Device /dev/$dev:"
        sudo clevis luks list -d "/dev/$dev" 2>/dev/null || echo "  No bindings"
    fi
done

echo -e "\nInitramfs Hooks:"
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis && echo "✓ Hooks present" || echo "✗ Missing hooks"
```

## Best Practices

### Security Best Practices

1. **Use PCR binding** when possible for enhanced security
2. **Document configuration** for recovery purposes  
3. **Test regularly** to catch configuration drift
4. **Keep backups** of LUKS headers and recovery keys

### Operational Best Practices

1. **Automate testing** with regular validation scripts
2. **Monitor TPM2 health** and PCR value changes
3. **Update documentation** after configuration changes
4. **Plan recovery procedures** for various failure scenarios

### Maintenance Best Practices

1. **Update after BIOS changes** that affect PCR values
2. **Reconfigure after major system updates** if issues arise
3. **Validate after hardware changes** that might affect TPM2
4. **Document all customizations** for future reference

## Next Steps

- Learn about [security implications](security.md) of different configurations
- Review [troubleshooting guide](troubleshooting.md) for configuration issues
- See [examples](examples.md) for specific configuration scenarios
