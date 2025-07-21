#!/bin/bash

# BSD 3-Clause License
#
# Copyright (c) 2025, Bryan Kemp
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Enhanced autodecrypt script with improved error handling and diagnostics
# This script configures automatic LUKS decryption using TPM2 and Clevis
# Author: Bryan Kemp
# Version: 1.0

# Exit on any error and treat unset variables as errors
set -euo pipefail

# Global variables
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[autodecrypt]"
VERBOSE=false

# Logging functions
log_info() {
    echo "${LOG_PREFIX} INFO: $*"
}

log_warn() {
    echo "${LOG_PREFIX} WARN: $*" >&2
}

log_error() {
    echo "${LOG_PREFIX} ERROR: $*" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "${LOG_PREFIX} DEBUG: $*" >&2
    fi
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Check if running as root (for operations that require sudo)
check_root_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root. This script should be run as a regular user with sudo privileges."
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges. You may be prompted for your password."
        sudo true || error_exit "Failed to obtain sudo privileges"
    fi
}

detect_luks_partition() {
    local luks_partition=""
    
    log_debug "Starting LUKS partition detection"
    
    # Method 1: Find LUKS partitions using filesystem type
    luks_partition=$(lsblk -o NAME,FSTYPE -n 2>/dev/null | grep crypto_LUKS | awk '{print "/dev/"$1}' | head -1 || true)
    log_debug "Method 1 result: $luks_partition"
    
    # Method 2: If that doesn't work, try to find mapped devices and get their underlying device
    if [[ -z "$luks_partition" ]]; then
        local mapped_device=$(lsblk -o NAME,TYPE -n 2>/dev/null | grep crypt | awk '{print $1}' | head -1 || true)
        if [[ -n "$mapped_device" ]]; then
            luks_partition=$(lsblk -o NAME,TYPE -n 2>/dev/null | grep -B1 "$mapped_device" | grep -v crypt | awk '{print "/dev/"$1}' | head -1 || true)
        fi
        log_debug "Method 2 result: $luks_partition"
    fi
    
    # Method 3: Use cryptsetup to find LUKS devices
    if [[ -z "$luks_partition" ]]; then
        for device in $(lsblk -o NAME -n 2>/dev/null | grep -E '^[a-z]+[0-9]+$' || true); do
            if cryptsetup isLuks "/dev/$device" 2>/dev/null; then
                luks_partition="/dev/$device"
                break
            fi
        done
        log_debug "Method 3 result: $luks_partition"
    fi
    
    # Cleanup any odd characters in the partition string
    luks_partition=$(echo "$luks_partition" | tr -d '[:space:]' | tr -d '─├└│')
    
    log_debug "Final LUKS partition: $luks_partition"
    echo "$luks_partition"
}

function check_clevis_binding {
    local luks_partition="$1"
    echo "Checking existing Clevis bindings..."
    
    if ! sudo clevis luks list -d "$luks_partition" 2>/dev/null; then
        echo "No existing Clevis bindings found."
        return 1
    fi
    return 0
}

function test_clevis_unlock {
    local luks_partition="$1"
    echo "Testing Clevis unlock capability..."
    
    # Check if device is already unlocked
    if cryptsetup status "$(basename "$luks_partition")" &>/dev/null || lsblk | grep -q "$(basename "$luks_partition")"; then
        echo "Device is already unlocked (this is normal for root filesystem)."
        echo "Clevis should automatically unlock this device at boot via initramfs."
        return 0
    fi
    
    # Create a temporary test mapping name
    local test_name="clevis_test_$(date +%s)"
    
    if sudo clevis luks unlock -d "$luks_partition" -n "$test_name" 2>/dev/null; then
        echo "Clevis unlock test successful."
        sudo cryptsetup luksClose "$test_name" 2>/dev/null
        return 0
    else
        echo "Clevis unlock test failed."
        return 1
    fi
}

function check_initramfs_hooks {
    echo "Checking initramfs hooks..."
    
    if [ ! -f "/usr/share/initramfs-tools/hooks/clevis" ]; then
        echo "WARNING: Clevis initramfs hook not found. Reinstalling clevis-initramfs..."
        sudo apt install --reinstall clevis-initramfs
    fi
    
    # Check if clevis hook is in the generated initramfs
    if ! lsinitramfs /boot/initrd.img-$(uname -r) 2>/dev/null | grep -q clevis; then
        echo "WARNING: Clevis not found in current initramfs. Will update initramfs."
        return 1
    fi
    
    echo "Initramfs hooks appear to be properly configured."
    return 0
}

function install_dependencies {
    echo "Installing necessary packages..."
    sudo apt update
    sudo apt install -y clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs
}

function detect_pcr_hash_algorithm {
    # Try SHA256 first (preferred)
    if sudo tpm2_pcrread sha256:7 2>/dev/null | grep -q "7 :"; then
        echo "sha256"
        return 0
    fi
    
    # Fall back to SHA1 if SHA256 not available
    if sudo tpm2_pcrread sha1:7 2>/dev/null | grep -q "7 :"; then
        echo "sha1"
        return 0
    fi
    
    # If neither works, return empty (no PCR binding will be used)
    echo ""
    return 1
}

function verify_tpm2 {
    echo "Verifying TPM2 availability..."
    if ! command -v tpm2_getrandom &> /dev/null; then
        echo "Error: TPM2 tools not found. Please install tpm2-tools package."
        exit 1
    fi
    
    if ! sudo tpm2_getrandom --hex 16 &> /dev/null; then
        echo "Error: TPM2 chip not available or not functioning properly."
        echo "Please ensure TPM2 is enabled in BIOS/UEFI settings."
        exit 1
    fi
    
    # Detect the best available hash algorithm for PCR 7
    echo "Detecting available PCR hash algorithms..."
    local hash_algo=$(detect_pcr_hash_algorithm)
    if [ -n "$hash_algo" ]; then
        local pcr7_value=$(sudo tpm2_pcrread $hash_algo:7 2>/dev/null | grep "7 :" | awk '{print $3}')
        if [ -n "$pcr7_value" ]; then
            echo "TPM2 PCR 7 value ($hash_algo): $pcr7_value"
        fi
        echo "Using hash algorithm: $hash_algo"
    else
        echo "Warning: Could not read PCR 7 with any hash algorithm. PCR binding may not be available."
    fi
    
    echo "TPM2 verification successful."
}

function update_initramfs {
    echo "Updating initramfs to include Clevis hooks..."
    sudo update-initramfs -u
    echo "Initramfs updated successfully."
}

function configure_auto_decrypt {
    echo "Configuring automatic decryption with TPM..."
    verify_tpm2
    luks_partition=$(detect_luks_partition)
    if [ -z "$luks_partition" ]; then
        echo "No LUKS partition detected. Exiting."
        exit 1
    fi
    echo "Detected LUKS partition: $luks_partition"
    
    # Check if there are existing bindings
    if check_clevis_binding "$luks_partition"; then
        echo "Existing Clevis bindings found. Testing unlock capability..."
        if test_clevis_unlock "$luks_partition"; then
            echo "Existing binding works. Checking initramfs..."
            if ! check_initramfs_hooks; then
                update_initramfs
            fi
        else
            echo "Existing binding failed. Removing and recreating..."
            # Remove existing bindings
            clevis_slots=$(sudo clevis luks list -d "$luks_partition" 2>/dev/null | grep -oE '^[0-9]+' | tr '\n' ' ')
            for slot in $clevis_slots; do
                echo "Removing existing binding in slot $slot..."
                sudo clevis luks unbind -d "$luks_partition" -s "$slot"
            done
        fi
    fi
    
    # Create new binding with detected hash algorithm
    echo "Creating new TPM2 binding..."
    
    # Detect the best available hash algorithm
    local hash_algo=$(detect_pcr_hash_algorithm)
    local binding_created=false
    
    if [ -n "$hash_algo" ]; then
        echo "Attempting PCR 7 binding with $hash_algo..."
        local pcr_config=$(printf '{"pcr_ids":"7","hash":"%s","pcr_bank":"%s"}' "$hash_algo" "$hash_algo")
        if sudo clevis luks bind -d "$luks_partition" tpm2 "$pcr_config"; then
            echo "PCR 7 binding successful with $hash_algo"
            binding_created=true
        else
            echo "PCR 7 binding failed with $hash_algo"
        fi
    fi
    
    # If PCR binding failed or no hash algorithm available, try without PCR binding
    if [ "$binding_created" = false ]; then
        echo "Trying without PCR binding (less secure but more compatible)..."
        # Try with SHA256 first, then SHA1 if that fails
        if sudo clevis luks bind -d "$luks_partition" tpm2 '{"hash":"sha256"}'; then
            echo "TPM2 binding successful with SHA256 (no PCR)"
            binding_created=true
        elif sudo clevis luks bind -d "$luks_partition" tpm2 '{"hash":"sha1"}'; then
            echo "TPM2 binding successful with SHA1 (no PCR)"
            binding_created=true
        elif sudo clevis luks bind -d "$luks_partition" tpm2 '{}'; then
            echo "TPM2 binding successful with default settings"
            binding_created=true
        fi
    fi
    
    # Check if any binding method worked
    if [ "$binding_created" = false ]; then
        echo "Error: Failed to create TPM2 binding with any configuration. Check TPM2 configuration."
        exit 1
    fi
    
    # Verify the binding was created
    if ! check_clevis_binding "$luks_partition"; then
        echo "Error: Binding creation appeared to succeed but no binding found."
        exit 1
    fi
    
    # Test the new binding
    if ! test_clevis_unlock "$luks_partition"; then
        echo "Error: New binding failed unlock test."
        exit 1
    fi
    
    echo "Auto decryption configured for $luks_partition."
    
    # Ensure initramfs is updated
    if ! check_initramfs_hooks; then
        update_initramfs
    fi
    
    echo ""
    echo "Setup complete! Your drive should now automatically unlock at boot."
    echo "If you still get prompted for a password, please reboot and try again."
    echo "You can test the binding by running: sudo clevis luks unlock -d $luks_partition -n test_unlock"
}

function uninstall_auto_decrypt {
    echo "Uninstalling automatic decryption..."
    luks_partition=$(detect_luks_partition)
    if [ -z "$luks_partition" ]; then
        echo "No LUKS partition detected. Exiting."
        exit 1
    fi
    echo "Detected LUKS partition: $luks_partition"
    
    # Auto-detect Clevis slots
    echo "Detecting Clevis slots..."
    clevis_slots=$(sudo clevis luks list -d "$luks_partition" 2>/dev/null | grep -oE '^[0-9]+' | tr '\n' ' ')
    
    if [ -z "$clevis_slots" ]; then
        echo "No Clevis slots found on $luks_partition. Nothing to uninstall."
        exit 0
    fi
    
    echo "Found Clevis slots: $clevis_slots"
    
    # Unbind each detected slot
    local unbind_failed=false
    for slot in $clevis_slots; do
        echo "Unbinding slot $slot..."
        if sudo clevis luks unbind -d "$luks_partition" -s "$slot"; then
            echo "Successfully unbound slot $slot"
        else
            echo "Error: Failed to unbind slot $slot"
            unbind_failed=true
        fi
    done
    
    # Check if any unbind operations failed
    if [ "$unbind_failed" = true ]; then
        echo "Error: One or more slots failed to unbind. Uninstall incomplete."
        exit 1
    fi
    
    echo "Auto decryption uninstalled for $luks_partition."
}

function test_setup {
    echo "Testing current autodecrypt setup..."
    luks_partition=$(detect_luks_partition)
    if [ -z "$luks_partition" ]; then
        echo "No LUKS partition detected. Exiting."
        exit 1
    fi
    echo "Detected LUKS partition: $luks_partition"
    
    verify_tpm2
    check_clevis_binding "$luks_partition"
    test_clevis_unlock "$luks_partition"
    check_initramfs_hooks
    
    echo "Test complete."
}

show_usage() {
    echo "Usage: $SCRIPT_NAME [OPTIONS] {install|uninstall|test}"
    echo ""
    echo "Commands:"
    echo "  install   - Install dependencies and configure auto-decryption"
    echo "  uninstall - Remove auto-decryption configuration"
    echo "  test      - Test current auto-decryption setup"
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Enable verbose output"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "This script configures automatic LUKS decryption using TPM2 and Clevis."
    echo "It requires sudo privileges to modify system configuration."
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            install|uninstall|test)
                local command="$1"
                shift
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                local command="$1"
                shift
                break
                ;;
        esac
    done
    
    # Check if command was provided
    if [[ -z "${command:-}" ]]; then
        log_error "No command specified"
        show_usage
        exit 1
    fi
    
    # Check root privileges
    check_root_privileges
    
    # Execute the requested command
    case "$command" in
        install)
            log_info "Starting installation process"
            install_dependencies
            configure_auto_decrypt
            ;;
        uninstall)
            log_info "Starting uninstallation process"
            uninstall_auto_decrypt
            ;;
        test)
            log_info "Starting test process"
            test_setup
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
