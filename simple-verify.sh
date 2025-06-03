#!/bin/bash
set -euo pipefail

# Simplified CI Fix Verification
echo "🔍 Verifying CI fixes..."
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

success=0
total=0

check() {
    local description="$1"
    local test_cmd="$2"
    total=$((total + 1))
    
    printf "%-50s " "$description..."
    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        success=$((success + 1))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
}

echo -e "${BLUE}1. README.md Files:${NC}"
check "hello-world README.md" "[ -f 'examples/01-basic/hello-world/README.md' ]"
check "multi-resource README.md" "[ -f 'examples/01-basic/multi-resource/README.md' ]"
check "basic-signing README.md" "[ -f 'examples/03-signing/basic-signing/README.md' ]"
check "component-references README.md" "[ -f 'examples/05-advanced/component-references/README.md' ]"
check "localization README.md" "[ -f 'examples/05-advanced/localization/README.md' ]"

echo
echo -e "${BLUE}2. Script Permissions:${NC}"
check "test-enhancements.sh executable" "[ -x 'test-enhancements.sh' ]"
check "verify-ci-fixes.sh executable" "[ -x 'verify-ci-fixes.sh' ]"
check "test-all.sh executable" "[ -x 'scripts/test-all.sh' ]"

echo
echo -e "${BLUE}3. CI Workflow:${NC}"
check "CI has permission fix step" "grep -q 'Fix script permissions' .github/workflows/ci.yml"
check "CI validates documentation" "grep -q 'Validate documentation' .github/workflows/ci.yml"

echo
echo -e "${BLUE}4. Enhanced Test Features:${NC}"
check "test-all.sh has timeout functionality" "grep -q 'timeout=' scripts/test-all.sh"
check "test-all.sh has retry functionality" "grep -q 'retry_count=' scripts/test-all.sh"
check "test-all.sh has suggest_fix function" "grep -q 'suggest_fix' scripts/test-all.sh"
check "test-all.sh has detailed summary" "grep -q 'print_detailed_summary' scripts/test-all.sh"

echo
echo "=================================================================="
echo -e "${BLUE}VERIFICATION SUMMARY:${NC}"
echo -e "Passed: ${GREEN}$success${NC}/$total checks"

if [ "$success" -eq "$total" ]; then
    echo -e "${GREEN}🎉 ALL CHECKS PASSED! CI is ready.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some checks failed.${NC}"
    exit 1
fi
