# Installation Guide

This guide covers the installation requirements and setup process for AutoDecrypt.

## Prerequisites

### Hardware Requirements

:::{admonition} TPM2 Required
:class: warning
AutoDecrypt requires a TPM 2.0 chip enabled in your system's BIOS/UEFI settings. Without TPM2, the script cannot function.
:::

- **TPM2 chip (TPM 2.0)** enabled in BIOS/UEFI
- **LUKS-encrypted partition** (typically root filesystem)
- **Physical access** to the machine for BIOS configuration

### Software Requirements

- **Ubuntu 20.04+** or **Debian 11+** (systemd-based systems)
- **Bash 4.0+** (usually pre-installed)
- **sudo privileges** for system configuration
- **Internet connection** for package installation

### Supported Systems

| Operating System | Version | Status | Notes |
|------------------|---------|--------|--------|
| Ubuntu           | 20.04 LTS | ✅ Tested | Recommended |
| Ubuntu           | 22.04 LTS | ✅ Tested | Recommended |  
| Ubuntu           | 24.04 LTS | ✅ Compatible | Should work |
| Debian           | 11 (Bullseye) | ✅ Tested | Recommended |
| Debian           | 12 (Bookworm) | ✅ Compatible | Should work |

## Pre-Installation Setup

### 1. Enable TPM2 in BIOS/UEFI

:::{admonition} BIOS Configuration Required  
:class: important
You must enable TPM2 in your system's BIOS/UEFI before running AutoDecrypt.
:::

1. Restart your system and enter BIOS/UEFI setup
2. Navigate to Security settings
3. Find TPM/Security Device settings
4. Enable TPM 2.0 (disable TPM 1.2 if present)  
5. Save settings and reboot

### 2. Verify TPM2 Availability

After enabling TPM2, verify it's accessible:

```bash
# Check if TPM device exists
ls -la /dev/tpm*

# Install TPM2 tools (may require sudo)
sudo apt update
sudo apt install tpm2-tools

# Test TPM2 functionality
sudo tpm2_getrandom --hex 16
```

Expected output: A random hexadecimal string like `a1b2c3d4e5f6789012345678`

### 3. Verify LUKS Encryption

Confirm your system has LUKS-encrypted partitions:

```bash
# List block devices and their types
lsblk -f

# Look for crypto_LUKS filesystem types
# Example output:
# sda2    crypto_LUKS 2       12345678-abcd-...  /

# Alternative verification
sudo cryptsetup luksDump /dev/sdXY  # Replace sdXY with your partition
```

## Installation Process

### Method 1: Git Clone (Recommended)

```bash
# Clone the repository
git clone https://github.com/bryankemp/autodecrypt.git
cd autodecrypt

# Make the script executable
chmod +x autodecrypt.sh

# Run installation
./autodecrypt.sh install
```

### Method 2: Direct Download

```bash
# Download the script
wget https://github.com/bryankemp/autodecrypt/raw/main/autodecrypt.sh

# Make executable
chmod +x autodecrypt.sh

# Run installation  
./autodecrypt.sh install
```

### Method 3: Manual Setup

If you need to customize the installation:

```bash
# Download to specific location
curl -o /usr/local/bin/autodecrypt.sh \\
  https://github.com/bryankemp/autodecrypt/raw/main/autodecrypt.sh

# Set permissions
chmod +x /usr/local/bin/autodecrypt.sh

# Run from any location
autodecrypt.sh install
```

## Installation Steps

The installation process consists of these automatic steps:

### 1. Dependency Installation

AutoDecrypt automatically installs required packages:

- `clevis` - Core Clevis framework
- `clevis-luks` - LUKS integration 
- `clevis-tpm2` - TPM2 backend
- `tpm2-tools` - TPM2 utilities
- `clevis-initramfs` - Boot-time hooks

### 2. System Verification

- Verifies TPM2 functionality
- Detects LUKS partitions
- Checks existing bindings
- Validates system compatibility

### 3. TPM2 Configuration

- Detects optimal hash algorithm (SHA256 preferred, SHA1 fallback)
- Attempts PCR 7 binding for enhanced security
- Creates TPM2 key bindings with multiple fallback options

### 4. Initramfs Integration

- Updates initramfs to include Clevis hooks
- Configures boot-time decryption
- Validates hook installation

## Verification

After installation, verify the setup:

```bash
# Test the configuration
./autodecrypt.sh test

# Check binding status  
sudo clevis luks list -d /dev/sdXY  # Replace with your partition

# Verify initramfs hooks
lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis
```

## Post-Installation

### Reboot Test

:::{admonition} Important Test
:class: warning  
Always test boot functionality after installation to ensure the system starts properly.
:::

1. Reboot your system
2. Observe the boot process - you should not be prompted for disk password
3. If prompted, enter your LUKS passphrase normally (backup method)
4. After successful boot, run diagnostics

### Security Backup

Before relying on auto-decryption:

1. **Document your LUKS passphrases** - keep them secure but accessible
2. **Test manual decryption** - ensure you can still unlock manually if needed
3. **Create recovery media** - consider a rescue USB with LUKS tools
4. **Backup TPM configuration** - document your TPM settings

## Troubleshooting Installation

### Common Issues

**\"No LUKS partition detected\"**
```bash
# Check with verbose mode
./autodecrypt.sh --verbose install

# Manual verification
sudo lsblk -f | grep crypto_LUKS
```

**\"TPM2 chip not available\"**  
```bash
# Check BIOS settings are correct
ls -la /dev/tpm*

# Verify TPM2 tools work
sudo tpm2_getrandom --hex 16
```

**\"Package installation failed\"**
```bash
# Update package lists
sudo apt update

# Install manually
sudo apt install clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs
```

**\"Permission denied\"**
```bash
# Ensure script is executable
chmod +x autodecrypt.sh

# Check sudo access
sudo -l
```

### Getting Help

If installation fails:

1. Run with verbose mode: `./autodecrypt.sh --verbose install`
2. Check system logs: `journalctl -xe`
3. Verify prerequisites are met
4. Review error messages carefully
5. Consult the [troubleshooting guide](troubleshooting.md)

## Next Steps

After successful installation:

- Review the [usage guide](usage.md) for daily operations
- Understand [security implications](security.md)  
- Learn about [configuration options](configuration.md)
- Set up monitoring and maintenance procedures
