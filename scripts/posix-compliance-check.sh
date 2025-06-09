#!/bin/bash

# POSIX Compliance and Shell Script Validation
# This script checks for common shell script issues that can cause CI failures

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
ISSUES_FOUND=0
FILES_CHECKED=0

print_header() {
    echo -e "${BLUE}🔍 POSIX Compliance and Shell Script Validation${NC}"
    echo "=================================================="
}

print_section() {
    echo -e "\n${BLUE}📋 $1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check for bash-specific features that aren't POSIX compliant
check_posix_compliance() {
    print_section "Checking POSIX Compliance"
    
    local bash_features_found=false
    
    # Check for &> redirection (should be >/dev/null 2>&1)
    if grep -r "&>" . --include="*.sh" > /dev/null 2>&1; then
        print_error "Found bash-specific &> redirections:"
        grep -rn "&>" . --include="*.sh" | head -5
        bash_features_found=true
    fi
    
    # Check for [[ ]] (should use [ ] for POSIX compliance in some contexts)
    local double_bracket_count
    double_bracket_count=$(grep -r "\[\[" . --include="*.sh" | wc -l | tr -d ' ')
    if [ "$double_bracket_count" -gt 0 ]; then
        print_info "Found $double_bracket_count instances of [[ ]] syntax (bash-specific but acceptable)"
    fi
    
    # Check for $(...) vs `...` (both are acceptable, $() is preferred)
    local backtick_count
    backtick_count=$(grep -r '`[^`]*`' . --include="*.sh" | wc -l | tr -d ' ')
    if [ "$backtick_count" -gt 0 ]; then
        print_warning "Found $backtick_count instances of backtick command substitution (consider using \$() instead)"
        grep -rn '`[^`]*`' . --include="*.sh" | head -3
    fi
    
    # Check for arrays (bash-specific)
    if grep -r "=(" . --include="*.sh" > /dev/null 2>&1; then
        local array_count
        array_count=$(grep -r "=(" . --include="*.sh" | wc -l | tr -d ' ')
        print_info "Found $array_count array declarations (bash-specific but acceptable with #!/bin/bash)"
    fi
    
    if [ "$bash_features_found" = false ]; then
        print_success "No critical POSIX compliance issues found"
    fi
}

# Check for proper shebangs
check_shebangs() {
    print_section "Checking Shebangs"
    
    local missing_shebang=false
    local wrong_shebang=false
    
    # Use a temporary file instead of process substitution for POSIX compliance
    temp_file=$(mktemp)
    find . -name "*.sh" -type f > "$temp_file"
    
    while IFS= read -r script; do
        [ -z "$script" ] && continue
        FILES_CHECKED=$((FILES_CHECKED + 1))
        
        if [ ! -s "$script" ]; then
            print_warning "Empty script: $script"
            continue
        fi
        
        first_line=$(head -n1 "$script" 2>/dev/null)
        
        if [ -z "$first_line" ]; then
            print_error "Empty or unreadable file: $script"
            missing_shebang=true
            continue
        fi
        
        if ! echo "$first_line" | grep -q "^#!"; then
            print_error "Missing shebang in: $script"
            missing_shebang=true
        elif echo "$first_line" | grep -qE "^#!/bin/sh$"; then
            print_warning "Using #!/bin/sh in: $script (consider #!/bin/bash for better compatibility)"
            wrong_shebang=true
        elif echo "$first_line" | grep -qE "^#!/bin/bash$"; then
            # This is good
            :
        else
            print_info "Non-standard shebang in: $script ($first_line)"
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ "$missing_shebang" = false ] && [ "$wrong_shebang" = false ]; then
        print_success "All scripts have proper shebangs"
    fi
}

# Check for syntax errors using multiple shell interpreters
check_syntax() {
    print_section "Checking Syntax with Multiple Interpreters"
    
    local syntax_errors=false
    local temp_file=$(mktemp)
    
    find . -name "*.sh" -type f > "$temp_file"
    
    while IFS= read -r script; do
        [ -z "$script" ] && continue
        
        # Check with bash
        if ! bash -n "$script" 2>/dev/null; then
            print_error "Bash syntax error in: $script"
            bash -n "$script" 2>&1 | head -3 | sed 's/^/  /'
            syntax_errors=true
        fi
        
        # Check with dash (POSIX shell) if available
        if command -v dash > /dev/null 2>&1; then
            if ! dash -n "$script" 2>/dev/null; then
                print_error "Dash (POSIX) syntax error in: $script"
                dash -n "$script" 2>&1 | head -3 | sed 's/^/  /'
                syntax_errors=true
            fi
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ "$syntax_errors" = false ]; then
        print_success "No syntax errors found"
    fi
}

# Check for common scripting issues
check_common_issues() {
    print_section "Checking Common Scripting Issues"
    
    # Check for unquoted variables that might cause word splitting
    if grep -r '\$[A-Za-z_][A-Za-z0-9_]*[^A-Za-z0-9_"' . --include="*.sh" > /dev/null 2>&1; then
        print_warning "Potentially unquoted variables found (may cause word splitting):"
        grep -rn '\$[A-Za-z_][A-Za-z0-9_]*[^A-Za-z0-9_"' . --include="*.sh" | head -3 | sed 's/^/  /'
    fi
    
    # Check for commands that might not exist in all environments
    local potentially_missing_commands="shellcheck jq yq"
    for cmd in $potentially_missing_commands; do
        if grep -r "command -v $cmd\|which $cmd\|$cmd " . --include="*.sh" > /dev/null 2>&1; then
            print_info "Uses potentially missing command: $cmd"
        fi
    done
    
    # Check for hardcoded paths that might not exist
    if grep -r "^[[:space:]]*/" . --include="*.sh" > /dev/null 2>&1; then
        local hardcoded_paths
        hardcoded_paths=$(grep -rn "^[[:space:]]*/" . --include="*.sh" | wc -l | tr -d ' ')
        if [ "$hardcoded_paths" -gt 0 ]; then
            print_info "Found $hardcoded_paths potential hardcoded paths"
        fi
    fi
    
    print_success "Common issues check completed"
}

# Check file permissions
check_permissions() {
    print_section "Checking File Permissions"
    
    local non_executable=false
    
    while IFS= read -r script; do
        if [ ! -x "$script" ]; then
            print_error "Non-executable script: $script"
            non_executable=true
        fi
    done <<EOF
$(find . -name "*.sh" -type f)
EOF
    
    if [ "$non_executable" = false ]; then
        print_success "All shell scripts are executable"
    fi
}

# Check for CI-specific issues
check_ci_compatibility() {
    print_section "Checking CI Environment Compatibility"
    
    # Check for interactive commands
    if grep -r "read -p\|read -n\|select " . --include="*.sh" > /dev/null 2>&1; then
        print_warning "Found potentially interactive commands that may fail in CI:"
        grep -rn "read -p\|read -n\|select " . --include="*.sh" | head -3 | sed 's/^/  /'
    fi
    
    # Check for commands that require TTY
    if grep -r "docker run -it\|kubectl.*-it" . --include="*.sh" > /dev/null 2>&1; then
        print_warning "Found commands with -it flags that may fail in CI:"
        grep -rn "docker run -it\|kubectl.*-it" . --include="*.sh" | head -3 | sed 's/^/  /'
    fi
    
    # Check for long-running commands without timeouts
    if grep -r "sleep [0-9][0-9][0-9]\|sleep [0-9][0-9][0-9][0-9]" . --include="*.sh" > /dev/null 2>&1; then
        print_warning "Found long sleep commands that may slow CI:"
        grep -rn "sleep [0-9][0-9][0-9]" . --include="*.sh" | head -3 | sed 's/^/  /'
    fi
    
    print_success "CI compatibility check completed"
}

# Main execution
main() {
    print_header
    echo
    
    check_shebangs
    check_posix_compliance
    check_syntax
    check_permissions
    check_common_issues
    check_ci_compatibility
    
    # Summary
    echo
    echo -e "${BLUE}📊 Summary${NC}"
    echo "=========="
    echo "Files checked: $FILES_CHECKED"
    echo "Issues found: $ISSUES_FOUND"
    echo
    
    if [ $ISSUES_FOUND -eq 0 ]; then
        print_success "🎉 All checks passed! Scripts are ready for CI."
        exit 0
    else
        print_warning "⚠️  Found $ISSUES_FOUND potential issues. Review the output above."
        exit 1
    fi
}

main "$@"
