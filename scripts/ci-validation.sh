#!/bin/bash

# CI validation script to check for common issues
# This script ensures all prerequisites are met before running tests

set -e

echo "🔍 Running CI validation checks..."

# Check 1: Ensure all directories under examples/ have README.md
echo "Checking for missing README.md files in examples/..."
missing_readme=0
for dir in examples/*/; do
  if [ ! -f "${dir}README.md" ]; then
    echo "❌ Missing README.md in $dir"
    missing_readme=1
  fi
done

if [ $missing_readme -eq 0 ]; then
  echo "✅ All examples/ directories have README.md files"
fi

# Check 2: Ensure all .sh scripts are executable
echo "Checking for non-executable .sh scripts..."
non_executable=0
while IFS= read -r -d '' script; do
  if [ ! -x "$script" ]; then
    echo "❌ Script is not executable: $script"
    non_executable=1
  fi
done < <(find . -name "*.sh" -type f -print0)

if [ $non_executable -eq 0 ]; then
  echo "✅ All .sh scripts are executable"
fi

# Check 3: Validate key script syntax
echo "Validating script syntax..."
syntax_errors=0
for script in scripts/*.sh examples/*/run-examples.sh examples/*/*/*.sh; do
  if [ -f "$script" ]; then
    if ! bash -n "$script" 2>/dev/null; then
      echo "❌ Syntax error in: $script"
      syntax_errors=1
    fi
  fi
done

if [ $syntax_errors -eq 0 ]; then
  echo "✅ All scripts have valid syntax"
fi

# Summary
echo ""
if [ $missing_readme -eq 0 ] && [ $non_executable -eq 0 ] && [ $syntax_errors -eq 0 ]; then
  echo "🎉 All CI validation checks passed!"
  exit 0
else
  echo "❌ CI validation failed - please fix the issues above"
  exit 1
fi
