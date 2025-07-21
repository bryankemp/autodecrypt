# Security Guide

This guide explains the security implications, threat model, and best practices for AutoDecrypt.

## Security Model

### Overview

AutoDecrypt implements a layered security approach that balances convenience with protection:

- **Hardware Security**: TPM2 chip provides hardware-based key storage
- **Boot Integrity**: PCR binding detects unauthorized system modifications
- **Fallback Protection**: Original LUKS passphrases remain valid
- **Transparent Operation**: No changes to existing LUKS setup

### Threat Model

#### Protected Against

✅ **Software-based attacks**
- Malware cannot extract keys from TPM2
- Keys are sealed to hardware state

✅ **Boot tampering detection**
- PCR binding detects bootloader modifications
- BIOS/UEFI changes invalidate automatic unlock

✅ **Remote attacks**
- Keys never leave the TPM2 chip
- No network communication required

✅ **Drive theft (powered off)**
- Full disk encryption remains intact
- TPM2 keys tied to specific hardware

#### NOT Protected Against

⚠️ **Physical access attacks**
- Physical access to running system
- Hardware tampering with TPM2 chip
- Cold boot attacks on RAM

⚠️ **Authorized user attacks**
- Root access bypasses encryption
- Physical keyboard access during boot

⚠️ **Advanced persistent threats**
- Sophisticated hardware implants
- TPM2 chip replacement attacks

## Security Components

### TPM2 Hardware Security Module

#### Key Storage
- **Hardware-based**: Keys stored in tamper-resistant TPM2 chip
- **Non-extractable**: Keys cannot be read directly from TPM2
- **Hardware-bound**: Keys tied to specific TPM2 instance

#### Sealing Mechanism
```bash
# Keys are "sealed" to system state
# Only released when conditions match:
# 1. Same TPM2 chip
# 2. Same PCR values (if PCR binding used)
# 3. Valid authentication
```

#### Hash Algorithms
- **SHA256**: Preferred for maximum security
- **SHA1**: Fallback for older systems
- **Algorithm detection**: Automatic selection of best available

### PCR (Platform Configuration Register) Binding

#### Security Benefits
- **Boot state verification**: Detects unauthorized changes
- **Tamper resistance**: Invalid PCR values prevent unlock
- **Integrity checking**: Validates system boot path

#### PCR 7 Usage
```bash
# PCR 7 contains Secure Boot policy measurements
# Changes when:
# - BIOS/UEFI updated
# - Secure Boot settings modified
# - Boot path altered

sudo tpm2_pcrread sha256:7  # Check current value
```

#### Security vs. Compatibility Trade-off

**With PCR Binding (More Secure):**
- Detects boot tampering
- Requires reconfiguration after BIOS updates
- May fail with some hardware configurations

**Without PCR Binding (More Compatible):**
- Works across BIOS updates
- Less tampering detection
- Better hardware compatibility

### LUKS Integration

#### Keyslot Usage
AutoDecrypt uses additional LUKS keyslots without affecting existing ones:

```bash
# Example keyslot layout:
# Slot 0: Original user passphrase
# Slot 1: TPM2 binding (AutoDecrypt)
# Slots 2-7: Available for other uses
```

#### Passphrase Preservation
- Original LUKS passphrases remain unchanged
- Manual unlock always possible as fallback
- No reduction in existing security

## Security Configurations

### Maximum Security Configuration

```bash
# PCR 7 binding with SHA256
sudo clevis luks bind -d /dev/sda2 tpm2 '{
  "pcr_ids": "7",
  "hash": "sha256",
  "pcr_bank": "sha256"
}'
```

**Benefits:**
- Strongest tamper detection
- Hardware state verification
- Secure Boot integration

**Considerations:**
- Requires reconfiguration after BIOS updates
- May not work with all hardware
- More complex troubleshooting

### Balanced Configuration

```bash
# SHA256 without PCR binding
sudo clevis luks bind -d /dev/sda2 tpm2 '{
  "hash": "sha256"
}'
```

**Benefits:**
- Strong encryption
- Hardware key protection
- Better compatibility

**Considerations:**
- No boot tamper detection
- Survives BIOS updates
- Simpler maintenance

### Compatibility Configuration

```bash
# Default settings (usually SHA1)
sudo clevis luks bind -d /dev/sda2 tpm2 '{}'
```

**Benefits:**
- Maximum hardware compatibility
- Simple configuration
- Reliable operation

**Considerations:**
- Weaker hash algorithm
- No tamper detection
- Minimum security level

## Security Best Practices

### Initial Setup

1. **Enable Secure Boot** (if supported):
   ```bash
   # Check Secure Boot status
   bootctl status | grep "Secure Boot"
   
   # Enable in BIOS/UEFI if available
   ```

2. **Use strong LUKS passphrases**:
   ```bash
   # Add strong backup passphrase
   sudo cryptsetup luksAddKey /dev/sda2
   ```

3. **Document configuration**:
   ```bash
   # Save configuration details
   sudo clevis luks list -d /dev/sda2 > security-config.txt
   ```

### Operational Security

#### Regular Monitoring

```bash
# Monthly security check
./autodecrypt.sh test

# Check for PCR changes
sudo tpm2_pcrread sha256:7

# Verify keyslot integrity
sudo cryptsetup luksDump /dev/sda2
```

#### Update Procedures

```bash
# Before BIOS updates (if using PCR binding):
./autodecrypt.sh test > pre-update-status.txt

# After BIOS updates:
./autodecrypt.sh test  # Will likely fail
./autodecrypt.sh install  # Reconfigure with new PCR values
```

#### Backup Procedures

1. **LUKS header backup**:
   ```bash
   sudo cryptsetup luksHeaderBackup /dev/sda2 --header-backup-file luks-header-backup.img
   ```

2. **Configuration documentation**:
   ```bash
   # Document TPM2 settings
   sudo tpm2_getcap properties-fixed > tpm2-properties.txt
   sudo clevis luks list -d /dev/sda2 > clevis-bindings.txt
   ```

3. **Recovery preparation**:
   ```bash
   # Ensure you have LUKS passphrases available
   # Test manual unlock capability
   # Prepare recovery media with LUKS tools
   ```

### Physical Security

#### Recommendations

1. **Secure physical access** to systems using AutoDecrypt
2. **Monitor for hardware tampering** indicators
3. **Use chassis intrusion detection** if available
4. **Implement screen locks** for running systems

#### TPM2 Protection

```bash
# Check TPM2 ownership
sudo tpm2_getcap properties-fixed | grep TPM2_PT_OWNER

# Verify TPM2 is not clearable by software
sudo tpm2_getcap properties-fixed | grep TPM2_PT_LOCKOUT_COUNTER
```

## Risk Assessment

### Low Risk Scenarios

- **Home desktop/laptop** with physical security
- **Development systems** with non-sensitive data
- **Systems with strong physical access controls**

**Recommended Configuration:**
```bash
# Balanced security with PCR binding
./autodecrypt.sh install  # Uses automatic configuration
```

### Medium Risk Scenarios

- **Workplace laptops** that travel
- **Servers in shared environments**
- **Systems with occasional physical access by others**

**Recommended Configuration:**
```bash
# Maximum security with monitoring
./autodecrypt.sh install
# Plus regular monitoring and update procedures
```

### High Risk Scenarios

- **Systems with sensitive data**
- **Environments with insider threats**
- **Systems in physically insecure locations**

**Additional Measures:**
```bash
# Consider additional layers:
# - Network-based key escrow
# - Multi-factor authentication
# - Hardware security keys
# - Full system monitoring
```

## Security Limitations

### Known Limitations

1. **Physical access**: Cannot protect against physical attacks
2. **Root compromise**: Root access bypasses all protections
3. **TPM2 vulnerabilities**: Depends on TPM2 implementation security
4. **Boot process**: Vulnerable during unencrypted boot phase

### Mitigation Strategies

```bash
# Defense in depth:
# 1. Physical security measures
# 2. Access control and monitoring
# 3. Network security
# 4. Regular security updates
# 5. Incident response planning
```

### When NOT to Use AutoDecrypt

❌ **Maximum security environments**
- Where physical security cannot be guaranteed
- Systems handling classified information
- Environments with sophisticated adversaries

❌ **Compliance requirements**
- Regulations requiring manual authentication
- Standards prohibiting automatic decryption
- Audit requirements for human verification

❌ **Shared systems**
- Multi-user systems without individual TPM2 instances
- Systems where multiple users need access
- Environments without clear ownership

## Compliance Considerations

### Regulatory Frameworks

- **GDPR**: Consider data protection implications
- **HIPAA**: May require additional controls for healthcare data
- **SOX**: Financial data may need enhanced protections
- **PCI DSS**: Credit card data has specific encryption requirements

### Documentation Requirements

```bash
# Maintain security documentation:
# 1. Risk assessment results
# 2. Configuration decisions and rationale
# 3. Regular testing and monitoring procedures
# 4. Incident response procedures
```

## Advanced Security Topics

### Network Boot Security

If using network boot with AutoDecrypt:

```bash
# Consider additional protections:
# - Secure network protocols (TLS/IPSec)
# - Network access controls
# - Boot image integrity verification
```

### Virtualization Security

For virtualized environments:

```bash
# VM-specific considerations:
# - Virtual TPM2 security model
# - Hypervisor trust boundaries
# - VM migration implications
```

### Container Security

AutoDecrypt with containerized workloads:

```bash
# Container considerations:
# - Host system encryption
# - Container runtime security
# - Secret management integration
```

## Security Testing

### Regular Security Validation

```bash
#!/bin/bash
# security-test.sh - Regular security validation

echo "=== AutoDecrypt Security Test ==="

# Test basic functionality
./autodecrypt.sh test

# Verify TPM2 security
sudo tpm2_getcap properties-fixed | grep -E "(OWNER|LOCKOUT)"

# Check PCR integrity
sudo tpm2_pcrread sha256:7

# Validate keyslot usage
sudo cryptsetup luksDump /dev/sda2 | grep -A5 "Key Slot"

echo "Security test completed at $(date)"
```

### Penetration Testing Considerations

When conducting security assessments:

1. **Test boot process security**
2. **Evaluate physical access controls** 
3. **Assess TPM2 configuration**
4. **Validate recovery procedures**
5. **Review logging and monitoring**

This security guide provides a foundation for secure AutoDecrypt deployment. For specific compliance or high-security environments, consult with security professionals familiar with your requirements.
