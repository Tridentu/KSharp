#!/bin/bash

# K# Test Suite
# Usage: ./run_tests.sh [path/to/ksharpc]

KSHARPC="${1:-./ksharpc}"
TESTS_DIR="$(dirname "$0")"
PASS=0
FAIL=0
WARN=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}K# Test Suite${NC}"
echo "Using compiler: $KSHARPC"
echo "----------------------------------------"

# Helper: run compiler and check exit code
expect_success() {
    local name="$1"
    shift
    local files=("$@")

    output=$("$KSHARPC" "${files[@]}" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC} $name"
        echo "  Expected success, got exit code $exit_code"
        echo "  Output: $(echo "$output" | tail -3)"
        FAIL=$((FAIL + 1))
    fi
}

expect_failure() {
    local name="$1"
    shift
    local files=("$@")

    output=$("$KSHARPC" "${files[@]}" 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo -e "${GREEN}PASS${NC} $name (failed as expected)"
        PASS=$((PASS + 1))
    else
        echo -e "${YELLOW}WARN${NC} $name (expected failure but succeeded)"
        WARN=$((WARN + 1))
    fi
}

expect_warning() {
    local name="$1"
    local pattern="$2"
    shift 2
    local files=("$@")

    output=$("$KSHARPC" "${files[@]}" 2>&1)

    if echo "$output" | grep -q "$pattern"; then
        echo -e "${GREEN}PASS${NC} $name (warning present: '$pattern')"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC} $name (expected warning '$pattern' not found)"
        FAIL=$((FAIL + 1))
    fi
}

expect_output_contains() {
    local name="$1"
    local file="$2"
    local pattern="$3"
    shift 3
    local sources=("$@")

    "$KSHARPC" "${sources[@]}" > /dev/null 2>&1

    # Derive output dir from first source file
    local base=$(basename "${sources[0]}" .kshp)
    local outdir="${base}_build"

    if grep -r "$pattern" "$outdir/" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC} $name (found '$pattern' in output)"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC} $name (pattern '$pattern' not found in $outdir/)"
        FAIL=$((FAIL + 1))
    fi
}

# ----------------------------------------
echo ""
echo "--- Valid programs ---"
# ----------------------------------------

expect_success "Hello World console app" \
    "$TESTS_DIR/valid/hello_world.kshp"

expect_success "Properties with defaults" \
    "$TESTS_DIR/valid/properties.kshp"

expect_success "Signals and slots" \
    "$TESTS_DIR/valid/signals_slots.kshp"

expect_success "Enums and interfaces" \
    "$TESTS_DIR/valid/enums_interfaces.kshp"

expect_success "Abstract class" \
    "$TESTS_DIR/valid/abstract_class.kshp"

expect_success "Multi-file compilation" \
    "$TESTS_DIR/valid/multi_file_a.kshp" \
    "$TESTS_DIR/valid/multi_file_b.kshp"

expect_success "UI window" \
    "$TESTS_DIR/valid/ui_window.kshp"

# ----------------------------------------
echo ""
echo "--- Output verification ---"
# ----------------------------------------

expect_output_contains "Properties generate Q_PROPERTY" \
    "" "Q_PROPERTY" \
    "$TESTS_DIR/valid/properties.kshp"

expect_output_contains "Signals generate emit" \
    "" "emit" \
    "$TESTS_DIR/valid/signals_slots.kshp"

expect_output_contains "Enums generate enum class" \
    "enum class" \
    "$TESTS_DIR/valid/enums_interfaces.kshp"

expect_output_contains "Abstract methods generate = 0" \
    "" "= 0" \
    "$TESTS_DIR/valid/abstract_class.kshp"

expect_output_contains "String interpolation generates arg()" \
    "" ".arg(" \
    "$TESTS_DIR/valid/properties.kshp"

expect_output_contains "UI generates QObject::connect" \
    "" "QObject::connect" \
    "$TESTS_DIR/valid/ui_window.kshp"

# ----------------------------------------
echo ""
echo "--- Invalid programs (error handling) ---"
# ----------------------------------------

expect_warning "Missing return type causes syntax error" \
    "Syntax Error" \
    "$TESTS_DIR/invalid/missing_return_type.kshp"

expect_warning "Non-static Main generates warning" \
    "not static" \
    "$TESTS_DIR/invalid/nonstatic_main.kshp"

expect_warning "Unknown parent class generates warning" \
    "Unknown parent class" \
    "$TESTS_DIR/invalid/unknown_parent.kshp"

# ----------------------------------------
echo ""
echo "----------------------------------------"
echo -e "Results: ${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}  ${YELLOW}$WARN warnings${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
else
    exit 0
fi
