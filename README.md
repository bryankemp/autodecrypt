# AutoDecrypt - Automatic LUKS Decryption with TPM2

A robust bash script that configures automatic LUKS decryption using TPM2 and Clevis for Ubuntu/Debian systems. This script eliminates the need to manually enter disk encryption passwords at boot time while maintaining security through TPM2 hardware security module.

## Author

**Bryan Kemp**  
Licensed under the BSD 3-Clause License

## Features

- **Automatic LUKS partition detection**: Intelligently detects encrypted partitions using multiple methods
- **TPM2 integration**: Leverages TPM2 hardware security module for secure key storage
- **PCR binding**: Supports PCR 7 binding for enhanced security (boot state verification)
- **Flexible hash algorithms**: Supports both SHA256 and SHA1 hash algorithms
- **Robust error handling**: Comprehensive error checking and recovery mechanisms
- **Verbose logging**: Optional detailed logging for troubleshooting
- **Safe operations**: Validates existing bindings before making changes
- **Initramfs integration**: Automatically configures initramfs hooks for boot-time decryption

## Prerequisites

### Hardware Requirements
- TPM2 chip (TPM 2.0) enabled in BIOS/UEFI
- LUKS-encrypted partition (typically root filesystem)

### Software Requirements
- Ubuntu 20.04+ or Debian 11+ (systemd-based systems)
- Bash 4.0+
- sudo privileges
- Internet connection for package installation

### Security Considerations
- **TPM2 must be enabled** in BIOS/UEFI settings
- **Secure Boot** recommended but not required
- **Physical security** of the machine is important (TPM2 protects against software attacks, not physical theft)
- **Backup your LUKS keys** before running this script

## Installation

1. **Clone or download the script**:
   ```bash
   git clone <repository-url>
   cd autodecrypt
   ```

2. **Make the script executable**:
   ```bash
   chmod +x autodecrypt.sh
   ```

3. **Run the installation**:
   ```bash
   ./autodecrypt.sh install
   ```

## Usage

### Basic Commands

```bash
# Install dependencies and configure auto-decryption
./autodecrypt.sh install

# Test current auto-decryption setup
./autodecrypt.sh test

# Remove auto-decryption configuration
./autodecrypt.sh uninstall

# Show help
./autodecrypt.sh --help
```

### Advanced Options

```bash
# Enable verbose logging
./autodecrypt.sh --verbose install

# Verbose testing
./autodecrypt.sh -v test
```

## How It Works

### TPM2 and Clevis Integration

The script uses [Clevis](https://github.com/latchset/clevis) with TPM2 backend to:

1. **Detect LUKS partitions** using multiple detection methods
2. **Verify TPM2 availability** and functionality
3. **Create TPM2 bindings** with optional PCR (Platform Configuration Register) binding
4. **Update initramfs** to include Clevis hooks for boot-time decryption
5. **Test the configuration** to ensure it works properly

### Security Model

- **TPM2 stores encryption keys** sealed to the current system state
- **PCR 7 binding** (when available) ensures keys are only released when boot state is unchanged
- **Fallback mechanisms** provide compatibility with various TPM2 configurations
- **Existing passphrases remain valid** as backup authentication methods

### Detection Methods

The script uses three methods to detect LUKS partitions:

1. **Filesystem type detection**: Uses `lsblk` to find crypto_LUKS filesystems
2. **Mapped device detection**: Finds currently mounted encrypted devices
3. **Direct cryptsetup verification**: Tests each block device with `cryptsetup isLuks`

## Configuration Details

### TPM2 Configuration

The script automatically detects and configures:

- **Hash algorithms**: Prefers SHA256, falls back to SHA1
- **PCR binding**: Attempts PCR 7 binding for enhanced security
- **Fallback options**: Multiple configuration attempts for maximum compatibility

### Clevis Configuration

Clevis bindings are created with these priority levels:

1. **PCR 7 + SHA256**: Most secure option
2. **PCR 7 + SHA1**: Fallback for older systems
3. **SHA256 only**: Compatible but less secure
4. **SHA1 only**: Maximum compatibility
5. **Default settings**: Last resort configuration

## Troubleshooting

### Common Issues

**"No LUKS partition detected"**
- Ensure you have an encrypted partition
- Run with `-v` flag to see detection attempts
- Manually verify with `sudo cryptsetup luksDump /dev/sdXY`

**"TPM2 chip not available"**
- Enable TPM2 in BIOS/UEFI settings
- Verify with `sudo tpm2_getrandom --hex 16`
- Check if TPM2 is accessible: `ls -la /dev/tpm*`

**"Clevis unlock test failed"**
- Verify TPM2 is functioning properly
- Check if PCR values have changed (after BIOS updates)
- Run `sudo clevis luks list -d /dev/sdXY` to see existing bindings

**"Still prompted for password at boot"**
- Ensure initramfs was updated successfully
- Reboot and check for error messages
- Verify Clevis hooks: `lsinitramfs /boot/initrd.img-$(uname -r) | grep clevis`

### Verbose Mode

Use the `-v` or `--verbose` flag to enable detailed logging:

```bash
./autodecrypt.sh --verbose test
```

This provides additional information about:
- LUKS partition detection attempts
- TPM2 interaction details
- Clevis binding creation process
- Initramfs hook verification

### Manual Testing

Test your configuration manually:

```bash
# List current bindings
sudo clevis luks list -d /dev/sdXY

# Test unlock (replace sdXY with your partition)
sudo clevis luks unlock -d /dev/sdXY -n test_unlock

# Clean up test
sudo cryptsetup luksClose test_unlock
```

## Security Implications

### Benefits
- **Eliminates manual password entry** at boot time
- **Maintains encryption security** through TPM2 hardware
- **Detects system tampering** (when using PCR binding)
- **Preserves existing authentication** methods as backup

### Considerations
- **Physical security** is crucial - TPM2 doesn't protect against physical attacks
- **BIOS/UEFI updates** may require reconfiguration due to PCR changes
- **TPM2 failure** would require manual password entry
- **Backup recovery methods** should be tested and documented

### Best Practices
1. **Keep existing LUKS passphrases** as backup
2. **Test recovery procedures** before relying on auto-decryption
3. **Monitor system for TPM2 health** and functionality
4. **Document configuration** for recovery purposes
5. **Consider additional security layers** like Secure Boot

## Recovery Procedures

### If Auto-Decryption Fails
1. **Boot normally** and enter your LUKS passphrase manually
2. **Check TPM2 status**: `sudo tpm2_getrandom --hex 16`
3. **Test existing bindings**: `./autodecrypt.sh test`
4. **Reconfigure if needed**: `./autodecrypt.sh install`

### Complete Removal
```bash
# Remove all Clevis bindings
./autodecrypt.sh uninstall

# Optional: Remove packages (if not needed for other purposes)
sudo apt remove clevis clevis-luks clevis-tpm2 clevis-initramfs
```

## Dependencies

The script automatically installs these packages:
- `clevis`: Core Clevis framework
- `clevis-luks`: LUKS integration for Clevis
- `clevis-tpm2`: TPM2 backend for Clevis
- `tpm2-tools`: TPM2 utilities
- `clevis-initramfs`: Initramfs hooks for boot-time decryption

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the BSD 3-Clause License. See the license header in the script for full details.

## Changelog

### Version 1.0
- Initial release
- Multi-method LUKS detection
- TPM2 integration with PCR binding
- Comprehensive error handling
- Verbose logging support
- Automatic initramfs configuration

## Support

For issues and questions:
1. Check the troubleshooting section
2. Run with verbose mode for detailed logs
3. Review system logs: `journalctl -u systemd-cryptsetup@*`
4. Test TPM2 functionality independently

## Acknowledgments

- [Clevis project](https://github.com/latchset/clevis) for the TPM2 integration framework
- [tpm2-tools](https://github.com/tpm2-software/tpm2-tools) for TPM2 utilities
- Ubuntu/Debian communities for cryptsetup and initramfs integration
