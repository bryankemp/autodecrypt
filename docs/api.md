# API Reference

This document provides detailed information about AutoDecrypt's internal functions and interfaces.

## Script Interface

### Command Line Interface

#### Synopsis
```bash
./autodecrypt.sh [OPTIONS] {install|uninstall|test}
```

#### Commands

##### install
Installs dependencies and configures automatic LUKS decryption.

```bash
./autodecrypt.sh install
```

**Process:**
1. Checks prerequisites (sudo access, TPM2 availability)
2. Installs required packages
3. Detects LUKS partitions
4. Configures TPM2 bindings
5. Updates initramfs
6. Validates configuration

**Exit Codes:**
- `0`: Success
- `1`: General error (missing dependencies, LUKS detection failure, etc.)

##### test
Tests current auto-decryption configuration.

```bash
./autodecrypt.sh test
```

**Process:**
1. Verifies TPM2 functionality
2. Checks existing Clevis bindings
3. Tests unlock capability
4. Validates initramfs hooks

**Exit Codes:**
- `0`: All tests passed
- `1`: One or more tests failed

##### uninstall
Removes auto-decryption configuration.

```bash
./autodecrypt.sh uninstall
```

**Process:**
1. Detects LUKS partitions
2. Identifies Clevis bindings
3. Removes all Clevis bindings
4. Preserves original LUKS passphrases

**Exit Codes:**
- `0`: Success
- `1`: Error during uninstall process

#### Options

##### --verbose, -v
Enables verbose output for debugging.

```bash
./autodecrypt.sh --verbose install
./autodecrypt.sh -v test
```

**Output:** Detailed logging of all operations including:
- LUKS partition detection attempts
- TPM2 interaction details
- Binding creation process
- Error diagnostics

##### --help, -h
Displays usage information.

```bash
./autodecrypt.sh --help
./autodecrypt.sh -h
```

**Output:** Command syntax, available options, and basic usage examples.

## Internal Functions

### Core Functions

#### detect_luks_partition()
Detects LUKS-encrypted partitions using multiple methods.

**Returns:** Path to detected LUKS partition (e.g., `/dev/sda2`)

**Detection Methods:**
1. **Filesystem type detection**: Uses `lsblk` to find crypto_LUKS filesystems
2. **Mapped device detection**: Finds currently mounted encrypted devices  
3. **Direct cryptsetup verification**: Tests each block device with `cryptsetup isLuks`

**Example Output:**
```bash
/dev/sda2
```

#### verify_tpm2()
Verifies TPM2 chip availability and functionality.

**Process:**
1. Checks for `tpm2_getrandom` command availability
2. Tests TPM2 random number generation
3. Detects available hash algorithms
4. Reports PCR 7 values if available

**Exit on Error:** Script terminates if TPM2 is not functional

#### detect_pcr_hash_algorithm()
Detects the best available hash algorithm for PCR operations.

**Returns:** Hash algorithm string (`sha256`, `sha1`, or empty)

**Priority Order:**
1. SHA256 (preferred)
2. SHA1 (fallback)
3. Empty (no PCR binding available)

**Example Usage:**
```bash
local hash_algo=$(detect_pcr_hash_algorithm)
if [ -n "$hash_algo" ]; then
    echo "Using hash algorithm: $hash_algo"
fi
```

### Configuration Functions

#### configure_auto_decrypt()
Main configuration function that sets up automatic decryption.

**Process:**
1. Calls `verify_tpm2()`
2. Calls `detect_luks_partition()`
3. Checks existing bindings with `check_clevis_binding()`
4. Creates new TPM2 bindings
5. Updates initramfs with `update_initramfs()`

**Binding Priority:**
1. PCR 7 + SHA256 (most secure)
2. PCR 7 + SHA1 (fallback)
3. SHA256 only (compatible)
4. SHA1 only (maximum compatibility)
5. Default settings (last resort)

#### check_clevis_binding()
Checks for existing Clevis bindings on a LUKS partition.

**Parameters:**
- `$1`: LUKS partition path (e.g., `/dev/sda2`)

**Returns:**
- `0`: Bindings found
- `1`: No bindings found

**Example:**
```bash
if check_clevis_binding "/dev/sda2"; then
    echo "Existing bindings found"
fi
```

#### test_clevis_unlock()
Tests Clevis unlock capability for a LUKS partition.

**Parameters:**
- `$1`: LUKS partition path

**Process:**
1. Checks if device is already unlocked
2. Creates temporary mapping for testing
3. Attempts unlock with Clevis
4. Cleans up test mapping

**Returns:**
- `0`: Unlock test successful
- `1`: Unlock test failed

### Utility Functions

#### check_root_privileges()
Verifies sudo access and warns if running as root.

**Process:**
1. Checks if running as root (not recommended)
2. Tests sudo access with `sudo -n true`
3. Prompts for password if needed

#### update_initramfs()
Updates initramfs to include Clevis hooks.

**Command:** `sudo update-initramfs -u`

**Purpose:** Ensures boot-time decryption capability

#### check_initramfs_hooks()
Verifies Clevis hooks are properly installed in initramfs.

**Process:**
1. Checks for `/usr/share/initramfs-tools/hooks/clevis`
2. Verifies hooks are in current initramfs
3. Reinstalls `clevis-initramfs` if needed

**Returns:**
- `0`: Hooks properly configured
- `1`: Hooks missing or need updating

### Logging Functions

#### log_info(message)
Outputs informational messages.

**Format:** `[autodecrypt] INFO: message`

**Example:**
```bash
log_info "Starting installation process"
```

#### log_warn(message)
Outputs warning messages to stderr.

**Format:** `[autodecrypt] WARN: message`

**Example:**
```bash
log_warn "Running as root. This script should be run as a regular user with sudo privileges."
```

#### log_error(message)
Outputs error messages to stderr.

**Format:** `[autodecrypt] ERROR: message`

**Example:**
```bash
log_error "TPM2 chip not available"
```

#### log_debug(message)
Outputs debug messages when verbose mode is enabled.

**Format:** `[autodecrypt] DEBUG: message`

**Example:**
```bash
log_debug "Method 1 result: /dev/sda2"
```

## Configuration Parameters

### TPM2 Policy Configurations

#### Maximum Security
```json
{
  "pcr_ids": "7",
  "hash": "sha256",
  "pcr_bank": "sha256"
}
```

#### Balanced Security
```json
{
  "hash": "sha256"
}
```

#### Maximum Compatibility
```json
{}
```

### Global Variables

#### SCRIPT_NAME
- **Type:** String
- **Value:** `$(basename "$0")`
- **Usage:** Script identification in logs

#### LOG_PREFIX
- **Type:** String  
- **Value:** `"[autodecrypt]"`
- **Usage:** Consistent log message formatting

#### VERBOSE
- **Type:** Boolean
- **Default:** `false`
- **Usage:** Controls debug output level

## External Dependencies

### Required Commands

#### System Commands
- `sudo`: Privilege escalation
- `lsblk`: Block device listing
- `cryptsetup`: LUKS operations
- `update-initramfs`: Initramfs management

#### TPM2 Commands
- `tpm2_getrandom`: TPM2 functionality testing
- `tpm2_pcrread`: PCR value reading
- `tpm2_getcap`: TPM2 capability query

#### Clevis Commands
- `clevis`: Core Clevis operations
- `clevis luks bind`: Create LUKS bindings
- `clevis luks unbind`: Remove LUKS bindings
- `clevis luks list`: List existing bindings
- `clevis luks unlock`: Test unlock functionality

### Required Packages

#### APT Packages
- `clevis`: Core framework
- `clevis-luks`: LUKS integration
- `clevis-tpm2`: TPM2 backend
- `tpm2-tools`: TPM2 utilities
- `clevis-initramfs`: Boot-time hooks

## Error Handling

### Exit Codes

| Code | Meaning | Context |
|------|---------|---------|
| 0    | Success | All operations completed successfully |
| 1    | General Error | Various failure conditions |

### Error Categories

#### Prerequisites Errors
- Missing sudo privileges
- TPM2 chip not available
- No LUKS partitions detected
- Package installation failures

#### Configuration Errors
- TPM2 binding creation failures
- Initramfs update failures
- Existing binding conflicts

#### Runtime Errors
- Clevis unlock test failures
- PCR value mismatches
- System state inconsistencies

### Error Recovery

#### Automatic Recovery
- Multiple detection methods for LUKS partitions
- Fallback hash algorithms for TPM2
- Multiple binding configuration attempts

#### Manual Recovery
- Complete uninstall and reinstall
- Manual binding creation
- System reset procedures

## Integration Points

### System Integration

#### Systemd
- Works with `systemd-cryptsetup` service
- Integrates with boot process
- Supports multiple encrypted devices

#### Initramfs
- Uses standard initramfs-tools hooks
- Compatible with update-initramfs
- Supports kernel updates

#### APT Package Manager
- Automatic dependency resolution
- Standard package installation
- Upgrade compatibility

### Hardware Integration

#### TPM2 Chip
- Direct hardware communication
- PCR binding support
- Multiple hash algorithm support

#### LUKS Encryption
- Keyslot management
- Multiple authentication methods
- Header preservation

This API reference provides the technical foundation for understanding, extending, and integrating with AutoDecrypt.
