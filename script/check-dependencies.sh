#!/bin/bash
# Dependency security check script for Gnosisland
# This script checks for outdated dependencies and known vulnerabilities

set -e

echo "=========================================="
echo "Gnosisland Dependency Security Check"
echo "=========================================="

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo "Error: forge not found. Please install Foundry first."
    exit 1
fi

echo ""
echo "1. Running forge audit..."
echo "----------------------------------------"
if forge audit 2>/dev/null; then
    echo "✓ Forge audit passed"
else
    echo "⚠️  Warning: forge audit not available or found issues"
    echo "Note: forge audit may not be available in all Foundry versions"
    echo "Consider using alternative security tools:"
    echo "  - Slither (static analysis)"
    echo "  - Mythril (symbolic execution)"
    echo "  - Professional security audit"
fi

echo ""
echo "2. Checking dependency versions..."
echo "----------------------------------------"

# Check OpenZeppelin version
if [ -d "lib/openzeppelin-contracts" ]; then
    echo "OpenZeppelin Contracts:"
    cd lib/openzeppelin-contracts
    if [ -f "package.json" ]; then
        VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
        echo "  Version: $VERSION"
    else
        echo "  Version: (check git tag)"
        git describe --tags --always 2>/dev/null || echo "  (unable to determine version)"
    fi
    cd ../..
else
    echo "⚠️  OpenZeppelin contracts not found!"
fi

# Check forge-std version
if [ -d "lib/forge-std" ]; then
    echo "Forge Std:"
    cd lib/forge-std
    if [ -f "package.json" ]; then
        VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
        echo "  Version: $VERSION"
    else
        echo "  Version: (check git tag)"
        git describe --tags --always 2>/dev/null || echo "  (unable to determine version)"
    fi
    cd ../..
else
    echo "⚠️  forge-std not found!"
fi

echo ""
echo "3. Checking for known vulnerable patterns..."
echo "----------------------------------------"

# Check for dangerous functions
echo "Checking for delegatecall usage..."
DELEGATECALL_COUNT=$(grep -r "delegatecall" src/ --include="*.sol" 2>/dev/null | grep -v "//" | grep -v "import" | wc -l || echo "0")
if [ "$DELEGATECALL_COUNT" -gt 0 ]; then
    echo "  ⚠️  Found $DELEGATECALL_COUNT delegatecall usage(s) - review carefully"
    grep -r "delegatecall" src/ --include="*.sol" | grep -v "//" | grep -v "import" || true
else
    echo "  ✓ No delegatecall found"
fi

echo "Checking for selfdestruct usage..."
SELFDESTRUCT_COUNT=$(grep -r "selfdestruct" src/ --include="*.sol" 2>/dev/null | grep -v "//" | grep -v "import" | wc -l || echo "0")
if [ "$SELFDESTRUCT_COUNT" -gt 0 ]; then
    echo "  ⚠️  Found $SELFDESTRUCT_COUNT selfdestruct usage(s) - review carefully"
    grep -r "selfdestruct" src/ --include="*.sol" | grep -v "//" | grep -v "import" || true
else
    echo "  ✓ No selfdestruct found"
fi

echo ""
echo "4. Verifying critical dependencies..."
echo "----------------------------------------"

MISSING_DEPS=0

if [ ! -d "lib/openzeppelin-contracts" ]; then
    echo "  ❌ OpenZeppelin contracts not found!"
    MISSING_DEPS=1
else
    echo "  ✓ OpenZeppelin contracts found"
fi

if [ ! -d "lib/forge-std" ]; then
    echo "  ❌ forge-std not found!"
    MISSING_DEPS=1
else
    echo "  ✓ forge-std found"
fi

echo ""
echo "=========================================="
if [ "$MISSING_DEPS" -eq 0 ]; then
    echo "✓ Dependency check completed"
    echo "=========================================="
    exit 0
else
    echo "❌ Missing critical dependencies!"
    echo "=========================================="
    exit 1
fi


