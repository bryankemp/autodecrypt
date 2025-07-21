# AutoDecrypt Documentation

Welcome to AutoDecrypt, a robust bash script that configures automatic LUKS decryption using TPM2 and Clevis for Ubuntu/Debian systems.

## Overview

AutoDecrypt eliminates the need to manually enter disk encryption passwords at boot time while maintaining security through TPM2 hardware security module. The script intelligently detects encrypted partitions, configures TPM2 bindings, and integrates with the system's initramfs for seamless boot-time decryption.

## Key Features

- **Automatic LUKS partition detection**: Intelligently detects encrypted partitions using multiple methods
- **TPM2 integration**: Leverages TPM2 hardware security module for secure key storage  
- **PCR binding**: Supports PCR 7 binding for enhanced security (boot state verification)
- **Flexible hash algorithms**: Supports both SHA256 and SHA1 hash algorithms
- **Robust error handling**: Comprehensive error checking and recovery mechanisms
- **Verbose logging**: Optional detailed logging for troubleshooting
- **Safe operations**: Validates existing bindings before making changes
- **Initramfs integration**: Automatically configures initramfs hooks for boot-time decryption

## Quick Start

```bash
# Make the script executable
chmod +x autodecrypt.sh

# Install and configure auto-decryption
./autodecrypt.sh install

# Test the configuration
./autodecrypt.sh test
```

## Security Model

AutoDecrypt uses a layered security approach:

- **TPM2 Hardware Security**: Keys are sealed in the TPM2 chip and only released when system integrity is verified
- **PCR Binding**: Platform Configuration Registers ensure keys are only available when boot state is unchanged
- **Fallback Compatibility**: Existing LUKS passphrases remain valid as backup authentication methods
- **Boot State Verification**: Optional PCR 7 binding detects unauthorized system modifications

## Documentation Contents

```{toctree}
:maxdepth: 2
:caption: User Guide

installation
usage
configuration
troubleshooting
```

```{toctree}
:maxdepth: 2
:caption: Reference

security
api
examples
changelog
```

```{toctree}
:maxdepth: 1
:caption: Development

contributing
license
```

## Support and Contributing

AutoDecrypt is open source and welcomes contributions. For support, please:

1. Check the [troubleshooting guide](troubleshooting.md)
2. Review the [examples](examples.md) for common use cases  
3. Test with verbose mode for detailed diagnostics
4. Report issues on the project repository

## License

AutoDecrypt is licensed under the BSD 3-Clause License. See the [license page](license.md) for full details.
