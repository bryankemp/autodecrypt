#!/bin/bash

# Test suite for AutoDecrypt
# This script provides basic testing functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUTODECRYPT_SCRIPT="$PROJECT_ROOT/autodecrypt.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test: Script exists and is executable
test_script_exists() {
    log_test "Checking if autodecrypt.sh exists and is executable"
    
    if [[ -f "$AUTODECRYPT_SCRIPT" ]]; then
        log_pass "Script exists at $AUTODECRYPT_SCRIPT"
    else
        log_fail "Script not found at $AUTODECRYPT_SCRIPT"
        return 1
    fi
    
    if [[ -x "$AUTODECRYPT_SCRIPT" ]]; then
        log_pass "Script is executable"
    else
        log_fail "Script is not executable"
        return 1
    fi
}

# Test: Help option works
test_help_option() {
    log_test "Testing help option"
    
    if "$AUTODECRYPT_SCRIPT" --help >/dev/null 2>&1; then
        log_pass "Help option works"
    else
        log_fail "Help option failed"
        return 1
    fi
}

# Test: Invalid option handling
test_invalid_option() {
    log_test "Testing invalid option handling"
    
    if "$AUTODECRYPT_SCRIPT" --invalid-option >/dev/null 2>&1; then
        log_fail "Script should reject invalid options"
        return 1
    else
        log_pass "Invalid options properly rejected"
    fi
}

# Test: No command specified
test_no_command() {
    log_test "Testing no command specified"
    
    if "$AUTODECRYPT_SCRIPT" >/dev/null 2>&1; then
        log_fail "Script should require a command"
        return 1
    else
        log_pass "Script properly requires a command"
    fi
}

# Test: Script syntax
test_script_syntax() {
    log_test "Testing script syntax with bash -n"
    
    if bash -n "$AUTODECRYPT_SCRIPT" >/dev/null 2>&1; then
        log_pass "Script syntax is valid"
    else
        log_fail "Script has syntax errors"
        return 1
    fi
}

# Test: Required functions exist
test_required_functions() {
    log_test "Testing required functions exist in script"
    
    local required_functions=(
        "detect_luks_partition"
        "verify_tpm2"
        "check_clevis_binding"
        "configure_auto_decrypt"
        "uninstall_auto_decrypt"
        "test_setup"
        "show_usage"
        "main"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" "$AUTODECRYPT_SCRIPT" || grep -q "^function $func" "$AUTODECRYPT_SCRIPT"; then
            continue
        else
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_pass "All required functions are present"
    else
        log_fail "Missing functions: ${missing_functions[*]}"
        return 1
    fi
}

# Test: Logging functions
test_logging_functions() {
    log_test "Testing logging functions exist"
    
    local log_functions=(
        "log_info"
        "log_warn" 
        "log_error"
        "log_debug"
    )
    
    local missing_log_functions=()
    
    for func in "${log_functions[@]}"; do
        if grep -q "$func()" "$AUTODECRYPT_SCRIPT"; then
            continue
        else
            missing_log_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_log_functions[@]} -eq 0 ]]; then
        log_pass "All logging functions are present"
    else
        log_fail "Missing logging functions: ${missing_log_functions[*]}"
        return 1
    fi
}

# Test: Error handling
test_error_handling() {
    log_test "Testing error handling (set -euo pipefail)"
    
    if grep -q "set -euo pipefail" "$AUTODECRYPT_SCRIPT"; then
        log_pass "Proper error handling is enabled"
    else
        log_fail "Script should use 'set -euo pipefail' for error handling"
        return 1
    fi
}

# Test: License header
test_license_header() {
    log_test "Testing license header presence"
    
    if grep -q "BSD 3-Clause License" "$AUTODECRYPT_SCRIPT"; then
        log_pass "BSD license header found"
    else
        log_fail "BSD license header not found"
        return 1
    fi
}

# Test: Version information
test_version_info() {
    log_test "Testing version information presence"
    
    if grep -q "Version:" "$AUTODECRYPT_SCRIPT" || grep -q "version" "$AUTODECRYPT_SCRIPT"; then
        log_pass "Version information found"
    else
        log_fail "Version information not found"
        return 1
    fi
}

# Test: Documentation files exist
test_documentation_exists() {
    log_test "Testing documentation files exist"
    
    local doc_files=(
        "README.md"
        "docs/index.md"
        "docs/installation.md"
        "docs/usage.md"
        "docs/configuration.md"
        "docs/troubleshooting.md"
        "docs/security.md"
    )
    
    local missing_docs=()
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$doc" ]]; then
            continue
        else
            missing_docs+=("$doc")
        fi
    done
    
    if [[ ${#missing_docs[@]} -eq 0 ]]; then
        log_pass "All documentation files are present"
    else
        log_fail "Missing documentation files: ${missing_docs[*]}"
        return 1
    fi
}

# Test: Project structure
test_project_structure() {
    log_test "Testing project structure"
    
    local required_files=(
        "LICENSE"
        ".gitignore"
        "autodecrypt.sh"
        "docs/conf.py"
        ".readthedocs.yaml"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            continue
        else
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_pass "All required project files are present"
    else
        log_fail "Missing project files: ${missing_files[*]}"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    echo "================================================"
    echo "AutoDecrypt Test Suite"
    echo "================================================"
    echo ""
    
    # Run tests (continue on failure to see all results)
    test_script_exists || true
    test_script_syntax || true
    test_help_option || true
    test_invalid_option || true
    test_no_command || true
    test_required_functions || true
    test_logging_functions || true
    test_error_handling || true
    test_license_header || true
    test_version_info || true
    test_documentation_exists || true
    test_project_structure || true
    
    echo ""
    echo "================================================"
    echo "Test Results"
    echo "================================================"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
